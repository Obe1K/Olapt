import Foundation

// MARK: - Уровни

/// Четыре уровня упражнений.
enum ExerciseLevel: Int, CaseIterable, Identifiable {
    case chooseTranslation = 1   // слово на португальском → выбрать перевод из 4
    case chooseWord = 2          // перевод → выбрать португальское слово из 4
    case typeTranslation = 3     // слово на португальском → написать перевод
    case typeWord = 4            // перевод → написать португальское слово

    var id: Int { return rawValue }

    var isChoice: Bool {
        return self == .chooseTranslation || self == .chooseWord
    }

    var promptIsPortuguese: Bool {
        return self == .chooseTranslation || self == .typeTranslation
    }

    var title: String {
        switch self {
        case .chooseTranslation: return "Уровень 1 · Выбери перевод"
        case .chooseWord: return "Уровень 2 · Выбери слово"
        case .typeTranslation: return "Уровень 3 · Напиши перевод"
        case .typeWord: return "Уровень 4 · Напиши слово"
        }
    }

    var shortTitle: String {
        switch self {
        case .chooseTranslation: return "Выбери перевод"
        case .chooseWord: return "Выбери слово"
        case .typeTranslation: return "Напиши перевод"
        case .typeWord: return "Напиши слово"
        }
    }

    var subtitle: String {
        switch self {
        case .chooseTranslation: return "Слово по-португальски, перевод — из 4 вариантов"
        case .chooseWord: return "Перевод дан, слово по-португальски — из 4 вариантов"
        case .typeTranslation: return "Слово по-португальски, перевод пишете сами"
        case .typeWord: return "Перевод дан, слово по-португальски пишете сами"
        }
    }

    var symbol: String {
        switch self {
        case .chooseTranslation: return "list.bullet.rectangle"
        case .chooseWord: return "arrow.left.arrow.right"
        case .typeTranslation: return "keyboard"
        case .typeWord: return "square.and.pencil"
        }
    }
}

// MARK: - Вопрос

struct WordQuestion: Identifiable {
    let id = UUID()
    let word: Word
    let level: ExerciseLevel
    /// Язык перевода в этом вопросе
    let lang: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    /// Принимаемые варианты ответа (для ввода с клавиатуры)
    let accepted: [String]
    /// "pt" или код языка — для нормализации
    let acceptedLang: String
    /// Правильный ответ для показа
    let answerText: String
    var isRetry: Bool = false
}

enum AnswerVerdict {
    case exact
    case accentsOnly   // всё верно, кроме диакритики
    case wrong
}

// MARK: - Генератор вопросов

struct ExerciseBuilder {
    let index: DictionaryIndex
    let settings: AppSettings

    /// На каком языке задавать перевод для этого слова.
    func pickLanguage(for word: Word) -> String? {
        var available: [String] = []
        for lang in index.languages where word.hasTranslation(lang: lang) {
            available.append(lang)
        }
        if available.isEmpty { return nil }
        if settings.exerciseLanguage == "mixed" {
            return available.randomElement()
        }
        if available.contains(settings.exerciseLanguage) {
            return settings.exerciseLanguage
        }
        return available.first
    }

    /// Список вопросов для набора слов. count == 0 — по одному вопросу на каждое слово.
    func makeQuestions(words: [Word], level: ExerciseLevel, count: Int) -> [WordQuestion] {
        var selected = words.shuffled()
        if count > 0 && selected.count > count {
            selected = Array(selected.prefix(count))
        }
        var result: [WordQuestion] = []
        for w in selected {
            if let q = makeQuestion(word: w, level: level, pool: words) {
                result.append(q)
            }
        }
        return result
    }

    /// Кандидаты на неверные варианты: сначала слова из той же коллекции, затем случайные из словаря.
    private func distractorCandidates(for word: Word, pool: [Word], lang: String) -> [Word] {
        var candidates: [Word] = []
        var seen: Set<String> = [word.id]
        let others = pool.filter { $0.id != word.id && $0.hasTranslation(lang: lang) }.shuffled()
        let samePOS = others.filter { $0.pos == word.pos }
        let differentPOS = others.filter { $0.pos != word.pos }
        for w in samePOS + differentPOS {
            if seen.insert(w.id).inserted { candidates.append(w) }
        }
        let extra = index.randomWords(count: 14, excluding: seen, pos: word.pos, lang: lang)
        candidates.append(contentsOf: extra)
        return candidates
    }

