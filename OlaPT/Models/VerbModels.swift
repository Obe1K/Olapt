import Foundation

// MARK: - Формат verbs.json

struct TenseInfo: Codable, Hashable, Identifiable {
    var id: String
    var name: String      // Pretérito Perfeito
    var ru: String        // пояснение по-русски
    var en: String?       // пояснение по-английски
    var group: String
    var groupRu: String
    var groupEn: String?
    var prefix: String    // que / se / quando / para — для сослагательного и личного инфинитива
    var labels: [String]  // eu, tu, ele/ela/você, nós, eles/elas/vocês (пустая строка — формы нет)

    /// Пояснение на языке интерфейса: «Настоящее время» / «Present tense»
    var desc: String { return Loc.isEnglish ? (en ?? ru) : ru }
    /// Наклонение на языке интерфейса
    var groupTitle: String { return Loc.isEnglish ? (groupEn ?? groupRu) : groupRu }
}

struct Verb: Codable, Hashable, Identifiable {
    var inf: String
    var base: String
    var reflexive: Bool
    var group: String
    var irregular: Bool
    var gerund: String
    var participle: String
    var forms: [String: [String]]

    var id: String { return inf }

    /// Слово-ключ в словаре: «falar|v».
    var wordID: String { return Word.makeID(pt: inf, pos: "v") }

    func form(_ tenseID: String, _ person: Int) -> String {
        guard let list = forms[tenseID], person >= 0, person < list.count else { return "" }
        return list[person]
    }
}

struct VerbFile: Codable {
    var format: Int?
    var tenses: [TenseInfo]
    var verbs: [Verb]
}

struct TenseGroup: Identifiable {
    let id: String
    let name: String
    let tenses: [TenseInfo]
}

// MARK: - Библиотека глаголов

struct VerbLetterSection: Identifiable {
    let letter: String
    let verbs: [Verb]
    var id: String { return letter }
}

final class VerbLibrary {
    let tenses: [TenseInfo]
    /// В порядке частотности (для упражнений)
    let verbs: [Verb]
    /// По алфавиту (португальский порядок без учёта акцентов: «à» рядом с «a»)
    let alphabetical: [Verb]
    /// Алфавит по первым буквам — для списка на вкладке «Глаголы»
    let letterSections: [VerbLetterSection]
    /// Инфинитив без акцентов и дефисов — для поиска
    let foldedInf: [String: String]
    let byInf: [String: Verb]
    let byWordID: [String: Verb]
    let loadError: String?

    init(tenses: [TenseInfo], verbs: [Verb], loadError: String? = nil) {
        self.tenses = tenses
        self.verbs = verbs
        var map: [String: Verb] = [:]
        var map2: [String: Verb] = [:]
        var folded: [String: String] = [:]
        for v in verbs {
            map[v.inf] = v
            map2[v.wordID] = v
            folded[v.inf] = TextUtil.fold(v.inf)
        }
        let sorted = verbs.sorted { a, b in
            let fa = folded[a.inf] ?? a.inf, fb = folded[b.inf] ?? b.inf
            return fa != fb ? fa < fb : a.inf < b.inf
        }
        var sections: [VerbLetterSection] = []
        var current = ""
        var bucket: [Verb] = []
        for v in sorted {
            let letter = String((folded[v.inf] ?? v.inf).prefix(1)).uppercased()
            if letter != current, !bucket.isEmpty {
                sections.append(VerbLetterSection(letter: current, verbs: bucket))
                bucket = []
            }
            current = letter
            bucket.append(v)
        }
        if !bucket.isEmpty { sections.append(VerbLetterSection(letter: current, verbs: bucket)) }
        self.alphabetical = sorted
        self.letterSections = sections
        self.foldedInf = folded
        self.byInf = map
        self.byWordID = map2
        self.loadError = loadError
    }

    static func load() -> VerbLibrary {
        guard let url = Bundle.main.findResource("verbs", ext: "json") else {
            return VerbLibrary(tenses: [], verbs: [], loadError: L("Файл verbs.json не найден в приложении."))
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(VerbFile.self, from: data)
            return VerbLibrary(tenses: file.tenses, verbs: file.verbs)
        } catch {
            return VerbLibrary(tenses: [], verbs: [], loadError: L("Не удалось прочитать verbs.json: %@", error.localizedDescription))
        }
    }

    func tense(_ id: String) -> TenseInfo? {
        return tenses.first { $0.id == id }
    }

    func verb(forWordID id: String) -> Verb? {
        return byWordID[id]
    }

    /// Времена, сгруппированные по наклонениям, в порядке появления.
    var tenseGroups: [TenseGroup] {
        var order: [String] = []
        var names: [String: String] = [:]
        var buckets: [String: [TenseInfo]] = [:]
        for t in tenses {
            if buckets[t.group] == nil {
                order.append(t.group)
                names[t.group] = t.groupTitle
                buckets[t.group] = []
            }
            buckets[t.group]?.append(t)
        }
        return order.map { key in
            TenseGroup(id: key, name: names[key] ?? key, tenses: buckets[key] ?? [])
        }
    }

    /// Индексы лиц, для которых в этом времени есть форма (в повелительном нет «eu»).
    func activePersons(_ tense: TenseInfo) -> [Int] {
        var list: [Int] = []
        for (i, label) in tense.labels.enumerated() where !label.isEmpty {
            list.append(i)
        }
        return list
    }

    /// Ключ прогресса для пары «глагол + время».
    static func progressKey(verb: Verb, tense: TenseInfo) -> String {
        return verb.inf + "|" + tense.id
    }
}
