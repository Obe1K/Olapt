import Foundation
import SwiftUI

/// Главная модель приложения: словари, коллекции, прогресс, настройки.
final class AppModel: ObservableObject {

    @Published private(set) var index: DictionaryIndex
    @Published private(set) var packs: [PackInfo] = []
    @Published var user: UserData {
        didSet { scheduleSave() }
    }
    let verbs: VerbLibrary
    /// Сообщение, если встроенные словари не удалось загрузить.
    let bundleError: String?

    private var packFiles: [PackFile] = []
    private var bundledIDs: Set<String> = []
    private var saveWork: DispatchWorkItem?

    // MARK: - Загрузка

    init() {
        let library = VerbLibrary.load()
        var files: [PackFile] = []
        var bundled = Set<String>()
        var problem: String? = library.loadError

        for name in ["dict-en-pt-eu", "dict-ru-pt-eu"] {
            if let url = Bundle.main.findResource(name, ext: "json") {
                do {
                    let data = try Data(contentsOf: url)
                    let pack = try JSONDecoder().decode(PackFile.self, from: data)
                    files.append(pack)
                    bundled.insert(pack.id)
                } catch {
                    problem = "Не удалось прочитать словарь \(name): \(error.localizedDescription)"
                }
            } else {
                problem = "Файл словаря \(name).json не найден в приложении."
            }
        }
        for pack in Persistence.loadImportedPacks() where !bundled.contains(pack.id) {
            files.append(pack)
        }

        let loaded = Persistence.loadUser()
        let active = files.filter { !loaded.settings.disabledPacks.contains($0.id) }
        let custom = loaded.customWords.map { $0.toWord() }

        self.verbs = library
        self.bundleError = problem
        self.packFiles = files
        self.bundledIDs = bundled
        self.user = loaded
        self.index = DictionaryIndex(packs: active, custom: custom, verbs: library)
        self.packs = AppModel.makeInfos(files: files, bundled: bundled)
    }

    private static func makeInfos(files: [PackFile], bundled: Set<String>) -> [PackInfo] {
        return files.map { f in
            PackInfo(id: f.id, name: f.name, lang: f.lang,
                     langName: f.langName ?? Languages.name(f.lang),
                     entryCount: f.entries.count, isBundled: bundled.contains(f.id))
        }
    }

    private func rebuildIndex() {
        let active = packFiles.filter { !user.settings.disabledPacks.contains($0.id) }
        let custom = user.customWords.map { $0.toWord() }
        index = DictionaryIndex(packs: active, custom: custom, verbs: verbs)
        packs = AppModel.makeInfos(files: packFiles, bundled: bundledIDs)
    }

    // MARK: - Сохранение

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = user
        let work = DispatchWorkItem {
            Persistence.saveUser(snapshot)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Немедленная запись (например, при сворачивании приложения).
    func saveNow() {
        saveWork?.cancel()
        Persistence.saveUser(user)
    }

    // MARK: - Настройки

    var settings: AppSettings {
        get { return user.settings }
        set { user.settings = newValue }
    }

    func isPackEnabled(_ id: String) -> Bool {
        return !user.settings.disabledPacks.contains(id)
    }

    func setPack(_ id: String, enabled: Bool) {
        var list = user.settings.disabledPacks
        if enabled {
            list.removeAll { $0 == id }
        } else if !list.contains(id) {
            list.append(id)
        }
        user.settings.disabledPacks = list
        rebuildIndex()
    }

    /// Устанавливает импортированный словарь и возвращает итоговый id.
    @discardableResult
    func installPack(_ pack: PackFile) throws -> String {
        var file = pack
        let existing = Set(packFiles.map { $0.id })
        file.id = PackImporter.sanitizedID(pack.id, existing: existing)
        try Persistence.savePack(file)
        packFiles.append(file)
        rebuildIndex()
        return file.id
    }

    func deletePack(_ id: String) {
        if bundledIDs.contains(id) { return }
        Persistence.deletePack(id: id)
        packFiles.removeAll { $0.id == id }
        user.settings.disabledPacks.removeAll { $0 == id }
        rebuildIndex()
    }

    /// Языки, доступные для упражнений: коды из подключённых словарей.
    var exerciseLanguages: [String] {
        return index.languages
    }

    // MARK: - Коллекции

    func collection(_ id: UUID) -> WordCollection? {
        return user.collections.first { $0.id == id }
    }

    @discardableResult
    func createCollection(name: String, wordIDs: [String] = []) -> WordCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Новая коллекция" : trimmed
        let c = WordCollection(name: finalName, wordIDs: wordIDs)
        user.collections.append(c)
        return c
    }

    func renameCollection(_ id: UUID, to name: String) {
        guard let i = user.collections.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { user.collections[i].name = trimmed }
    }

    func deleteCollection(_ id: UUID) {
        user.collections.removeAll { $0.id == id }
    }

    func add(wordIDs: [String], to collectionID: UUID) {
        guard let i = user.collections.firstIndex(where: { $0.id == collectionID }) else { return }
        var list = user.collections[i].wordIDs
        for id in wordIDs where !list.contains(id) {
            list.append(id)
        }
        user.collections[i].wordIDs = list
    }

    func remove(wordID: String, from collectionID: UUID) {
        guard let i = user.collections.firstIndex(where: { $0.id == collectionID }) else { return }
        user.collections[i].wordIDs.removeAll { $0 == wordID }
    }

