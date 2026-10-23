import Foundation

// MARK: - Банк фраз (Resources/phrases.json, собирается Tools/build_data.py из Tools/phrases/*.txt)

/// Одна строка упражнения: подсказка по-русски и правильные ответы.
struct PhraseLine: Codable, Hashable {
    /// Лицо: eu, tu, ele, ela, nós, eles; пусто — готовая фраза
    let p: String
    let ru: String
    /// Подсказка по-английски (нет в старых файлах)
    let en: String?
    /// Ответ, как его показывать: «Estou com fome.»
    let show: String
    /// Другие правильные варианты: «Tenho fome.»
    let also: [String]
    /// Все принимаемые ответы без регистра и знаков препинания
    let accept: [String]
    /// Слова ответа для «Собери фразу»
    let tiles: [String]
    /// Лишние слова-ловушки
    let extra: [String]

    /// Подсказка на языке интерфейса: «Я хочу есть.» / «I'm hungry.»
    var prompt: String { return Loc.isEnglish ? (en ?? ru) : ru }
}

struct PhraseItem: Codable, Identifiable, Hashable {
    let id: String
    /// person — выражение в лицах («estar com fome»), fixed — готовая фраза («A conta, por favor.»)
    let kind: String
    /// Варианты выражения: ["estar com fome", "ter fome"]
    let pt: [String]
    let en: String
    let ru: String
    let note: String
    let noteEn: String?
    let lines: [PhraseLine]

    /// Смысл на языке интерфейса: «хотеть есть» / «to be hungry»
    var meaning: String { return Loc.isEnglish ? en : ru }
    /// Пояснение на языке интерфейса (в английском — только английское)
    var localNote: String { return Loc.isEnglish ? (noteEn ?? "") : note }

    var isPerson: Bool { return kind == "person" }
    /// Заголовок для списка: «estar com fome / ter fome»
    var title: String { return isPerson ? pt.joined(separator: " / ") : (lines.first?.show ?? pt.first ?? "") }
}

struct PhraseSet: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String?
    let level: String
    let items: [PhraseItem]

    /// Название на языке интерфейса
    var title: String { return Loc.isEnglish ? (nameEn ?? name) : name }
}

struct PhraseFile: Codable {
    let format: Int?
    let sets: [PhraseSet]
}

final class PhraseBank {
    let sets: [PhraseSet]
    let byID: [String: PhraseItem]

    init(sets: [PhraseSet]) {
        self.sets = sets
        var map: [String: PhraseItem] = [:]
        for s in sets {
            for it in s.items { map[it.id] = it }
        }
        self.byID = map
    }

    /// Все фразы по порядку наборов (так же по порядку они попадают в план дня)
    var allItems: [PhraseItem] { return sets.flatMap { $0.items } }

    static func load() -> PhraseBank {
        guard let url = Bundle.main.findResource("phrases", ext: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PhraseFile.self, from: data) else {
            return PhraseBank(sets: [])
        }
        return PhraseBank(sets: file.sets)
    }

    // MARK: Проверка ответа

    /// Нормализация как в Tools/phrasebank.py: нижний регистр, без знаков препинания, одинарные пробелы.
    static func normalize(_ text: String) -> String {
        let punct = CharacterSet(charactersIn: ".,!?¿¡;:«»\"“”()…")
        let lowered = text.lowercased()
        var out = ""
        for ch in lowered.unicodeScalars {
            out.unicodeScalars.append(punct.contains(ch) ? " " : ch)
        }
        return out.split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
    }

    /// exact — точно; accentsOnly — верно, кроме диакритики; wrong — неверно.
    static func verdict(_ input: String, line: PhraseLine) -> AnswerVerdict {
        let typed = normalize(input)
        if typed.isEmpty { return .wrong }
        if line.accept.contains(typed) { return .exact }
        let folded = AccentCheck.fold(typed)
        if line.accept.contains(where: { AccentCheck.fold($0) == folded }) { return .accentsOnly }
        return .wrong
    }

    /// Правильный ответ, с которым ввод совпал без учёта диакритики (для подсветки акцентов).
    static func accentMatch(_ input: String, line: PhraseLine) -> String? {
        let folded = AccentCheck.fold(normalize(input))
        guard line.accept.contains(where: { AccentCheck.fold($0) == folded }) else { return nil }
        // показываем из «show» и «also» тот вариант, что совпал
        for s in [line.show] + line.also where AccentCheck.fold(normalize(s)) == folded {
            return s
        }
        return line.show
    }
}

// MARK: - Вопрос упражнения «Фразы»

struct PhraseQuestion: Identifiable {
    let id = UUID()
    let item: PhraseItem
    let line: PhraseLine
    /// true — набрать с клавиатуры, false — собрать из слов
    let typing: Bool
    /// Плитки в случайном порядке (слова ответа + ловушки)
    let tiles: [String]
    var isRetry = false

    static func make(item: PhraseItem, typing: Bool) -> PhraseQuestion {
        let line = item.lines.randomElement() ?? item.lines[0]
        return make(item: item, line: line, typing: typing)
    }

    static func make(item: PhraseItem, line: PhraseLine, typing: Bool) -> PhraseQuestion {
        return PhraseQuestion(item: item, line: line, typing: typing, tiles: (line.tiles + line.extra).shuffled())
    }
}
