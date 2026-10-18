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
        migrateProgressToSRS()
        applySoundSettings()
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
        set {
            user.settings = newValue
            applySoundSettings()
        }
    }

    func applySoundSettings() {
        SoundFX.shared.effectsOn = user.settings.soundsOn
        SoundFX.shared.musicOn = user.settings.musicOn
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

    // MARK: - Прогресс по словам (интервальные повторения)

    func progress(for wordID: String) -> WordProgress {
        return user.progress[wordID] ?? WordProgress()
    }

    func srsState(for wordID: String) -> SRSState? {
        return user.srs[wordID]
    }

    /// «Новое» — ещё не начато; «Выучено» — держится в памяти не меньше 3 недель; иначе «Учу».
    func status(for wordID: String) -> MasteryStatus {
        guard let s = user.srs[wordID] else { return .new }
        return s.stability >= FSRS.learnedStability ? .learned : .learning
    }

    /// Доля выученности слова от 0 до 1 (стабильность памяти относительно 3 недель).
    func fraction(for wordID: String) -> Double {
        guard let s = user.srs[wordID] else { return 0 }
        return min(1.0, s.stability / FSRS.learnedStability)
    }

    /// Записывает ответ: счётчики верных/ошибок и интервальные повторения.
    /// - recognition: ответ выбран из вариантов (узнать слово легче, чем вспомнить самому)
    /// - accentsOnly: верно, но с ошибкой в ударении
    func record(wordID: String, correct: Bool, recognition: Bool = false, accentsOnly: Bool = false, now: Date = Date()) {
        var p = user.progress[wordID] ?? WordProgress()
        if correct {
            p.correct += 1
            p.score += 1
        } else {
            p.wrong += 1
            p.score = max(0, p.score - 1)
        }
        p.lastSeen = now
        user.progress[wordID] = p

        var rating: ReviewRating = correct ? (accentsOnly ? .hard : .good) : .again
        let previous = user.srs[wordID]
        // Совсем новое слово, угаданное среди вариантов, вернётся уже завтра, а не через 4 дня.
        if previous == nil && recognition && rating == .good {
            rating = .hard
        }
        user.srs[wordID] = FSRS.review(previous, rating: rating, now: now)
        feedPet(correct ? PetRules.foodPerCorrect : PetRules.foodPerWrong, now: now)
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
        return user.srs.values.filter { $0.stability >= FSRS.learnedStability }.count
    }

    var totalLearningWords: Int {
        return user.srs.values.filter { $0.stability < FSRS.learnedStability }.count
    }

    /// Слова со старым прогрессом (до версии 1.1) переводим в интервальные повторения.
    private func migrateProgressToSRS() {
        if user.progress.isEmpty { return }
        var changed = false
        let now = Date()
        for (id, p) in user.progress where user.srs[id] == nil && p.attempts > 0 {
            let learned = p.score >= user.settings.masteryThreshold
            let stability: Double = learned ? 21 : max(1, Double(p.score) / 2)
            let last = p.lastSeen ?? now
            let interval = FSRS.intervalDays(stability: stability)
            var due = Calendar.current.date(byAdding: .day, value: interval, to: FSRS.startOfDay(last)) ?? now
            if due < FSRS.startOfDay(now) { due = FSRS.startOfDay(now) }
            user.srs[id] = SRSState(stability: stability, difficulty: p.wrong > p.correct ? 7 : 5,
                                    firstSeen: last, lastReview: last, due: due,
                                    reps: p.attempts, lapses: p.wrong)
            changed = true
        }
        if changed { scheduleSave() }
    }

    // MARK: - План на сегодня

    struct DailyPlan {
        /// Слова, которые пора повторить (самые просроченные первыми)
        var dueIDs: [String]
        /// Новые слова из коллекций в пределах дневного лимита
        var newIDs: [String]
        /// Сколько слов уже повторено сегодня
        var reviewedToday: Int
        /// Сколько новых слов уже начато сегодня
        var introducedToday: Int
        /// Есть ли вообще неначатые слова в коллекциях
        var hasMoreNew: Bool

        var isEmpty: Bool { return dueIDs.isEmpty && newIDs.isEmpty }
        var total: Int { return dueIDs.count + newIDs.count }
    }

    /// Неначатые слова из коллекций по порядку: коллекции — от старых к новым, слова — как в коллекции.
    func unstartedCollectionWords(limit: Int) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for c in user.collections.sorted(by: { $0.created < $1.created }) {
            for id in c.wordIDs where user.srs[id] == nil && index.word(id) != nil && !seen.contains(id) {
                seen.insert(id)
                result.append(id)
                if result.count >= limit { return result }
            }
        }
        return result
    }

    func dailyPlan(now: Date = Date()) -> DailyPlan {
        let today = FSRS.startOfDay(now)
        var due: [(String, Date)] = []
        var reviewed = 0
        var introduced = 0
        for (id, s) in user.srs {
            if index.word(id) == nil { continue }
            if s.due <= today { due.append((id, s.due)) }
            if FSRS.startOfDay(s.lastReview) == today { reviewed += 1 }
            if FSRS.startOfDay(s.firstSeen) == today { introduced += 1 }
        }
        due.sort { $0.1 < $1.1 }
        let dueIDs = Array(due.prefix(150).map { $0.0 })
        let remaining = max(0, user.settings.newWordsPerDay - introduced)
        let newIDs = remaining > 0 ? unstartedCollectionWords(limit: remaining) : []
        let hasMore = !unstartedCollectionWords(limit: 1).isEmpty
        return DailyPlan(dueIDs: dueIDs, newIDs: newIDs, reviewedToday: reviewed,
                         introducedToday: introduced, hasMoreNew: hasMore)
    }

    /// Сколько слов придётся повторить в каждый из ближайших дней (1 = завтра).
    func forecast(days: Int, now: Date = Date()) -> [Int] {
        var result = Array(repeating: 0, count: days)
        let today = FSRS.startOfDay(now)
        for (id, s) in user.srs where index.word(id) != nil {
            let d = FSRS.days(from: today, to: s.due)
            if d >= 1 && d <= days {
                result[d - 1] += 1
            }
        }
        return result
    }

    /// Примерное время на тренировку, в минутах.
    func estimatedMinutes(questions: Int) -> Int {
        if questions == 0 { return 0 }
        let seconds = Double(questions) * 11 * 1.2
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    // MARK: - Трудные слова

    /// Слова, в которых было 2 ошибки и больше и которые ещё не выучены. Самые трудные — первыми.
    var difficultWords: [Word] {
        var list: [(Word, Int)] = []
        for (id, p) in user.progress where p.wrong >= 2 && status(for: id) != .learned {
            if let w = index.word(id) { list.append((w, p.wrong)) }
        }
        list.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0.pt < b.0.pt
        }
        return list.map { $0.0 }
    }

    // MARK: - Питомец

    func petFood(now: Date = Date()) -> Double {
        return PetRules.food(user.pet, at: now)
    }

    /// Каждый ответ в упражнениях — немного еды.
    func feedPet(_ amount: Double, now: Date = Date()) {
        var p = user.pet
        p.food = min(100, PetRules.food(p, at: now) + amount)
        p.updated = now
        p.pendingMeal = true
        user.pet = p
    }

    /// План на сегодня выполнен — сыт полностью.
    func feedPetFull(now: Date = Date()) {
        var p = user.pet
        p.food = 100
        p.updated = now
        p.pendingMeal = true
        user.pet = p
    }

    func consumePendingMeal() {
        if user.pet.pendingMeal {
            user.pet.pendingMeal = false
        }
    }

    // MARK: - Башня: этажи и вещи

    /// Слово «в памяти», если держится хотя бы неделю.
    static let memoryStability = 7.0
    /// Каждые 50 слов в памяти — новая вещь в башне.
    static let wordsPerItem = 50

    /// Сколько слов в памяти (всего или определённого уровня).
    func wordsInMemory(level: String? = nil) -> Int {
        var n = 0
        for (id, s) in user.srs where s.stability >= AppModel.memoryStability {
            if let lv = level {
                if index.word(id)?.level == lv { n += 1 }
            } else {
                n += 1
            }
        }
        return n
    }

    /// Самый высокий открытый этаж.
    var towerRoom: PetRoom {
        var room = PetRoom.cellar
        for r in PetRoom.allCases.dropFirst() {
            guard let req = r.requirement else { continue }
            if wordsInMemory(level: req.level) >= req.count {
                room = r
            } else {
                break
            }
        }
        return room
    }

    var towerItems: Int {
        return min(PetAtlas.items.count, wordsInMemory() / AppModel.wordsPerItem)
    }

    /// Новые вещи и этаж с прошлого раза: текст объявления (и отметка «увидено»).
    func takeTowerNews() -> String? {
        var news: [String] = []
        let room = towerRoom.rawValue
        if room > user.pet.seenRoom {
            news.append("Маг поднялся на новый этаж: \(towerRoom.title)!")
        }
        let items = towerItems
        if items > user.pet.seenItems {
            let titles = PetAtlas.items[user.pet.seenItems..<items].map { $0.title }
            news.append("В башне появилось: " + titles.joined(separator: ", "))
        }
        if room != user.pet.seenRoom || items != user.pet.seenItems {
            user.pet.seenRoom = room
            user.pet.seenItems = items
        }
        return news.isEmpty ? nil : news.joined(separator: "\n")
    }

    /// Следующий этаж и сколько до него осталось.
    func nextRoomProgress() -> (room: PetRoom, level: String, have: Int, need: Int)? {
        let current = towerRoom
        guard let next = PetRoom(rawValue: current.rawValue + 1), let req = next.requirement else { return nil }
        return (next, req.level, min(req.count, wordsInMemory(level: req.level)), req.count)
    }

    /// Следующая вещь в башне.
    func nextItemProgress() -> (title: String, have: Int, need: Int)? {
        let count = towerItems
        guard count < PetAtlas.items.count else { return nil }
        let need = (count + 1) * AppModel.wordsPerItem
        return (PetAtlas.items[count].title, wordsInMemory(), need)
    }

    // MARK: - Босс недели

    /// «2026-42»: год и номер недели (неделя начинается в понедельник).
    func weekKey(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
    }

    /// Босс этой недели (по кругу).
    var bossOfWeek: (key: String, title: String) {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        let week = cal.component(.weekOfYear, from: Date())
        return PetAtlas.bosses[week % PetAtlas.bosses.count]
    }

    /// Босс появляется, когда начато хотя бы 12 слов.
    var bossAvailable: Bool {
        return user.srs.count >= 12
    }

    var bossDefeatedThisWeek: Bool {
        return user.boss.defeatedWeek == weekKey()
    }

    /// Слова для боя: повторённые за последние 7 дней, затем самые «слабые» из начатых.
    func bossWords(limit: Int = 15) -> [Word] {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        var recent: [(Word, Date)] = []
        var others: [(Word, Double)] = []
        for (id, s) in user.srs {
            guard let w = index.word(id) else { continue }
            if s.lastReview >= weekAgo {
                recent.append((w, s.lastReview))
            } else {
                others.append((w, s.stability))
            }
        }
        var result = recent.shuffled().map { $0.0 }
        if result.count < limit {
            result += others.sorted { $0.1 < $1.1 }.map { $0.0 }.prefix(limit - result.count)
        }
        return Array(result.prefix(limit))
    }

    func bossConfig() -> BossConfig {
        let b = bossOfWeek
        let words = min(15, max(8, user.srs.count))
        return BossConfig(key: b.key, title: b.title, hp: words, hearts: 4)
    }

    func recordBossVictory() {
        if user.boss.defeatedWeek != weekKey() {
            user.boss.defeatedWeek = weekKey()
            user.boss.wins += 1
        }
        feedPetFull()
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

    func recordVerb(verb: Verb, tense: TenseInfo, correct: Bool, recognition: Bool = false) {
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
        // интервальные повторения для пары «глагол + время»
        var rating: ReviewRating = correct ? .good : .again
        let previous = user.verbSRS[key]
        if previous == nil && recognition && rating == .good { rating = .hard }
        user.verbSRS[key] = FSRS.review(previous, rating: rating)
        feedPet(correct ? PetRules.foodPerCorrect : PetRules.foodPerWrong)
    }

    // MARK: - Глаголы в плане «Сегодня»

    /// Новых пар «глагол + время» в день
    static let newVerbPairsPerDay = 4
    /// Порядок времён для изучения
    static let verbTenseOrder = ["presente", "perfeito", "imperfeito", "futuro", "condicional",
                                 "conjuntivo_presente", "imperativo", "mais_que_perfeito",
                                 "conjuntivo_imperfeito", "conjuntivo_futuro", "infinitivo_pessoal"]
    /// Если в коллекциях нет глаголов — самые нужные
    static let coreVerbs = ["ser", "estar", "ter", "ir", "fazer", "poder", "querer", "dizer", "ver", "dar",
                            "saber", "vir", "ficar", "falar", "comer", "viver", "gostar", "precisar", "conhecer", "sair"]

    struct VerbPlan {
        var due: [VerbPair]
        var new: [VerbPair]
        var total: Int { return due.count + new.count }
        var isEmpty: Bool { return total == 0 }
    }

    /// Глаголы для плана: из коллекций по порядку, иначе — базовый список.
    private func planVerbs() -> [Verb] {
        var result: [Verb] = []
        var seen = Set<String>()
        for c in user.collections.sorted(by: { $0.created < $1.created }) {
            for id in c.wordIDs {
                if let v = verbs.verb(forWordID: id), !v.reflexive, seen.insert(v.inf).inserted {
                    result.append(v)
                }
            }
        }
        if result.count < 5 {
            for inf in AppModel.coreVerbs {
                if let v = verbs.byInf[inf], seen.insert(v.inf).inserted {
                    result.append(v)
                }
            }
        }
        return result
    }

    func dailyVerbPlan(now: Date = Date()) -> VerbPlan {
        let today = FSRS.startOfDay(now)
        let tenseByID = Dictionary(verbs.tenses.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var due: [VerbPair] = []
        var introduced = 0
        for (key, s) in user.verbSRS {
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2, let v = verbs.byInf[parts[0]], let t = tenseByID[parts[1]] else { continue }
            if s.due <= today {
                due.append(VerbPair(verb: v, tense: t, typing: s.stability >= 4))
            }
            if FSRS.startOfDay(s.firstSeen) == today { introduced += 1 }
        }
        var new: [VerbPair] = []
        let remaining = max(0, AppModel.newVerbPairsPerDay - introduced)
        if remaining > 0 {
            let list = planVerbs()
            outer: for tid in AppModel.verbTenseOrder {
                guard let t = tenseByID[tid] else { continue }
                for v in list {
                    let key = VerbLibrary.progressKey(verb: v, tense: t)
                    if user.verbSRS[key] == nil {
                        new.append(VerbPair(verb: v, tense: t, typing: false))
                        if new.count >= remaining { break outer }
                    }
                }
            }
        }
        return VerbPlan(due: Array(due.prefix(40)), new: new)
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
        user.srs = [:]
        user.verbSRS = [:]
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

    /// Добавляет несколько своих слов за раз (индекс перестраивается один раз).
    /// Если такое своё слово уже есть, используется оно. Возвращает id слов.
    func addCustomWords(_ items: [(pt: String, translations: [String: [String]])]) -> [String] {
        var ids: [String] = []
        var changed = false
        for item in items {
            let trimmed = item.pt.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let existing = user.customWords.first(where: { $0.pt.lowercased() == trimmed.lowercased() }) {
                ids.append(existing.wordID)
                continue
            }
            var cleanTr: [String: [String]] = [:]
            for (lang, list) in item.translations {
                let parts = list.flatMap { $0.split(separator: ",").map(String.init) }
                let clean = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !clean.isEmpty { cleanTr[lang] = clean }
            }
            if cleanTr.isEmpty { continue }
            let custom = CustomWord(pt: trimmed, pos: "", gender: "", translations: cleanTr)
            user.customWords.append(custom)
            ids.append(custom.wordID)
            changed = true
        }
        if changed { rebuildIndex() }
        return ids
    }

    func deleteCustomWord(wordID: String) {
        user.customWords.removeAll { $0.wordID == wordID }
        for i in user.collections.indices {
            user.collections[i].wordIDs.removeAll { $0 == wordID }
        }
        user.progress[wordID] = nil
        user.srs[wordID] = nil
        rebuildIndex()
    }
}
