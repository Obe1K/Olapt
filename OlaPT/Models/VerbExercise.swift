import Foundation

enum VerbMode: String, CaseIterable, Identifiable {
    case choice
    case typing

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .choice: return "Выбрать из 4"
        case .typing: return "Написать форму"
        }
    }
}

/// Итог проверки введённой формы глагола.
enum VerbVerdict: Equatable {
    case exact
    /// Всё верно, кроме диакритики: засчитываем с напоминанием
    case accentsOnly
    /// Без акцента вышла другая форма того же глагола: «falamos» (Presente) вместо «falámos»
    case otherForm(form: String, tenseName: String, pronoun: String)
    case wrong
}

struct VerbQuestion: Identifiable {
    let id = UUID()
    let verb: Verb
    let tense: TenseInfo
    let person: Int
    let answer: String
    let options: [String]
    let correctIndex: Int
    var isRetry: Bool = false

    var pronoun: String {
        return person < tense.labels.count ? tense.labels[person] : ""
    }

    /// Начало фразы перед пропуском: «que eu», «tu», «quando ele/ela/você».
    var lead: String {
        if tense.prefix.isEmpty { return pronoun }
        return tense.prefix + " " + pronoun
    }
}

struct VerbExerciseBuilder {
    let library: VerbLibrary
    let progress: [String: WordProgress]

    /// Составляет вопросы для набора глаголов и времён.
    /// Сначала чаще попадаются пары «глагол + время», которые выучены хуже.
    func makeQuestions(verbs: [Verb], tenses: [TenseInfo], mode: VerbMode, count: Int) -> [VerbQuestion] {
        if verbs.isEmpty || tenses.isEmpty { return [] }

        // Один глагол и одно время: берём все лица по порядку (перемешанные).
        var triples: [(Verb, TenseInfo, Int)] = []
        for v in verbs {
            for t in tenses {
                for p in library.activePersons(t) {
                    if v.form(t.id, p).isEmpty { continue }
                    triples.append((v, t, p))
                }
            }
        }
        if triples.isEmpty { return [] }

        var keyed: [(Double, (Verb, TenseInfo, Int))] = []
        for item in triples {
            let key = VerbLibrary.progressKey(verb: item.0, tense: item.1)
            let score = Double(progress[key]?.score ?? 0)
            keyed.append((score + Double.random(in: 0..<3), item))
        }
        keyed.sort { $0.0 < $1.0 }

        var limit = count
        if limit <= 0 || limit > keyed.count { limit = keyed.count }
        var chosen: [(Verb, TenseInfo, Int)] = []
        for i in 0..<limit {
            chosen.append(keyed[i].1)
        }
        chosen.shuffle()

        var result: [VerbQuestion] = []
        for item in chosen {
            result.append(makeQuestion(verb: item.0, tense: item.1, person: item.2, mode: mode))
        }
        return result
    }

    func makeQuestion(verb: Verb, tense: TenseInfo, person: Int, mode: VerbMode) -> VerbQuestion {
        let answer = verb.form(tense.id, person)
        var options: [String] = []
        var correctIndex = -1
        if mode == .choice {
            options = distractors(verb: verb, tense: tense, person: person, answer: answer)
            options.append(answer)
            options.shuffle()
            correctIndex = options.firstIndex(of: answer) ?? 0
        }
        return VerbQuestion(verb: verb, tense: tense, person: person, answer: answer,
                            options: options, correctIndex: correctIndex)
    }

    /// Неверные варианты — типичные путаницы: другие лица того же времени
    /// и то же лицо в других временах этого глагола.
    private func distractors(verb: Verb, tense: TenseInfo, person: Int, answer: String) -> [String] {
        let answerKey = TextUtil.normalizeVerbForm(answer)
        var pool: [String] = []
        var seen: Set<String> = [answerKey]

        func take(_ form: String) {
            let key = TextUtil.normalizeVerbForm(form)
            if key.isEmpty || seen.contains(key) { return }
            seen.insert(key)
            pool.append(form)
        }

        var sameTense: [String] = []
        for p in library.activePersons(tense) where p != person {
            sameTense.append(verb.form(tense.id, p))
        }
        sameTense.shuffle()

        var otherTenses: [String] = []
        for t in library.tenses where t.id != tense.id {
            otherTenses.append(verb.form(t.id, person))
        }
        otherTenses.shuffle()

        // Две формы того же времени + одна из другого времени, затем добираем любыми.
        for f in sameTense.prefix(2) { take(f) }
        for f in otherTenses.prefix(2) { take(f) }
        for f in sameTense { take(f) }
        for f in otherTenses { take(f) }

        // Если вариантов не хватило (редко), берём формы другого глагола.
        if pool.count < 3 {
            let others = library.verbs.filter { $0.inf != verb.inf }.shuffled()
            for o in others.prefix(8) {
                take(o.form(tense.id, person))
                if pool.count >= 3 { break }
            }
        }
        return Array(pool.prefix(3))
    }

    /// Местоимения (и «que», «se», «quando»), которые пользователь может написать перед формой.
    static func leads(_ question: VerbQuestion) -> [String] {
        let pronouns = question.pronoun.split(separator: "/").map { String($0) }
        var leads: [String] = []
        for p in pronouns {
            leads.append(p)
            if !question.tense.prefix.isEmpty {
                leads.append(question.tense.prefix + " " + p)
            }
        }
        return leads
    }

    /// Точная проверка введённой формы (с диакритикой).
    static func isCorrect(input: String, question: VerbQuestion) -> Bool {
        let typed = TextUtil.normalizeVerbForm(input)
        if typed.isEmpty { return false }
        let target = TextUtil.normalizeVerbForm(question.answer)
        if typed == target { return true }
        // Допускаем, что пользователь написал и местоимение: «tu falas», «que eu fale».
        for lead in leads(question) {
            if typed == lead + " " + target { return true }
        }
        return false
    }

    /// Проверка с учётом акцентов. Забытый акцент засчитывается, но если без него получилась
    /// другая форма того же глагола (falamos — Presente вместо falámos — Perfeito), это ошибка.
    static func verdict(input: String, question: VerbQuestion, tenses: [TenseInfo]) -> VerbVerdict {
        if isCorrect(input: input, question: question) { return .exact }
        let typed = TextUtil.normalizeVerbForm(input)
        if typed.isEmpty { return .wrong }
        let target = TextUtil.normalizeVerbForm(question.answer)
        let folded = AccentCheck.fold(typed)
        let candidates = [target] + leads(question).map { $0 + " " + target }
        guard candidates.contains(where: { AccentCheck.fold($0) == folded }) else { return .wrong }
        // Сама форма без местоимения
        let core = String(Array(typed).suffix(Array(target).count))
        for t in tenses {
            guard let list = question.verb.forms[t.id] else { continue }
            for (p, f) in list.enumerated() {
                let form = TextUtil.normalizeVerbForm(f)
                if form == core && form != target && !(t.id == question.tense.id && p == question.person) {
                    let label = p < t.labels.count ? t.labels[p] : ""
                    return .otherForm(form: f, tenseName: t.name, pronoun: label)
                }
            }
        }
        return .accentsOnly
    }
}