    func makeQuestion(word: Word, level: ExerciseLevel, pool: [Word]) -> WordQuestion? {
        guard let lang = pickLanguage(for: word) else { return nil }
        let translations = word.tr(lang)
        if translations.isEmpty { return nil }

        switch level {
        case .chooseTranslation:
            let correct = word.translationText(lang: lang, limit: 2)
            var forbidden = Set<String>()
            for t in translations {
                forbidden.insert(TextUtil.normalizeAnswer(t, lang: lang, keepAccents: true, keepParentheses: true))
            }
            var options: [String] = [correct]
            var usedKeys: Set<String> = [TextUtil.fold(correct)]
            for c in distractorCandidates(for: word, pool: pool, lang: lang) {
                var overlaps = false
                for t in c.tr(lang) {
                    if forbidden.contains(TextUtil.normalizeAnswer(t, lang: lang, keepAccents: true, keepParentheses: true)) {
                        overlaps = true
                        break
                    }
                }
                if overlaps { continue }
                let text = c.translationText(lang: lang, limit: 2)
                let key = TextUtil.fold(text)
                if key.isEmpty || usedKeys.contains(key) { continue }
                usedKeys.insert(key)
                options.append(text)
                if options.count == 4 { break }
            }
            if options.count < 2 { return nil }
            options.shuffle()
            let correctIndex = options.firstIndex(of: correct) ?? 0
            return WordQuestion(word: word, level: level, lang: lang,
                                prompt: word.titleWithArticle, options: options,
                                correctIndex: correctIndex, accepted: [], acceptedLang: lang,
                                answerText: correct)

        case .chooseWord:
            let prompt = word.translationText(lang: lang, limit: 3)
            let synonyms = index.synonymIDs(of: word, lang: lang)
            let correct = word.titleWithArticle
            var options: [String] = [correct]
            var usedKeys: Set<String> = [TextUtil.fold(correct)]
            for c in distractorCandidates(for: word, pool: pool, lang: lang) {
                if synonyms.contains(c.id) { continue }
                let text = c.titleWithArticle
                let key = TextUtil.fold(text)
                if usedKeys.contains(key) { continue }
                usedKeys.insert(key)
                options.append(text)
                if options.count == 4 { break }
            }
            if options.count < 2 { return nil }
            options.shuffle()
            let correctIndex = options.firstIndex(of: correct) ?? 0
            return WordQuestion(word: word, level: level, lang: lang,
                                prompt: prompt, options: options,
                                correctIndex: correctIndex, accepted: [], acceptedLang: "pt",
                                answerText: correct)

        case .typeTranslation:
            return WordQuestion(word: word, level: level, lang: lang,
                                prompt: word.titleWithArticle, options: [],
                                correctIndex: -1, accepted: translations, acceptedLang: lang,
                                answerText: translations.joined(separator: ", "))

        case .typeWord:
            let prompt = word.translationText(lang: lang, limit: 3)
            var accepted: [String] = word.ptVariants
            for id in index.synonymIDs(of: word, lang: lang) where id != word.id {
                if let other = index.word(id) {
                    accepted.append(contentsOf: other.ptVariants)
                }
            }
            return WordQuestion(word: word, level: level, lang: lang,
                                prompt: prompt, options: [],
                                correctIndex: -1, accepted: accepted, acceptedLang: "pt",
                                answerText: word.answerDisplay)
        }
    }

    // MARK: - Проверка ответа

    /// Проверка текстового ответа.
    static func verdict(input: String, question: WordQuestion) -> AnswerVerdict {
        let lang = question.acceptedLang
        let strictInput = TextUtil.normalizeAnswer(input, lang: lang, keepAccents: true)
        if strictInput.isEmpty { return .wrong }
        let lenientInput = TextUtil.normalizeAnswer(input, lang: lang, keepAccents: false)

        var strictSet = Set<String>()
        var lenientSet = Set<String>()
        for a in question.accepted {
            strictSet.insert(TextUtil.normalizeAnswer(a, lang: lang, keepAccents: true))
            lenientSet.insert(TextUtil.normalizeAnswer(a, lang: lang, keepAccents: false))
        }
        if strictSet.contains(strictInput) { return .exact }
        if lenientSet.contains(lenientInput) { return .accentsOnly }
        return .wrong
    }
}
