import Foundation

// MARK: - Формат словаря (JSON-файл)

/// Файл словаря. Такой же формат используется для встроенных и импортируемых словарей.
struct PackFile: Codable {
    var format: Int?
    var id: String
    var name: String
    var lang: String
    var langName: String?
    var variant: String?
    var version: Int?
    var topics: [TopicInfo]?
    var entries: [PackEntry]
}

struct TopicInfo: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// Название по-английски (во встроенных словарях)
    var nameEn: String?

    /// Название на языке интерфейса
    var title: String {
        return Loc.isEnglish ? (nameEn ?? name) : name
    }
}

struct PackEntry: Codable {
    var pt: String
    var pos: String?
    var g: String?
    var f: String?
    var pl: String?
    var tr: [String]
    var topic: String?
    var br: String?
    var note: String?
    /// Уровень CEFR: "A1", "A2", "B1"… (необязательно)
    var lv: String?
}

/// Краткая информация о словаре для экрана «Словари».
struct PackInfo: Identifiable, Hashable {
    let id: String
    var name: String
    var lang: String
    var langName: String
    var entryCount: Int
    var isBundled: Bool
}

// MARK: - Слово (объединённая карточка)

/// Португальское слово со всеми переводами из всех подключённых словарей.
struct Word: Identifiable, Hashable {
    let id: String
    var pt: String
    var pos: String
    var gender: String
    var feminine: String
    var plural: String
    var topic: String
    var brazilian: String
    var note: String
    var translations: [String: [String]]
    var isCustom: Bool
    /// Уровень CEFR («A1», «A2», «B1») или пустая строка.
    var level: String = ""
    /// Пояснение по-английски (из английского словаря); `note` — по-русски или из других словарей.
    var noteEn: String = ""

    /// Пояснение на языке интерфейса. В английском интерфейсе русское не показываем.
    var localNote: String {
        if Loc.isEnglish { return noteEn }
        return note.isEmpty ? noteEn : note
    }

    static func makeID(pt: String, pos: String) -> String {
        return pt.lowercased() + "|" + pos
    }

    var isVerb: Bool { return pos == "v" }

    /// Определённый артикль для существительных: o / a / o/a.
    var article: String {
        if pos != "n" { return "" }
        guard let first = pt.first, first.isLowercase else { return "" }
        switch gender {
        case "m": return "o"
        case "f": return "a"
        case "mf": return "o/a"
        default: return ""
        }
    }

    /// «a casa», «o/a colega», «bom» — как показывать слово.
    var titleWithArticle: String {
        return article.isEmpty ? pt : article + " " + pt
    }

    /// Полная форма ответа: «o miúdo / a miúda», «bonito / bonita».
    var answerDisplay: String {
        if feminine.isEmpty || feminine == pt { return titleWithArticle }
        if pos == "n" {
            return titleWithArticle + " / a " + feminine
        }
        return pt + " / " + feminine
    }

    /// Все варианты написания, которые засчитываются как верный ответ.
    var ptVariants: [String] {
        var list: [String] = [pt]
        if pos == "n" && article == "o/a" {
            list.append("o " + pt)
            list.append("a " + pt)
        } else if !article.isEmpty {
            list.append(article + " " + pt)
        }
        if !feminine.isEmpty && feminine != pt {
            list.append(feminine)
            if pos == "n" { list.append("a " + feminine) }
        }
        return list
    }

    var genderLabel: String {
        switch gender {
        case "m": return L("м. р.")
        case "f": return L("ж. р.")
        case "mf": return L("м./ж. р.")
        default: return ""
        }
    }

    /// «сущ., м. р.» / «глагол» / «прил.»
    var posLine: String {
        var parts: [String] = []
        let p = PartOfSpeech.label(pos)
        if !p.isEmpty { parts.append(p) }
        if pos == "n" && !genderLabel.isEmpty { parts.append(genderLabel) }
        return parts.joined(separator: ", ")
    }

    func tr(_ lang: String) -> [String] {
        return translations[lang] ?? []
    }

    /// Переводы одной строкой: «дом, жильё».
    func translationText(lang: String, limit: Int = 3) -> String {
        let list = tr(lang)
        return list.prefix(limit).joined(separator: ", ")
    }

    func hasTranslation(lang: String) -> Bool {
        return !tr(lang).isEmpty
    }
}

// MARK: - Справочники

enum PartOfSpeech {
    static func label(_ pos: String) -> String {
        switch pos {
        case "n": return L("сущ.")
        case "v": return L("глагол")
        case "adj": return L("прил.")
        case "adv": return L("нареч.")
        case "prep": return L("предлог")
        case "conj": return L("союз")
        case "pron": return L("местоим.")
        case "det": return L("определит.")
        case "num": return L("числит.")
        case "interj": return L("межд.")
        case "phrase": return L("фраза")
        default: return ""
        }
    }

    /// Допустимые значения для пользовательских слов.
    static let choices: [String] = ["n", "v", "adj", "adv", "phrase", "prep", "conj", "pron", "num", "interj"]
}

enum Languages {
    /// Вычисляется при каждом обращении — чтобы следовать языку интерфейса.
    static var names: [String: String] {
        return [
        "en": L("Английский"), "ru": L("Русский"), "uk": L("Украинский"), "es": L("Испанский"),
        "fr": L("Французский"), "de": L("Немецкий"), "it": L("Итальянский"), "pl": L("Польский"),
        "nl": L("Нидерландский"), "tr": L("Турецкий"), "zh": L("Китайский"), "ja": L("Японский"),
        "ar": L("Арабский"), "pt": L("Португальский")
        ]
    }

    /// Языки, которые можно выбрать при импорте CSV.
    static let importable: [String] = ["en", "ru", "uk", "es", "fr", "de", "it", "pl", "nl", "tr", "zh", "ja", "ar"]

    static func name(_ code: String) -> String {
        return names[code] ?? code.uppercased()
    }
}

extension Bundle {
    /// Ищет файл ресурса и в корне бандла, и в типичных подпапках
    /// (Xcode может сохранять или «разворачивать» структуру папок).
    func findResource(_ name: String, ext: String) -> URL? {
        if let u = url(forResource: name, withExtension: ext) { return u }
        for sub in ["Resources", "Dictionaries", "Resources/Dictionaries", "Data"] {
            if let u = url(forResource: name, withExtension: ext, subdirectory: sub) { return u }
        }
        return nil
    }
}
