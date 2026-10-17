import Foundation

// MARK: - Коллекции

struct WordCollection: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var wordIDs: [String]
    var created: Date
    /// Лучший результат по уровням: "1"…"4" → процент.
    var bestScores: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id, name, wordIDs, created, bestScores
    }

    init(id: UUID = UUID(), name: String, wordIDs: [String] = [], created: Date = Date(), bestScores: [String: Int] = [:]) {
        self.id = id
        self.name = name
        self.wordIDs = wordIDs
        self.created = created
        self.bestScores = bestScores
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Коллекция"
        wordIDs = try c.decodeIfPresent([String].self, forKey: .wordIDs) ?? []
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        bestScores = try c.decodeIfPresent([String: Int].self, forKey: .bestScores) ?? [:]
    }
}

// MARK: - Прогресс

/// Прогресс по слову (или по паре «глагол + время»).
struct WordProgress: Codable, Hashable {
    var score: Int
    var correct: Int
    var wrong: Int
    var lastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case score, correct, wrong, lastSeen
    }

    init(score: Int = 0, correct: Int = 0, wrong: Int = 0, lastSeen: Date? = nil) {
        self.score = score
        self.correct = correct
        self.wrong = wrong
        self.lastSeen = lastSeen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        correct = try c.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        wrong = try c.decodeIfPresent(Int.self, forKey: .wrong) ?? 0
        lastSeen = try c.decodeIfPresent(Date.self, forKey: .lastSeen)
    }

    var attempts: Int { return correct + wrong }
}

enum MasteryStatus {
    case new
    case learning
    case learned

    var title: String {
        switch self {
        case .new: return "Новое"
        case .learning: return "Учу"
        case .learned: return "Выучено"
        }
    }
}

// MARK: - Настройки

struct AppSettings: Codable, Hashable {
    /// "ru", "en" или "mixed"
    var exerciseLanguage: String
    /// Глаголы: сколько верных ответов нужно, чтобы пара «глагол + время» считалась выученной
    var masteryThreshold: Int
    /// Глаголы: за ошибку вычитать один балл
    var wrongPenalty: Bool
    /// Сколько новых слов в день брать в план «Сегодня»
    var newWordsPerDay: Int
    /// Строго учитывать диакритику при вводе слов
    var strictAccents: Bool
    /// Произносить португальское слово при показе карточки
    var autoSpeak: Bool
    /// Сколько слов в одной тренировке (0 — все)
    var sessionSize: Int
    /// id отключённых словарей
    var disabledPacks: [String]

    enum CodingKeys: String, CodingKey {
        case exerciseLanguage, masteryThreshold, wrongPenalty, strictAccents, autoSpeak, sessionSize, disabledPacks
        case newWordsPerDay
    }

    init() {
        exerciseLanguage = "ru"
        masteryThreshold = 10
        wrongPenalty = true
        strictAccents = false
        autoSpeak = false
        sessionSize = 0
        disabledPacks = []
        newWordsPerDay = 10
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseLanguage = try c.decodeIfPresent(String.self, forKey: .exerciseLanguage) ?? "ru"
        masteryThreshold = try c.decodeIfPresent(Int.self, forKey: .masteryThreshold) ?? 10
        wrongPenalty = try c.decodeIfPresent(Bool.self, forKey: .wrongPenalty) ?? true
        strictAccents = try c.decodeIfPresent(Bool.self, forKey: .strictAccents) ?? false
        autoSpeak = try c.decodeIfPresent(Bool.self, forKey: .autoSpeak) ?? false
        sessionSize = try c.decodeIfPresent(Int.self, forKey: .sessionSize) ?? 0
        disabledPacks = try c.decodeIfPresent([String].self, forKey: .disabledPacks) ?? []
        newWordsPerDay = try c.decodeIfPresent(Int.self, forKey: .newWordsPerDay) ?? 10
    }
}

// MARK: - Свои слова

