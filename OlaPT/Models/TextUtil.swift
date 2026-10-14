import Foundation

/// Нормализация текста для поиска и проверки ответов.
enum TextUtil {

    // MARK: - Поиск

    /// Для поиска: нижний регистр, без диакритики и знаков препинания, пробелы схлопнуты.
    /// Дефисы и апострофы превращаются в пробелы («pequeno-almoço» → «pequeno almoco»).
    static func fold(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.folding(options: [.diacriticInsensitive], locale: nil)
        return collapse(removePunctuation(stripped))
    }

    static func removePunctuation(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else if ch == "-" || ch == "–" || ch == "—" || ch == "'" || ch == "’" || ch.isWhitespace {
                out.append(" ")
            }
        }
        return out
    }

    static func collapse(_ text: String) -> String {
        return text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// Убирает пояснения в скобках: «спасибо (говорит мужчина)» → «спасибо».
    static func stripParentheses(_ text: String) -> String {
        var depth = 0
        var out = ""
        for ch in text {
            if ch == "(" {
                depth += 1
                continue
            }
            if ch == ")" {
                if depth > 0 { depth -= 1 }
                continue
            }
            if depth == 0 { out.append(ch) }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Проверка ответов

    /// Нормализация ответа пользователя / эталона.
    /// - Parameters:
    ///   - lang: "pt", "en", "ru" или другой код языка
    ///   - keepAccents: true — различать диакритику (для португальского)
    ///   - keepParentheses: true — пояснение в скобках считается частью перевода
    ///     (так «be (permanent)» и «be (temporary)» не принимаются за синонимы)
    static func normalizeAnswer(_ text: String, lang: String, keepAccents: Bool, keepParentheses: Bool = false) -> String {
        var t = (keepParentheses ? text : stripParentheses(text)).lowercased()
        t = t.replacingOccurrences(of: "ё", with: "е")
        if lang == "pt" && !keepAccents {
            t = t.folding(options: [.diacriticInsensitive], locale: nil)
        }
        t = collapse(removePunctuation(t))
        if lang == "en" {
            for prefix in ["to ", "the ", "a ", "an "] {
                if t.hasPrefix(prefix) && t.count > prefix.count {
                    t = String(t.dropFirst(prefix.count))
                    break
                }
            }
        }
        return t
    }

    static let ptArticles: Set<String> = ["o", "a", "os", "as", "um", "uma", "uns", "umas"]

    /// «a casa» → «casa»
    static func stripLeadingArticle(_ text: String) -> String {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 && ptArticles.contains(String(parts[0])) {
            return String(parts[1])
        }
        return text
    }

    /// Нормализация для проверки спряжений: строгая (с диакритикой), но без регистра и лишних пробелов.
    static func normalizeVerbForm(_ text: String) -> String {
        var t = text.lowercased()
        t = t.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        t = t.replacingOccurrences(of: "’", with: "'")
        let allowed: (Character) -> Bool = { $0.isLetter || $0 == "-" || $0 == " " }
        t = String(t.filter(allowed))
        // «chamo - me» → «chamo-me»
        t = t.replacingOccurrences(of: " - ", with: "-")
        return collapse(t)
    }
}
