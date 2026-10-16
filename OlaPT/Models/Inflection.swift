import Foundation

/// Формы существительных и прилагательных для поиска слов в тексте:
/// «casas» → casa, «bonitas» → bonito, «animais» → animal, «portuguesa» → português.
/// Генерирует возможные формы с запасом: лишняя форма ничему не мешает, её просто никто не встретит.
enum Inflection {

    /// Местоимения, которые пишутся через дефис после глагола.
    static let clitics: Set<String> = [
        "me", "te", "se", "nos", "vos", "lhe", "lhes",
        "o", "a", "os", "as", "lo", "la", "los", "las", "no", "na", "nas",
        // слитные: me + o = mo, lhe + a = lha…
        "mo", "ma", "mos", "mas", "to", "ta", "tos", "tas", "lho", "lha", "lhos", "lhas"
    ]

    /// Распространённые варианты форм, которых нет в таблицах спряжения.
    static let verbAliases: [String: String] = [
        "oiço": "ouvir", "oiça": "ouvir", "oiças": "ouvir", "oiçamos": "ouvir", "oiçam": "ouvir",
        "doi": "doer"
    ]

    private static let irregularSuperlatives: [String: String] = [
        "facílimo": "fácil", "dificílimo": "difícil", "paupérrimo": "pobre", "boníssimo": "bom",
        "amabilíssimo": "amável", "agradabilíssimo": "agradável", "utilíssimo": "útil"
    ]

    /// Возможные исходные формы для превосходной степени: «lindíssimas» → lindo, linde, lind…
    static func superlativeBases(_ word: String) -> [String] {
        var w = word.lowercased()
        if w.hasSuffix("s") { w.removeLast() }
        if w.hasSuffix("a") { w = String(w.dropLast()) + "o" }   // lindíssima → lindíssimo
        if let irr = irregularSuperlatives[w] { return [irr] }
        guard w.hasSuffix("íssimo"), w.count > 7 else { return [] }
        var stem = String(w.dropLast(6))
        if stem.hasSuffix("qu") { stem = String(stem.dropLast(2)) + "c" }   // riquíssimo → rico
        if stem.hasSuffix("gu") { stem = String(stem.dropLast(2)) + "g" }   // larguíssimo → largo
        return [stem + "o", stem + "e", stem, stem + "a"]
    }

    /// Все формы слова, кроме исходной: множественное число, женский род, женский род во мн. числе.
    static func forms(of w: Word) -> [String] {
        guard w.pos == "n" || w.pos == "adj" || w.pos == "num" || w.pos == "det" || w.pos == "pron" || w.pos == "prep" else {
            return []
        }
        // Выражения из нескольких слов не склоняем.
        if w.pt.contains(" ") { return [] }
        var out: [String] = []
        if !w.plural.isEmpty {
            out.append(w.plural)
        } else if w.pos == "n" || w.pos == "adj" || w.pos == "det" || w.pos == "prep" {
            out.append(contentsOf: plurals(of: w.pt))
        }
        if !w.feminine.isEmpty && w.feminine != w.pt {
            out.append(w.feminine)
            out.append(contentsOf: plurals(of: w.feminine))
        }
        return out.filter { $0.lowercased() != w.pt.lowercased() }
    }

    /// Возможные формы множественного числа по правилам.
    static func plurals(of word: String) -> [String] {
        let w = word
        guard let last = w.last else { return [] }
        let lower = w.lowercased()
        if lower.hasSuffix("ão") {
            let stem = String(w.dropLast(2))
            return [stem + "ões", stem + "ães", stem + "ãos"]
        }
        if lower.hasSuffix("al") { return [String(w.dropLast(2)) + "ais"] }
        if lower.hasSuffix("el") {
            let stem = String(w.dropLast(2))
            return [stem + "éis", stem + "eis"]
        }
        if lower.hasSuffix("ol") { return [String(w.dropLast(2)) + "óis"] }
        if lower.hasSuffix("ul") { return [String(w.dropLast(2)) + "uis"] }
        if lower.hasSuffix("il") {
            let stem = String(w.dropLast(2))
            return [stem + "is", stem + "eis"]
        }
        if last == "m" { return [String(w.dropLast()) + "ns"] }
        if last == "r" || last == "z" { return [w + "es"] }
        if last == "s" {
            // país → países, mês → meses, inglês → ingleses; lápis не меняется
            return [w + "es", deaccentLastVowel(w) + "es"]
        }
        if last == "x" { return [] }
        if "aeiouáéíóúâêôã".contains(last) { return [w + "s"] }
        return []
    }

    /// «mês» → «mes», «inglês» → «ingles» (ударение уходит при добавлении слога).
    static func deaccentLastVowel(_ word: String) -> String {
        var chars = Array(word)
        let map: [Character: Character] = ["á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "â": "a", "ê": "e", "ô": "o"]
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            if let plain = map[chars[i]] {
                chars[i] = plain
                break
            }
        }
        return String(chars)
    }

    /// «comprá-lo» → comprar, «fazê-lo» → fazer, «parti-lo» → partir, «pô-lo» → pôr.
    static func infinitivesBeforeLo(_ stem: String) -> [String] {
        guard let last = stem.last else { return [] }
        let base = String(stem.dropLast())
        switch last {
        case "á": return [base + "ar"]
        case "ê": return [base + "er"]
        case "í", "i": return [base + "ir"]
        case "ô": return [base + "ôr", base + "or"]
        default: return []
        }
    }
}
