import Foundation

struct SearchResult: Identifiable {
    let word: Word
    let score: Int
    let hint: String
    var id: String { return word.id }
}

/// Найденная форма спряжения: «falou» → falar, Pretérito Perfeito, ele/ela/você.
struct VerbFormHit {
    let verbWordID: String
    let infinitive: String
    let tenseName: String
    let personLabel: String
    let form: String
}

/// Объединённый индекс всех подключённых словарей: слова, поиск, темы.
final class DictionaryIndex {
    let words: [Word]
    let byID: [String: Word]
    let languages: [String]
    let topics: [TopicInfo]
    /// язык → нормализованный перевод → id слов с таким переводом (для синонимов в упражнениях)
    let translationIndex: [String: [String: Set<String>]]

    private let wordsByTopic: [String: [Word]]
    private let foldedPT: [String]
    private let foldedTr: [[String]]
    private let formIndex: [String: [VerbFormHit]]

    init(packs: [PackFile], custom: [Word], verbs: VerbLibrary) {
        var ordered: [Word] = []
        var posKeyToIndex: [String: Int] = [:]
        var firstByPT: [String: Int] = [:]
        var topicList: [TopicInfo] = []
        var seenTopics = Set<String>()
        var langs: [String] = []

        for pack in packs {
            if !langs.contains(pack.lang) { langs.append(pack.lang) }
            for t in pack.topics ?? [] {
                if !seenTopics.contains(t.id) {
                    seenTopics.insert(t.id)
                    topicList.append(t)
                }
            }
            for e in pack.entries {
                let pt = e.pt.trimmingCharacters(in: .whitespacesAndNewlines)
                if pt.isEmpty { continue }
                let pos = (e.pos ?? "").trimmingCharacters(in: .whitespaces)
                let lowerPT = pt.lowercased()
                var found: Int? = posKeyToIndex[lowerPT + "|" + pos]
                if found == nil && pos.isEmpty {
                    found = firstByPT[lowerPT]
                }
                if found == nil {
                    let w = Word(
                        id: Word.makeID(pt: pt, pos: pos),
                        pt: pt, pos: pos,
                        gender: e.g ?? "", feminine: e.f ?? "", plural: e.pl ?? "",
                        topic: e.topic ?? "", brazilian: e.br ?? "", note: e.note ?? "",
                        translations: [:], isCustom: false)
                    ordered.append(w)
                    let newIndex = ordered.count - 1
                    posKeyToIndex[lowerPT + "|" + pos] = newIndex
                    if firstByPT[lowerPT] == nil { firstByPT[lowerPT] = newIndex }
                    found = newIndex
                }
                guard let i = found else { continue }
                if ordered[i].gender.isEmpty, let g = e.g { ordered[i].gender = g }
                if ordered[i].feminine.isEmpty, let f = e.f { ordered[i].feminine = f }
                if ordered[i].plural.isEmpty, let p = e.pl { ordered[i].plural = p }
                if ordered[i].topic.isEmpty, let tp = e.topic { ordered[i].topic = tp }
                if ordered[i].brazilian.isEmpty, let b = e.br { ordered[i].brazilian = b }
                if ordered[i].note.isEmpty, let n = e.note { ordered[i].note = n }
                var list = ordered[i].translations[pack.lang] ?? []
                for t in e.tr {
                    let tt = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tt.isEmpty && !list.contains(tt) { list.append(tt) }
                }
                ordered[i].translations[pack.lang] = list
            }
        }

        for w in custom {
            ordered.append(w)
            for lang in w.translations.keys where !langs.contains(lang) {
                langs.append(lang)
            }
        }

        var byIDMap: [String: Word] = [:]
        var topicMap: [String: [Word]] = [:]
        var fPT: [String] = []
        var fTr: [[String]] = []
        var trIndex: [String: [String: Set<String>]] = [:]
        for w in ordered {
            byIDMap[w.id] = w
            if !w.topic.isEmpty {
                topicMap[w.topic, default: []].append(w)
            }
            fPT.append(TextUtil.fold(w.pt))
            var folded: [String] = []
            for (lang, list) in w.translations {
                for t in list {
                    let plain = TextUtil.stripParentheses(t)
                    folded.append(TextUtil.fold(plain))
                    let key = TextUtil.normalizeAnswer(t, lang: lang, keepAccents: true, keepParentheses: true)
                    if !key.isEmpty {
                        trIndex[lang, default: [:]][key, default: []].insert(w.id)
                    }
                }
            }
            fTr.append(folded)
        }

        // Индекс форм глаголов: «falou» → falar
        var forms: [String: [VerbFormHit]] = [:]
        for v in verbs.verbs where !v.reflexive {
            func add(_ form: String, tenseName: String, label: String) {
                let key = TextUtil.fold(form)
                if key.isEmpty || key.contains(" ") { return }
                var list = forms[key] ?? []
                if list.contains(where: { $0.verbWordID == v.wordID }) { return }
                list.append(VerbFormHit(verbWordID: v.wordID, infinitive: v.inf,
                                        tenseName: tenseName, personLabel: label, form: form))
                forms[key] = list
            }
            for t in verbs.tenses {
                if t.id == "presente_continuo" || t.id == "futuro_proximo"
                    || t.id == "perfeito_composto" || t.id == "mais_que_perfeito_composto" {
                    continue
                }
                guard let list = v.forms[t.id] else { continue }
                for (i, f) in list.enumerated() where !f.isEmpty {
                    let label = i < t.labels.count ? t.labels[i] : ""
                    add(f, tenseName: t.name, label: label)
                }
            }
            add(v.gerund, tenseName: "Gerúndio", label: "")
            add(v.participle, tenseName: "Particípio", label: "")
        }

        self.words = ordered
        self.byID = byIDMap
        self.languages = langs
        self.topics = topicList
        self.wordsByTopic = topicMap
        self.foldedPT = fPT
        self.foldedTr = fTr
        self.formIndex = forms
        self.translationIndex = trIndex
    }

