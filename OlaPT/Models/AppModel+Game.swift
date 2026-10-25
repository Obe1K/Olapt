import Foundation

// MARK: - Империя слов: связь игры с учёбой

extension AppModel {

    // MARK: День игры

    /// Прожить ночи до сегодняшнего дня (смена дня считается при каждом открытии).
    func gameTick(now: Date = Date()) {
        let target = user.game.dayNumber(for: now)
        if target > user.game.day {
            user.game.advance(to: target)
        }
    }

    // MARK: Авра за упражнения

    /// Начало упражнения. mode — режим для защиты от «фарма» («words.daily», «verbs», «phrases»…);
    /// nil — бой, вылазка или оборона: каждый из них — отдельное упражнение.
    func beginExercise(_ mode: String?) {
        endExercise()
        gameTick()
        let share = user.game.beginExercise(mode: mode)
        gameExercise = GameExercise(mode: mode, share: share)
    }

    /// Ответ в упражнении: Авра начисляется сразу, с долей за повтор режима.
    func gameAnswer(correct: Bool, typed: Bool, level: String?, isNew: Bool = false) {
        if gameExercise == nil {
            beginExercise("misc")
        }
        guard var ex = gameExercise else { return }
        ex.answers += 1
        if isNew { ex.newWords = true }
        if correct {
            var v = GameExercise.value(typed: typed, level: level)
            if isNew && user.game.has(.word, tier: 0) { v *= 1.1 }   // указ «Глашатаи»
            ex.base += v
            user.game.earn(v * ex.share)
        } else {
            ex.errors += 1
            user.game.earn(0)
        }
        gameExercise = ex
    }

    /// Конец упражнения: без единой ошибки — ещё +25%; пройден план «Сегодня» — +20.
    func endExercise() {
        guard let ex = gameExercise else { return }
        gameExercise = nil
        if ex.errors == 0 && ex.base > 0 {
            user.game.earn(ex.base * Act1.perfectBonus * ex.share)
        }
        checkPlanDone()
    }

    /// План «Сегодня» (слова) пройден: +20 Авры и обелиски на ночь заряжаются.
    func checkPlanDone() {
        guard !user.game.planDone else { return }
        let plan = dailyPlan()
        if plan.isEmpty && plan.reviewedToday > 0 {
            user.game.completePlan()
        }
    }

    // MARK: Указы

    /// Сколько глаголов «в памяти» в этом времени (пара «глагол + время» держится неделю и дольше).
    func verbsInMemory(tense: String, among verbs: Set<String>? = nil) -> Int {
        var n = 0
        for (key, s) in user.verbSRS where s.stability >= AppModel.memoryStability {
            let parts = key.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, parts[1] == tense else { continue }
            if let only = verbs, !only.contains(String(parts[0])) { continue }
            n += 1
        }
        return n
    }

    static let irregularPresente: Set<String> = ["ser", "estar", "ter", "ir", "fazer", "poder", "querer", "dizer"]

    /// Открыта ли ступень указов грамматикой: (сколько есть, сколько нужно).
    func decreeProgress(tier: Int) -> (have: Int, need: Int) {
        switch tier {
        case 0: return (min(10, verbsInMemory(tense: "presente")), 10)
        case 1: return (min(6, verbsInMemory(tense: "presente", among: AppModel.irregularPresente)), 6)
        default: return (min(10, verbsInMemory(tense: "perfeito")), 10)
        }
    }

    // MARK: Вопросы для боёв

    /// Слова для боя: «слова, которые вы уже учите» — недавние и самые слабые из начатых.
    func battleWords(limit: Int) -> [Word] {
        return bossWords(limit: limit)
    }

    /// Вопросы боя: слова, которые вы уже учите (выбор и письмо — как в плане «Сегодня»).
    func battleQuestions(count: Int) -> [WordQuestion] {
        let words = battleWords(limit: count)
        let builder = ExerciseBuilder(index: index, settings: settings)
        return builder.makeDailyQuestions(dueWords: words, newWords: [], states: user.srs, pool: words)
    }

    /// Хватает ли начатых слов, чтобы воевать.
    var canFight: Bool {
        return user.srs.count >= 4
    }
}
