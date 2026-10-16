import Foundation

/// Слово (или выражение) из распознанного текста.
struct ScanToken: Identifiable, Hashable {
    let id: Int
    /// Как написано в тексте
    let text: String
    /// Слово из словаря или nil, если такого нет
    let word: Word?
    /// Пояснение: «форма глагола «falar»»
    let hint: String

    /// Ключ выбора: одинаковые слова в тексте выбираются вместе.
    var key: String {
        if let w = word { return w.id }
        return "?" + TextUtil.fold(text)
    }

    /// Форма из словаря, если она отличается от написанной в тексте.
    var lemma: String? {
        guard let w = word else { return nil }
        if TextUtil.fold(w.pt) == TextUtil.fold(text) { return nil }
        return w.pt
    }

    static func == (a: ScanToken, b: ScanToken) -> Bool { return a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Разбивает распознанный текст на слова и находит их в словаре.
enum TextScanner {

    /// Символы, которые срезаются по краям слова.
    private static func isEdgePunctuation(_ ch: Character) -> Bool {
        return !(ch.isLetter || ch.isNumber)
    }

    /// Очищает слово от знаков препинания по краям: «(casa),» → «casa».
    static func clean(_ piece: Substring) -> String {
        var s = String(piece)
        s = s.replacingOccurrences(of: "’", with: "'")
        while let f = s.first, isEdgePunctuation(f) { s.removeFirst() }
        while let l = s.last, isEdgePunctuation(l) { s.removeLast() }
        return s
    }

    private static func hasLetters(_ s: String) -> Bool {
        return s.contains(where: { $0.isLetter })
    }

    /// Слова по строкам; перенос «infor-» + «mação» склеивается.
    static func words(from lines: [String], index: DictionaryIndex) -> [String] {
        var rows: [[String]] = []
        for line in lines {
            let normalized = line
                .replacingOccurrences(of: "/", with: " ")
                .replacingOccurrences(of: "—", with: " ")
                .replacingOccurrences(of: "–", with: " ")
                .replacingOccurrences(of: "…", with: " ")
            let pieces = normalized.split(whereSeparator: { $0.isWhitespace })
            rows.append(pieces.map { String($0) })
        }

        var result: [String] = []
        var carry: String?
        for (r, row) in rows.enumerated() {
            for (k, rawPiece) in row.enumerated() {
                var piece = rawPiece
                if let c = carry {
                    // Перенос с предыдущей строки
                    let next = clean(Substring(piece))
                    let joinedPlain = c + next
                    let joinedHyphen = c + "-" + next
                    if index.lookupToken(joinedPlain) != nil {
                        piece = joinedPlain
                    } else if index.lookupToken(joinedHyphen) != nil {
                        piece = joinedHyphen
                    } else {
                        piece = joinedPlain
                    }
                    carry = nil
                }
                let isLastInRow = k == row.count - 1
                if isLastInRow && r < rows.count - 1 && piece.hasSuffix("-") && piece.count > 2 {
                    let stem = clean(Substring(piece))
                    if let firstNext = rows[r + 1].first,
                       let ch = clean(Substring(firstNext)).first, ch.isLowercase {
                        carry = stem
                        continue
                    }
                }
                let word = clean(Substring(piece))
                if hasLetters(word) { result.append(word) }
            }
        }
        if let c = carry, hasLetters(c) { result.append(c) }
        return result
    }

    /// Слова текста с найденными переводами; выражения из нескольких слов собираются в один элемент.
    static func tokens(from lines: [String], index: DictionaryIndex) -> [ScanToken] {
        let list = words(from: lines, index: index)
        var tokens: [ScanToken] = []
        var i = 0
        while i < list.count {
            var matched = false
            let longest = min(index.maxPhraseWords, list.count - i)
            if longest >= 2 {
                for n in stride(from: longest, through: 2, by: -1) {
                    let slice = Array(list[i..<(i + n)])
                    if let w = index.lookupPhrase(slice) {
                        tokens.append(ScanToken(id: tokens.count, text: slice.joined(separator: " "), word: w, hint: ""))
                        i += n
                        matched = true
                        break
                    }
                }
            }
            if matched { continue }
            let text = list[i]
            if let found = index.lookupToken(text) {
                tokens.append(ScanToken(id: tokens.count, text: text, word: found.word, hint: found.hint))
            } else {
                tokens.append(ScanToken(id: tokens.count, text: text, word: nil, hint: ""))
            }
            i += 1
        }
        return tokens
    }

    /// Служебные слова, которые не выбираются кнопкой «Выбрать новые».
    static let functionPOS: Set<String> = ["prep", "conj", "det", "pron", "num", "interj"]
}