    func word(_ id: String) -> Word? {
        return byID[id]
    }

    func words(inTopic id: String) -> [Word] {
        return wordsByTopic[id] ?? []
    }

    func topicName(_ id: String) -> String {
        return topics.first(where: { $0.id == id })?.name ?? id
    }

    // MARK: - Поиск

    private func matchScore(_ text: String, _ q: String) -> Int {
        if text.isEmpty { return 0 }
        if text == q { return 100 }
        if text.hasPrefix(q) { return 80 }
        if text.contains(" " + q) { return 65 }
        if q.count >= 3 && text.contains(q) { return 40 }
        return 0
    }

    /// Поиск по португальскому слову, любому переводу и по формам глаголов.
    func search(_ query: String, limit: Int = 80) -> [SearchResult] {
        let q = TextUtil.fold(query)
        if q.isEmpty { return [] }

        var scores: [Int: Int] = [:]     // индекс слова → оценка
        var hints: [Int: String] = [:]

        for i in 0..<words.count {
            var best = matchScore(foldedPT[i], q)
            if best < 100 {
                for t in foldedTr[i] {
                    let s = matchScore(t, q) - 10
                    if s > best { best = s }
                    if best >= 90 { break }
                }
            }
            if best > 0 { scores[i] = best }
        }

        if let hits = formIndex[q] {
            for h in hits {
                if let i = words.firstIndex(where: { $0.id == h.verbWordID }) {
                    let label = h.personLabel.isEmpty ? "" : ", " + h.personLabel
                    hints[i] = "форма «\(h.form)» — \(h.tenseName)\(label)"
                    let current = scores[i] ?? 0
                    if current < 95 { scores[i] = 95 }
                }
            }
        }

        var results: [SearchResult] = []
        results.reserveCapacity(scores.count)
        for (i, s) in scores {
            results.append(SearchResult(word: words[i], score: s, hint: hints[i] ?? ""))
        }
        results.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.word.pt.count != b.word.pt.count { return a.word.pt.count < b.word.pt.count }
            return a.word.pt < b.word.pt
        }
        if results.count > limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    // MARK: - Случайные слова (для вариантов ответа)

    func randomWords(count: Int, excluding: Set<String>, pos: String?, lang: String?) -> [Word] {
        var result: [Word] = []
        var used = excluding
        let n = words.count
        if n == 0 || count <= 0 { return [] }
        var attempts = 0
        while result.count < count && attempts < 600 {
            attempts += 1
            let w = words[Int.random(in: 0..<n)]
            if used.contains(w.id) { continue }
            if let p = pos, w.pos != p, attempts < 300 { continue }
            if let l = lang, !w.hasTranslation(lang: l) { continue }
            used.insert(w.id)
            result.append(w)
        }
        return result
    }

    /// id слов, у которых совпадает хотя бы один перевод с переводами данного слова.
    func synonymIDs(of word: Word, lang: String) -> Set<String> {
        var result: Set<String> = [word.id]
        guard let table = translationIndex[lang] else { return result }
        for t in word.tr(lang) {
            let key = TextUtil.normalizeAnswer(t, lang: lang, keepAccents: true, keepParentheses: true)
            if let ids = table[key] {
                result.formUnion(ids)
            }
        }
        return result
    }
}
