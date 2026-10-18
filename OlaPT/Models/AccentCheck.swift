import Foundation

/// Раскраска ввода: сколько первых символов верны (без учёта диакритики)
/// и в каких из них не хватает акцента или седили.
struct AnswerColoring: Equatable {
    var prefix: Int
    var accentSlips: Set<Int>

    static let empty = AnswerColoring(prefix: 0, accentSlips: [])
}

/// Ответ, засчитанный без нужного акцента: показываем в итогах тренировки.
struct AccentSlip: Identifiable {
    let id = UUID()
    /// Слово или пара «глагол + время» — чтобы не повторять одно и то же дважды
    let key: String
    let typed: String
    let answer: String
}

/// Сравнение ответов с точностью до диакритики: «falamos» и «falámos», «licao» и «lição».
enum AccentCheck {
    /// Буква без диакритики, в нижнем регистре; дефис и тире — как пробел.
    static func plain(_ ch: Character) -> String {
        return letter(ch).folding(options: [.diacriticInsensitive], locale: nil)
    }

    /// Буква в нижнем регистре; дефис и тире — как пробел, типографский апостроф — как обычный.
    static func letter(_ ch: Character) -> String {
        var s = String(ch).lowercased()
        if s == "-" || s == "–" || s == "—" { s = " " }
        if s == "’" { s = "'" }
        return s
    }

    static func fold(_ text: String) -> String {
        return text.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
    }

    /// Раскраска ввода по лучшему из правильных ответов: длиннее верное начало, меньше пропущенных акцентов.
    static func coloring(input: String, answers: [String]) -> AnswerColoring {
        let typed = Array(input)
        var best = AnswerColoring.empty
        for answer in answers {
            let target = Array(answer)
            var n = 0
            var slips = Set<Int>()
            while n < typed.count && n < target.count {
                if letter(typed[n]) == letter(target[n]) {
                    n += 1
                } else if plain(typed[n]) == plain(target[n]) {
                    slips.insert(n)
                    n += 1
                } else {
                    break
                }
            }
            if n > best.prefix || (n == best.prefix && slips.count < best.accentSlips.count) {
                best = AnswerColoring(prefix: n, accentSlips: slips)
            }
            if best.prefix == typed.count && best.accentSlips.isEmpty { break }
        }
        return best
    }

    /// Позиции букв в `answer`, где ввод отличается только диакритикой.
    /// Ввод может быть с артиклем или местоимением, а ответ — без них, и наоборот.
    static func slips(typed: String, answer: String) -> Set<Int> {
        let a = Array(answer)
        let t = Array(typed.trimmingCharacters(in: .whitespacesAndNewlines))
        let fa = a.map(plain).joined()
        let ft = t.map(plain).joined()
        // Сдвиг, при котором ответ совпадает с частью ввода (или ввод — с частью ответа)
        var offset: Int? = nil
        if let r = ft.range(of: fa) {
            offset = ft.distance(from: ft.startIndex, to: r.lowerBound)
        } else if let r = fa.range(of: ft) {
            offset = -fa.distance(from: fa.startIndex, to: r.lowerBound)
        }
        var result = Set<Int>()
        for (i, ch) in a.enumerated() {
            let hasMark = plain(ch) != letter(ch)
            guard let off = offset else {
                if hasMark { result.insert(i) }
                continue
            }
            let j = i + off
            if j < 0 || j >= t.count { continue }
            if letter(t[j]) != letter(ch) && plain(t[j]) == plain(ch) {
                result.insert(i)
            }
        }
        return result
    }
}
