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

    /// Уровни CEFR, которые встречаются в словарях, по порядку: A1, A2, B1…
    let levels: [String]

    private let wordsByTopic: [String: [Word]]
    private let wordsByLevel: [String: [Word]]
    private let foldedPT: [String]
    private let foldedTr: [[String]]
    private let formIndex: [String: [VerbFormHit]]
    /// Для распознавания текста: точное написание (нижний регистр, с диакритикой) → индексы слов
    private let exactPT: [String: [Int]]
    /// То же без диакритики («fold»)
    private let foldedPTMap: [String: [Int]]
    /// Формы множественного числа и женского рода → индексы слов
    private let inflectedExact: [String: [Int]]
    private let inflectedFolded: [String: [Int]]
    /// Второе написание (dupla grafia): «carácter» → «caráter», «contacto» → «contato».
    /// Ключ — слово или его форма без «немой» c/p перед t/ç; только для слов, где это написание отличается.
    private let altSpelling: [String: [Int]]
    /// То же для поиска: второе написание без диакритики (или пустая строка)
    private let altFoldedPT: [String]
    private let indexByID: [String: Int]
    /// Самое длинное выражение в словах (для поиска выражений в тексте)
    let maxPhraseWords: Int

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
                        translations: [:], isCustom: false, level: e.lv ?? "")
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
                if ordered[i].level.isEmpty, let lv = e.lv { ordered[i].level = lv }
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
        var levelMap: [String: [Word]] = [:]
        var fPT: [String] = []
        var fTr: [[String]] = []
        var trIndex: [String: [String: Set<String>]] = [:]
        var exact: [String: [Int]] = [:]
        var foldedMap: [String: [Int]] = [:]
        var inflExact: [String: [Int]] = [:]
        var inflFolded: [String: [Int]] = [:]
        var alt: [String: [Int]] = [:]
        var altFolded: [String] = []
        var idToIndex: [String: Int] = [:]
        var longestPhrase = 1

        func put(_ map: inout [String: [Int]], _ key: String, _ i: Int) {
            if key.isEmpty { return }
            var list = map[key] ?? []
            if !list.contains(i) {
                list.append(i)
                map[key] = list
            }
        }

        for (i, w) in ordered.enumerated() {
            byIDMap[w.id] = w
            idToIndex[w.id] = i
            if !w.topic.isEmpty {
                topicMap[w.topic, default: []].append(w)
            }
            if !w.level.isEmpty {
                levelMap[w.level, default: []].append(w)
            }
            let foldedSelf = TextUtil.fold(w.pt)
            fPT.append(foldedSelf)
            put(&exact, w.pt.lowercased(), i)
            put(&foldedMap, foldedSelf, i)
            let wordsInPhrase = foldedSelf.split(separator: " ").count
            if wordsInPhrase > longestPhrase { longestPhrase = wordsInPhrase }
            for form in Inflection.forms(of: w) {
                put(&inflExact, form.lowercased(), i)
                put(&inflFolded, TextUtil.fold(form), i)
            }
            // Двойное написание: слово с c/p перед t/ç находится и без этой буквы.
            let lowerSelf = w.pt.lowercased()
            let modernSelf = TextUtil.modernSpelling(lowerSelf)
            if modernSelf != lowerSelf {
                put(&alt, modernSelf, i)
                altFolded.append(TextUtil.fold(modernSelf))
            } else {
                altFolded.append("")
            }
            for form in Inflection.forms(of: w) {
                let lf = form.lowercased()
                let m = TextUtil.modernSpelling(lf)
                if m != lf { put(&alt, m, i) }
            }
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

        // Индекс форм глаголов: «falou» → falar. Сначала обычные глаголы, потом возвратные
        // (у них берём саму форму без местоимения: «sento-me» → «sento», «me sente» → «sente»),
        // чтобы при совпадении первой находилась невозвратная форма.
        var forms: [String: [VerbFormHit]] = [:]
        let verbOrder = verbs.verbs.filter { !$0.reflexive } + verbs.verbs.filter { $0.reflexive }
        for v in verbOrder {
            func add(_ rawForm: String, tenseName: String, label: String) {
                var form = rawForm
                if v.reflexive {
                    if form.contains(" ") {
                        // проклиза: «me sente» → «sente»
                        form = String(form.split(separator: " ").last ?? "")
                    }
                    if let dash = form.firstIndex(of: "-") {
                        // энклиза и мезоклиза: «sento-me» → «sento», «sentar-se-á» → «sentar»
                        form = String(form[..<dash])
                    }
                }
                let key = TextUtil.fold(form)
                if key.isEmpty || key.contains(" ") { return }
                var list = forms[key] ?? []
                // Одна и та же форма глагола — один раз; разные формы с одинаковым написанием без
                // ударений (falamos / falámos) храним обе, чтобы различать их по диакритике.
                if list.contains(where: { $0.verbWordID == v.wordID && $0.form == form }) { return }
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
        self.wordsByLevel = levelMap
        self.levels = levelMap.keys.sorted()
        self.exactPT = exact
        self.foldedPTMap = foldedMap
        self.inflectedExact = inflExact
        self.inflectedFolded = inflFolded
        self.altSpelling = alt
        self.altFoldedPT = altFolded
        self.indexByID = idToIndex
        self.maxPhraseWords = min(longestPhrase, 6)
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

    func words(inLevel level: String) -> [Word] {
        return wordsByLevel[level] ?? []
    }

    /// Слова уровня, сгруппированные по темам (в порядке тем словаря).
    func topics(inLevel level: String) -> [(topic: TopicInfo, words: [Word])] {
        let list = words(inLevel: level)
        var byTopic: [String: [Word]] = [:]
        for w in list { byTopic[w.topic, default: []].append(w) }
        var result: [(topic: TopicInfo, words: [Word])] = []
        for t in topics {
            if let ws = byTopic[t.id], !ws.isEmpty { result.append((t, ws)) }
        }
        return result
    }

    // MARK: - Слова в тексте (распознавание с фото)

    /// Ищет слово из текста: точное написание, формы глаголов, множественное число и женский род,
    /// затем то же без учёта диакритики. Возвращает слово и пояснение («форма глагола falar»).
    func lookupToken(_ raw: String) -> (word: Word, hint: String)? {
        let t = raw.lowercased()
        let f = TextUtil.fold(t)
        if f.isEmpty { return nil }

        if let i = exactPT[t]?.first { return (words[i], "") }
        // Множественное число и женский род раньше форм глаголов: «casas» — это casa, а не «tu casas».
        if let i = inflectedExact[t]?.first { return (words[i], L("форма слова «%@»", words[i].pt)) }
        if let hit = formIndex[f]?.first(where: { $0.form.lowercased() == t }),
           let w = byID[hit.verbWordID] {
            return (w, L("форма глагола «%@»", w.pt))
        }

        // Без учёта диакритики сравниваем только слова, в которых её нет совсем (её потеряли
        // при наборе или распознавании: «voce», «telemovel»). Слово с «ç», «ã», «é» и т. п.
        // так не сравниваем, иначе «tranças» (косы) превращается в «trancas» (от trancar).
        let hasMarks = t.folding(options: [.diacriticInsensitive], locale: nil) != t
        if !hasMarks {
            if let i = foldedPTMap[f]?.first { return (words[i], "") }
            if let hit = formIndex[f]?.first, let w = byID[hit.verbWordID] {
                return (w, L("форма глагола «%@»", w.pt))
            }
            if let i = inflectedFolded[f]?.first { return (words[i], L("форма слова «%@»", words[i].pt)) }
        }

        // Другие написания форм: «oiço» = «ouço» (ouvir).
        if let inf = Inflection.verbAliases[t], let i = exactPT[inf]?.first {
            return (words[i], L("форма глагола «%@»", words[i].pt))
        }

        // Превосходная степень: «lindíssimo» → lindo, «tardíssimo» → tarde, «facílimo» → fácil.
        for base in Inflection.superlativeBases(t) {
            if let i = exactPT[base]?.first, words[i].pos == "adj" || words[i].pos == "adv" {
                return (words[i], L("превосходная степень от «%@»", words[i].pt))
            }
        }

        // Второе написание: «caráter» → carácter, «contato» → contacto.
        if let i = altSpelling[t]?.first {
            let w = words[i]
            return (w, t == TextUtil.modernSpelling(w.pt.lowercased()) ? "" : L("форма слова «%@»", w.pt))
        }

        // Старая орфография: «acção», «óptimo», «director».
        let modern = TextUtil.modernSpelling(t)
        if modern != t, let found = lookupToken(modern) {
            return found
        }

        // Глагол с местоимением через дефис: «chama-se», «levantei-me», «comprá-lo».
        let parts = t.split(separator: "-").map(String.init)
        if parts.count >= 2, let first = parts.first, !first.isEmpty, Inflection.clitics.contains(parts[1]) {
            var candidates: [String] = []
            if ["lo", "la", "los", "las"].contains(parts[1]) {
                candidates.append(contentsOf: Inflection.infinitivesBeforeLo(first))
            }
            candidates.append(first)
            for c in candidates {
                if let found = lookupToken(c) {
                    let w = found.word
                    let isVerb = w.isVerb
                    return (w, isVerb ? L("форма глагола «%@»", w.pt) : found.hint)
                }
            }
        }
        return nil
    }

    /// Ищет выражение из нескольких слов («bom dia», «pequeno-almoço») по тексту без диакритики.
    func lookupPhrase(_ tokens: [String]) -> Word? {
        if tokens.count < 2 { return nil }
        let key = TextUtil.fold(tokens.joined(separator: " "))
        guard let list = foldedPTMap[key] else { return nil }
        for i in list where words[i].pt.contains(" ") || words[i].pt.contains("-") {
            return words[i]
        }
        return nil
    }

    /// Словарная форма слова, если она отличается: «estou» → «estar», «cansada» → «cansado».
    func lemma(_ token: String) -> String? {
        guard let found = lookupToken(token) else { return nil }
        let base = found.word.pt.lowercased()
        if base.contains(" ") || TextUtil.fold(base) == TextUtil.fold(token) { return nil }
        return base
    }

    /// Выражение с учётом форм слов: «estou com fome» → «estar com fome»,
    /// «está cansada» → «estar cansado», «temos frio» → «ter frio».
    /// - lemmas: словарные формы токенов (можно передать заранее посчитанные), nil — нет другой формы
    func lookupPhraseForms(_ tokens: [String], lemmas: [String?]? = nil) -> Word? {
        if tokens.count < 2 { return nil }
        if let w = lookupPhrase(tokens) { return w }
        let lem = lemmas ?? tokens.map { lemma($0) }
        var options: [[String]] = []
        var combos = 1
        for (i, t) in tokens.enumerated() {
            var opts = [t]
            if i < lem.count, let l = lem[i], l != t.lowercased() { opts.append(l) }
            options.append(opts)
            combos *= opts.count
        }
        if combos == 1 || combos > 64 { return nil }
        var choice = Array(repeating: 0, count: tokens.count)
        while true {
            // следующий вариант (первый — исходные слова — уже проверен выше)
            var k = tokens.count - 1
            while k >= 0 {
                choice[k] += 1
                if choice[k] < options[k].count { break }
                choice[k] = 0
                k -= 1
            }
            if k < 0 { return nil }
            let candidate = (0..<tokens.count).map { options[$0][choice[$0]] }
            if let w = lookupPhrase(candidate) { return w }
        }
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
        var found = searchExact(query, limit: limit)
        if found.isEmpty {
            // «acção» → «ação» и т. п.: старое написание
            let modern = TextUtil.modernSpelling(query.lowercased())
            if modern != query.lowercased() {
                found = searchExact(modern, limit: limit)
            }
        }
        // Выражение в любой форме: «estou com fome» находит «estar com fome»
        let parts = TextUtil.removePunctuation(query.lowercased())
            .split(whereSeparator: { $0 == " " }).map(String.init)
        if parts.count >= 2, let w = lookupPhraseForms(parts), !found.contains(where: { $0.word.id == w.id }) {
            found.insert(SearchResult(word: w, score: 100, hint: L("выражение «%@»", w.pt)), at: 0)
        }
        return found
    }

    private func searchExact(_ query: String, limit: Int) -> [SearchResult] {
        let q = TextUtil.fold(query)
        if q.isEmpty { return [] }

        var scores: [Int: Int] = [:]     // индекс слова → оценка
        var hints: [Int: String] = [:]

        for i in 0..<words.count {
            var best = matchScore(foldedPT[i], q)
            if best < 100 && !altFoldedPT[i].isEmpty {
                // второе написание: «caráter» находит «carácter»
                let s = matchScore(altFoldedPT[i], q) - 2
                if s > best { best = s }
            }
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
            let typed = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for h in hits {
                if let i = indexByID[h.verbWordID] {
                    let label = h.personLabel.isEmpty ? "" : ", " + h.personLabel
                    // Если введено с ударением («falámos»), показываем именно эту форму.
                    if hints[i] == nil || h.form.lowercased() == typed {
                        hints[i] = L("форма «%@» — %@", h.form, h.tenseName) + label
                    }
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
