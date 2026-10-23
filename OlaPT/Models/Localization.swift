import Foundation

// MARK: - Язык интерфейса

/// Язык интерфейса: русский или английский. Переключается в настройках без перезапуска.
///
/// Строки интерфейса пишутся в коде по-русски и проходят через `L(...)`; английские переводы лежат
/// в OlaPT/Resources/ui-en.json (ключ — русский текст). Строки с числами и именами — шаблоны
/// `L("Добавлено %d слов в «%@»", n, name)`. Проверка, что ничего не пропущено и у каждого ключа
/// есть перевод: Tools/l10n.py (запускается в сборке на GitHub). Это единственный файл,
/// где русские строки могут стоять без `L(...)`.
enum Loc {
    static let supported = ["ru", "en"]

    /// "ru" или "en"
    private(set) static var lang = "ru"
    private static var english: [String: String] = [:]
    private static var loaded = false

    static var isEnglish: Bool { return lang == "en" }

    static func set(_ code: String) {
        lang = code == "en" ? "en" : "ru"
        if lang == "en" && !loaded {
            loaded = true
            if let url = Bundle.main.findResource("ui-en", ext: "json"),
               let data = try? Data(contentsOf: url),
               let map = try? JSONDecoder().decode([String: String].self, from: data) {
                english = map
            }
        }
    }

    static func tr(_ ru: String) -> String {
        if lang == "ru" { return ru }
        return english[ru] ?? ru
    }

    /// Язык новой установки: русский, если русский есть среди языков iPhone и стоит выше английского;
    /// иначе английский. Те, кто пользовался приложением до 1.3, остаются на русском (см. AppSettings).
    static func systemDefault() -> String {
        for code in Locale.preferredLanguages {
            let base = String(code.prefix(2)).lowercased()
            if base == "ru" { return "ru" }
            if base == "en" { return "en" }
        }
        return "en"
    }

    /// Название языка для настроек — на нём самом.
    static func nativeName(_ code: String) -> String {
        switch code {
        case "ru": return "Русский"
        case "en": return "English"
        default: return code
        }
    }
}

/// Строка интерфейса на текущем языке. Ключ — русский текст.
func L(_ ru: String) -> String {
    return Loc.tr(ru)
}

/// Шаблон с подстановками (%d, %@): `L("Слов: %d", n)`.
func L(_ ru: String, _ args: CVarArg...) -> String {
    return String(format: Loc.tr(ru), arguments: args)
}

// MARK: - Числа и слова

/// «1 слово, 2 слова, 5 слов» / «1 word, 2 words».
enum Plural {
    private static func pick(_ n: Int, _ one: String, _ few: String, _ many: String, en: (String, String)) -> String {
        if Loc.isEnglish { return n == 1 ? en.0 : en.1 }
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return many }
        if mod10 == 1 { return one }
        if mod10 >= 2 && mod10 <= 4 { return few }
        return many
    }

    static func forms(_ n: Int) -> String { return pick(n, "форма", "формы", "форм", en: ("form", "forms")) }
    static func phrases(_ n: Int) -> String { return pick(n, "фраза", "фразы", "фраз", en: ("phrase", "phrases")) }
    static func spells(_ n: Int) -> String { return pick(n, "заклинание", "заклинания", "заклинаний", en: ("spell", "spells")) }
    static func weeks(_ n: Int) -> String { return pick(n, "неделя", "недели", "недель", en: ("week", "weeks")) }
    static func months(_ n: Int) -> String { return pick(n, "месяц", "месяца", "месяцев", en: ("month", "months")) }
    static func days(_ n: Int) -> String { return pick(n, "день", "дня", "дней", en: ("day", "days")) }
    static func words(_ n: Int) -> String { return pick(n, "слово", "слова", "слов", en: ("word", "words")) }
}