    func isWord(_ wordID: String, in collectionID: UUID) -> Bool {
        return collection(collectionID)?.wordIDs.contains(wordID) ?? false
    }

    func words(in collection: WordCollection) -> [Word] {
        var result: [Word] = []
        for id in collection.wordIDs {
            if let w = index.word(id) { result.append(w) }
        }
        return result
    }

    func setBestScore(collection id: UUID, level: ExerciseLevel, percent: Int) {
        guard let i = user.collections.firstIndex(where: { $0.id == id }) else { return }
        let key = String(level.rawValue)
        let old = user.collections[i].bestScores[key] ?? 0
        if percent > old {
            user.collections[i].bestScores[key] = percent
        }
    }

    // MARK: - Прогресс по словам

    func progress(for wordID: String) -> WordProgress {
        return user.progress[wordID] ?? WordProgress()
    }

    func status(for wordID: String) -> MasteryStatus {
        let p = progress(for: wordID)
        if p.score >= user.settings.masteryThreshold { return .learned }
        if p.attempts == 0 { return .new }
        return .learning
    }

    /// Доля выученности слова от 0 до 1.
    func fraction(for wordID: String) -> Double {
        let threshold = max(1, user.settings.masteryThreshold)
        let score = progress(for: wordID).score
        return min(1.0, Double(score) / Double(threshold))
    }

    /// Записывает результат ответа. Верный ответ даёт +1, ошибка снимает 1 (если включено).
    func record(wordID: String, correct: Bool) {
        var p = user.progress[wordID] ?? WordProgress()
        if correct {
            p.correct += 1
            p.score += 1
        } else {
            p.wrong += 1
            if user.settings.wrongPenalty {
                p.score = max(0, p.score - 1)
            }
        }
        p.lastSeen = Date()
        user.progress[wordID] = p
    }

    func counts(for wordIDs: [String]) -> (new: Int, learning: Int, learned: Int) {
        var n = 0
        var l = 0
        var d = 0
        for id in wordIDs {
            switch status(for: id) {
            case .new: n += 1
            case .learning: l += 1
            case .learned: d += 1
            }
        }
        return (n, l, d)
    }

    func learnedFraction(of wordIDs: [String]) -> Double {
        if wordIDs.isEmpty { return 0 }
        var sum = 0.0
        for id in wordIDs { sum += fraction(for: id) }
        return sum / Double(wordIDs.count)
    }

    var totalLearnedWords: Int {
        let threshold = user.settings.masteryThreshold
        return user.progress.values.filter { $0.score >= threshold }.count
    }

    // MARK: - Прогресс по глаголам

    func verbProgress(verb: Verb, tense: TenseInfo) -> WordProgress {
        return user.verbProgress[VerbLibrary.progressKey(verb: verb, tense: tense)] ?? WordProgress()
    }

    func verbStatus(verb: Verb, tense: TenseInfo) -> MasteryStatus {
        let p = verbProgress(verb: verb, tense: tense)
        if p.score >= user.settings.masteryThreshold { return .learned }
        if p.attempts == 0 { return .new }
        return .learning
    }

    func verbFraction(verb: Verb, tense: TenseInfo) -> Double {
        let threshold = max(1, user.settings.masteryThreshold)
        return min(1.0, Double(verbProgress(verb: verb, tense: tense).score) / Double(threshold))
    }

    func recordVerb(verb: Verb, tense: TenseInfo, correct: Bool) {
        let key = VerbLibrary.progressKey(verb: verb, tense: tense)
        var p = user.verbProgress[key] ?? WordProgress()
        if correct {
            p.correct += 1
            p.score += 1
        } else {
            p.wrong += 1
            if user.settings.wrongPenalty {
                p.score = max(0, p.score - 1)
            }
        }
        p.lastSeen = Date()
        user.verbProgress[key] = p
    }

    /// Средняя выученность глагола по всем временам (0…1).
    func verbOverallFraction(_ verb: Verb) -> Double {
        if verbs.tenses.isEmpty { return 0 }
        var sum = 0.0
        for t in verbs.tenses { sum += verbFraction(verb: verb, tense: t) }
        return sum / Double(verbs.tenses.count)
    }

    func resetProgress() {
        user.progress = [:]
        user.verbProgress = [:]
        for i in user.collections.indices {
            user.collections[i].bestScores = [:]
        }
    }

    // MARK: - Свои слова

    @discardableResult
    func addCustomWord(pt: String, pos: String, gender: String, translations: [String: [String]]) -> Word? {
        let trimmed = pt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        var cleanTr: [String: [String]] = [:]
        for (lang, list) in translations {
            let items = list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !items.isEmpty { cleanTr[lang] = items }
        }
        if cleanTr.isEmpty { return nil }
        let custom = CustomWord(pt: trimmed, pos: pos, gender: gender, translations: cleanTr)
        user.customWords.append(custom)
        rebuildIndex()
        return custom.toWord()
    }

    func deleteCustomWord(wordID: String) {
        user.customWords.removeAll { $0.wordID == wordID }
        for i in user.collections.indices {
            user.collections[i].wordIDs.removeAll { $0 == wordID }
        }
        user.progress[wordID] = nil
        rebuildIndex()
    }
}