struct CustomWord: Codable, Identifiable, Hashable {
    var id: UUID
    var pt: String
    var pos: String
    var gender: String
    var translations: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case id, pt, pos, gender, translations
    }

    init(id: UUID = UUID(), pt: String, pos: String, gender: String, translations: [String: [String]]) {
        self.id = id
        self.pt = pt
        self.pos = pos
        self.gender = gender
        self.translations = translations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        pt = try c.decodeIfPresent(String.self, forKey: .pt) ?? ""
        pos = try c.decodeIfPresent(String.self, forKey: .pos) ?? ""
        gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? ""
        translations = try c.decodeIfPresent([String: [String]].self, forKey: .translations) ?? [:]
    }

    var wordID: String { return "custom:" + id.uuidString }

    func toWord() -> Word {
        return Word(id: wordID, pt: pt, pos: pos, gender: gender, feminine: "", plural: "",
                    topic: "", brazilian: "", note: "", translations: translations, isCustom: true)
    }
}

// MARK: - Все данные пользователя

struct UserData: Codable {
    var collections: [WordCollection]
    var progress: [String: WordProgress]
    var verbProgress: [String: WordProgress]
    var customWords: [CustomWord]
    var settings: AppSettings
    /// Интервальные повторения: id слова → состояние
    var srs: [String: SRSState]
    /// Тамагочи
    var pet: PetData

    enum CodingKeys: String, CodingKey {
        case collections, progress, verbProgress, customWords, settings, srs, pet
    }

    init() {
        collections = []
        progress = [:]
        verbProgress = [:]
        customWords = []
        settings = AppSettings()
        srs = [:]
        pet = PetData()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        collections = try c.decodeIfPresent([WordCollection].self, forKey: .collections) ?? []
        progress = try c.decodeIfPresent([String: WordProgress].self, forKey: .progress) ?? [:]
        verbProgress = try c.decodeIfPresent([String: WordProgress].self, forKey: .verbProgress) ?? [:]
        customWords = try c.decodeIfPresent([CustomWord].self, forKey: .customWords) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        srs = try c.decodeIfPresent([String: SRSState].self, forKey: .srs) ?? [:]
        pet = try c.decodeIfPresent(PetData.self, forKey: .pet) ?? PetData()
    }
}

// MARK: - Хранение на диске

enum Persistence {
    static var baseURL: URL {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = support.appendingPathComponent("OlaPT", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var userFile: URL {
        return baseURL.appendingPathComponent("userdata.json")
    }

    static var packsDirectory: URL {
        let dir = baseURL.appendingPathComponent("Dictionaries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func loadUser() -> UserData {
        let url = userFile
        guard FileManager.default.fileExists(atPath: url.path) else { return UserData() }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(UserData.self, from: data)
        } catch {
            // Не теряем данные молча: сохраняем повреждённый файл рядом и начинаем с чистого листа.
            let backup = baseURL.appendingPathComponent("userdata.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return UserData()
        }
    }

    static func saveUser(_ user: UserData) {
        do {
            let data = try JSONEncoder().encode(user)
            try data.write(to: userFile, options: .atomic)
        } catch {
            // Ошибку записи показывать пользователю нечем; данные останутся в памяти до следующей попытки.
        }
    }

    /// Импортированные пользователем словари.
    static func loadImportedPacks() -> [PackFile] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: packsDirectory, includingPropertiesForKeys: nil) else { return [] }
        var result: [PackFile] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(PackFile.self, from: data) {
                result.append(pack)
            }
        }
        return result
    }

    static func savePack(_ pack: PackFile) throws {
        let data = try JSONEncoder().encode(pack)
        let url = packsDirectory.appendingPathComponent(pack.id + ".json")
        try data.write(to: url, options: .atomic)
    }

    static func deletePack(id: String) {
        let url = packsDirectory.appendingPathComponent(id + ".json")
        try? FileManager.default.removeItem(at: url)
    }
}
