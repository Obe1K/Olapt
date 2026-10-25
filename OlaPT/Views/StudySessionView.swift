import SwiftUI

// MARK: - Состояние тренировки

final class WordStudySession: ObservableObject {
    private let generator: () -> [WordQuestion]

    @Published var queue: [WordQuestion] = []
    @Published var position: Int = 0
    @Published var answered: Bool = false
    @Published var selectedIndex: Int? = nil
    @Published var lastCorrect: Bool = false
    @Published var lastVerdict: AnswerVerdict = .wrong
    @Published var correctCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var mistakes: [Word] = []
    /// Ответы без нужного акцента: засчитаны, но в итогах напоминаем, как пишется
    @Published var accentSlips: [AccentSlip] = []
    /// Что ввёл пользователь и с каким ответом это совпало (для подсветки акцентов)
    @Published var lastTyped: String = ""
    @Published var lastMatch: String = ""
    @Published var finished: Bool = false
    /// Все верные и неверные ответы, включая повторы (для боя с боссом)
    @Published var hits: Int = 0
    @Published var misses: Int = 0
    /// Закончить раньше (босс повержен или маг выбился из сил)
    var stopWhen: (() -> Bool)?

    init(generator: @escaping () -> [WordQuestion]) {
        self.generator = generator
        self.queue = generator()
        self.finished = queue.isEmpty
    }

    var current: WordQuestion? {
        if position >= 0 && position < queue.count { return queue[position] }
        return nil
    }

    var percent: Int {
        if totalCount == 0 { return 0 }
        return Int((Double(correctCount) / Double(totalCount) * 100.0).rounded())
    }

    func restart() {
        queue = generator()
        position = 0
        answered = false
        selectedIndex = nil
        lastCorrect = false
        correctCount = 0
        totalCount = 0
        mistakes = []
        accentSlips = []
        hits = 0
        misses = 0
        finished = queue.isEmpty
    }

    func answerChoice(_ choice: Int, model: AppModel) {
        guard !answered, let q = current else { return }
        selectedIndex = choice
        let ok = (choice == q.correctIndex)
        finish(ok: ok, verdict: ok ? .exact : .wrong, model: model)
    }

    func answerText(_ text: String, model: AppModel) {
        guard !answered, let q = current else { return }
        var verdict = ExerciseBuilder.verdict(input: text, question: q)
        lastTyped = text
        lastMatch = ExerciseBuilder.accentMatch(input: text, question: q) ?? q.answerText
        if verdict == .accentsOnly && model.settings.strictAccents {
            verdict = .wrong
        }
        if verdict == .accentsOnly && !q.isRetry && !accentSlips.contains(where: { $0.key == q.word.id }) {
            accentSlips.append(AccentSlip(key: q.word.id, typed: text, answer: lastMatch))
        }
        finish(ok: verdict != .wrong, verdict: verdict, model: model)
    }

    func giveUp(model: AppModel) {
        guard !answered, current != nil else { return }
        finish(ok: false, verdict: .wrong, model: model)
    }

    private func finish(ok: Bool, verdict: AnswerVerdict, model: AppModel) {
        guard let q = current else { return }
        answered = true
        lastCorrect = ok
        lastVerdict = verdict
        if ok { hits += 1 } else { misses += 1 }
        SoundFX.shared.play(ok ? .correct : .wrong)
        if !q.isRetry {
            totalCount += 1
            if ok {
                correctCount += 1
            } else {
                mistakes.append(q.word)
            }
            model.record(wordID: q.word.id, correct: ok,
                         recognition: q.kind.isChoice, accentsOnly: verdict == .accentsOnly)
            if !ok {
                var retry = q
                retry.isRetry = true
                queue.append(retry)
            }
        }
    }

    /// Переход к следующему вопросу. Возвращает true, если тренировка закончилась.
    @discardableResult
    func next() -> Bool {
        position += 1
        answered = false
        selectedIndex = nil
        if position >= queue.count || stopWhen?() == true {
            finished = true
        }
        return finished
    }
}

// MARK: - Экран тренировки

struct StudySessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: WordStudySession
    /// Уровень коллекции (для лучшего результата) или nil для тренировки «Сегодня» и «Трудных слов»
    let level: ExerciseLevel?
    let title: String
    let collectionID: UUID?
    /// Тренировка «Сегодня»: в конце показываем план на ближайшие дни
    let isDaily: Bool
    /// Бой с боссом недели
    let boss: BossConfig?
    /// Бой Империи слов (штурм, бой с боссом поселения, вылазка, оборона)
    let battle: BattleSpec?
    @State private var exerciseBegun = false
    @State private var battleReported = false

    @State private var typed = ""
    @State private var fieldFocused = false
    /// Автопереход к следующему слову в уровнях с выбором ответа
    @State private var advanceWork: DispatchWorkItem?
    /// Короткая пауза после смены слова: случайное второе касание не должно выбрать вариант в новом вопросе.
    @State private var inputLocked = false

    init(level: ExerciseLevel?, title: String? = nil, collectionID: UUID?, isDaily: Bool = false,
         boss: BossConfig? = nil, battle: BattleSpec? = nil, generator: @escaping () -> [WordQuestion]) {
        self.level = level
        self.title = title ?? level?.shortTitle ?? L("Тренировка")
        self.collectionID = collectionID
        self.isDaily = isDaily
        self.boss = boss
        self.battle = battle
        let s = WordStudySession(generator: generator)
        if let b = battle?.arena ?? boss {
            s.stopWhen = { [unowned s] in s.hits >= b.hp || s.misses >= b.hearts }
        }
        _session = StateObject(wrappedValue: s)
    }

    /// Противник на арене: босс недели или босс поселения
    private var arena: BossConfig? {
        return battle?.arena ?? boss
    }

    private var bossWon: Bool {
        guard let b = arena else { return false }
        return session.hits >= b.hp
    }

    /// Режим для Авры (защита от «фарма»): тот же режим за день — 100%, 50%, 25%, потом ничего.
    private var exerciseMode: String? {
        if battle != nil { return nil }
        if boss != nil { return "boss" }
        if isDaily { return "words.daily" }
        if let lv = level { return "words.level\(lv.rawValue)" }
        return "words.other"
    }

    private func battleScore() -> BattleScore {
        return BattleScore(correct: session.correctCount, total: session.totalCount,
                           hits: session.hits, misses: session.misses, won: bossWon)
    }

    private var currentIsChoice: Bool {
        return session.current?.kind.isChoice ?? false
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.finished {
                    summaryView
                } else if let q = session.current {
                    questionView(q)
                } else {
                    Text(L("Нет вопросов"))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Закрыть")) { dismiss() }
                }
            }
        }
        .onChange(of: session.position) { _ in
            typed = ""
            if !currentIsChoice && !session.finished {
                fieldFocused = true
            } else {
                fieldFocused = false
            }
            if currentIsChoice {
                inputLocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    inputLocked = false
                }
            }
        }
        .onChange(of: session.answered) { answered in
            if answered && currentIsChoice {
                scheduleAutoAdvance()
            }
        }
        .onDisappear {
            advanceWork?.cancel()
            model.endExercise()
            reportBattle()
        }
        .onChange(of: session.finished) { done in
            if done {
                saveBestScore()
                model.endExercise()
                if isDaily && model.dailyPlan().isEmpty {
                    model.feedPetFull()
                }
                if bossWon {
                    if battle == nil { model.recordBossVictory() }
                    SoundFX.shared.play(.victory)
                }
                reportBattle()
            }
        }
        .onAppear {
            if !exerciseBegun {
                exerciseBegun = true
                model.beginExercise(exerciseMode)
            }
            if !currentIsChoice && !session.finished {
                fieldFocused = true
            }
        }
    }

    /// Итог боя — один раз: когда бой закончен или его бросили на середине.
    private func reportBattle() {
        guard let b = battle, !battleReported else { return }
        battleReported = true
        b.onFinish(battleScore())
    }

    private func saveBestScore() {
        if let id = collectionID, let level = level, session.totalCount > 0 {
            model.setBestScore(collection: id, level: level, percent: session.percent)
        }
    }

    // MARK: Вопрос

    private func caption(_ q: WordQuestion) -> String {
        switch q.kind {
        case .chooseTranslation: return L("Выберите перевод")
        case .chooseWord: return L("Выберите слово по-португальски")
        case .typeWord: return L("Напишите по-португальски · перевод: %@", Languages.name(q.lang))
        }
    }

    @ViewBuilder
    private func questionView(_ q: WordQuestion) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if let b = arena {
                    BossArenaView(boss: b, hits: session.hits, misses: session.misses,
                                  answered: session.answered, lastCorrect: session.lastCorrect)
                        .padding(.horizontal, -20)
                } else {
                    PixelProgressBar(fraction: Double(session.position + (session.answered ? 1 : 0)) / Double(max(1, session.queue.count)),
                                     fill: Theme.bloodBright)
                        .padding(.top, 8)
                }

                if q.isRetry {
                    Text(L("Повторим слово, в котором была ошибка"))
                        .font(.footnote)
                        .foregroundColor(Theme.ember)
                }

                Text(caption(q))
                    .font(.footnote)
                    .foregroundColor(Theme.textDim)

                HStack(spacing: 10) {
                    Text(q.prompt)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    if q.kind.promptIsPortuguese {
                        SpeakButton(text: q.word.pt)
                    }
                }
                .padding(.vertical, 8)

                if q.kind.isChoice {
                    choiceList(q)
                } else {
                    typingArea(q)
                }

                if session.answered {
                    feedback(q)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if session.answered && !q.kind.isChoice {
                nextButtonBar
            }
        }
    }

    // MARK: Выбор из вариантов

    private func choiceColor(_ i: Int, _ q: WordQuestion) -> Color {
        if !session.answered { return Theme.panel }
        if i == q.correctIndex { return Theme.mossDark }
        if session.selectedIndex == i { return Theme.bloodDark }
        return Theme.panel
    }

    @ViewBuilder
    private func choiceList(_ q: WordQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(q.options.indices, id: \.self) { i in
                Button {
                    if inputLocked { return }
                    session.answerChoice(i, model: model)
                } label: {
                    HStack {
                        Text(q.options[i])
                            .font(.title3)
                            .foregroundColor(Theme.text)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if session.answered && i == q.correctIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.moss)
                        } else if session.answered && session.selectedIndex == i {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.red)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(PixelFrame(fill: choiceColor(i, q)))
                }
                .buttonStyle(.plain)
                .disabled(session.answered)
            }
        }
    }

    // MARK: Ввод с клавиатуры

    @ViewBuilder
    private func typingArea(_ q: WordQuestion) -> some View {
        VStack(spacing: 12) {
            ColoredAnswerField(
                text: $typed,
                isFocused: $fieldFocused,
                placeholder: L("Ваш ответ"),
                isEnabled: !session.answered,
                coloring: { input in
                    ExerciseBuilder.coloring(input: input, question: q)
                },
                onSubmit: { check() }
            )
            .frame(height: 52)
            .padding(.horizontal, 12)
            .background(PixelFrame(fill: Theme.panelDeep))
            if !session.answered {
                Text(L("Зелёные буквы — верно, золотые — не хватает акцента, красные — с места ошибки."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !session.answered {
                HStack(spacing: 12) {
                    Button {
                        session.giveUp(model: model)
                        fieldFocused = false
                    } label: {
                        Text(L("Не знаю"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GothicButtonStyle(.secondary))

                    Button {
                        check()
                    } label: {
                        Text(L("Проверить"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GothicButtonStyle(.primary))
                    .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func check() {
        if session.answered { return }
        if typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        session.answerText(typed, model: model)
        fieldFocused = false
    }

    // MARK: Результат ответа

    @ViewBuilder
    private func feedback(_ q: WordQuestion) -> some View {
        VStack(spacing: 10) {
            if session.lastCorrect && session.lastVerdict == .accentsOnly {
                Label(L("Верно, но с акцентом"), systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(20, relativeTo: .title3))
                    .foregroundColor(Theme.goldBright)
                    .accessibilityIdentifier("accent-feedback")
                AccentHighlight.text(session.lastMatch, typed: session.lastTyped)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.text)
                Text(L("Засчитано. Не забывайте акцент: он меняет произношение, а иногда и смысл."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if session.lastCorrect {
                Label(L("Верно!"), systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.moss)
            } else {
                Label(L("Неверно"), systemImage: "xmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.red)
                if session.lastVerdict == .accentsOnly {
                    // Строгий режим: без акцента — ошибка
                    AccentHighlight.text(session.lastMatch, typed: session.lastTyped)
                        .font(.headline)
                        .foregroundColor(Theme.text)
                    Text(L("Включена строгая проверка ударений (Настройки → Упражнения)."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(L("Правильный ответ: %@", q.answerText))
                        .font(.headline)
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                }
            }
            if !q.kind.promptIsPortuguese {
                HStack(spacing: 8) {
                    Text(q.word.titleWithArticle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SpeakButton(text: q.word.pt)
                }
            }
        }
        .padding(.top, 6)
    }

    /// Кнопка «Далее» внизу экрана (уровень с вводом): туда удобно дотянуться большим пальцем.
    private var nextButtonBar: some View {
        Button {
            session.next()
        } label: {
            Text(session.position + 1 >= session.queue.count ? L("Завершить") : L("Далее"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GothicButtonStyle(.primary))
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.background.opacity(0.95))
    }

    /// Уровни 1–2: результат виден пару секунд, затем следующее слово само.
    private func scheduleAutoAdvance() {
        advanceWork?.cancel()
        let position = session.position
        let delay = session.lastCorrect ? 1.5 : 2.5
        let current = session
        let work = DispatchWorkItem { [weak current] in
            guard let s = current, s.answered, s.position == position, !s.finished else { return }
            s.next()
        }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: Итоги

    /// «Следующее повторение — завтра: 12 слов (≈ 3 мин)».
    private var nextReviewText: String {
        let days = model.forecast(days: 30)
        guard let i = days.firstIndex(where: { $0 > 0 }) else {
            return L("Следующих повторений пока нет. Добавьте новые слова в коллекции — они появятся в плане «Сегодня».")
        }
        let n = days[i]
        let when: String
        switch i {
        case 0: when = L("завтра")
        case 1: when = L("послезавтра")
        default: when = L("через %d %@", i + 1, Plural.days(i + 1))
        }
        return L("Следующее повторение — %@: %d %@ (≈ %d мин).", when, n, Plural.words(n), model.estimatedMinutes(questions: n))
    }

    private var summaryView: some View {
        GothicList {
            if battle != nil {
                Section {
                    VStack(spacing: 10) {
                        if let b = battle?.arena {
                            BossArenaView(boss: b, hits: session.hits, misses: session.misses,
                                          answered: false, lastCorrect: false, defeated: bossWon)
                            Text(bossWon ? L("%@ повержен!", b.title) : L("Бой проигран"))
                                .font(Theme.pixel(24, relativeTo: .title2))
                                .foregroundColor(bossWon ? Theme.goldBright : Theme.red)
                        } else {
                            Text(L("Бой окончен"))
                                .font(Theme.pixel(24, relativeTo: .title2))
                                .foregroundColor(Theme.goldBright)
                        }
                        Button(L("Дальше")) { dismiss() }
                            .buttonStyle(GothicButtonStyle(.primary))
                            .accessibilityIdentifier("battle-continue")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("battle-result")
                }
                .listRowBackground(Color.clear)
            } else if let b = boss {
                Section {
                    VStack(spacing: 10) {
                        BossArenaView(boss: b, hits: session.hits, misses: session.misses,
                                      answered: false, lastCorrect: false, defeated: bossWon)
                        if bossWon {
                            Text(L("%@ повержен!", b.title))
                                .font(Theme.pixel(24, relativeTo: .title2))
                                .foregroundColor(Theme.goldBright)
                            Text(L("Маг получил полный котёл зелья. Следующий босс появится в понедельник."))
                                .font(.subheadline)
                                .foregroundColor(Theme.text)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(L("Маг выбился из сил"))
                                .font(Theme.pixel(22, relativeTo: .title2))
                                .foregroundColor(Theme.red)
                            Text(L("Повторите слова и бросьте вызов снова — босс ждёт до конца недели."))
                                .font(.subheadline)
                                .foregroundColor(Theme.text)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("boss-result")
                }
                .listRowBackground(Color.clear)
            }
            if isDaily {
                Section {
                    let plan = model.dailyPlan()
                    VStack(alignment: .leading, spacing: 8) {
                        if plan.isEmpty {
                            Label(L("На сегодня всё"), systemImage: "checkmark.seal.fill")
                                .font(Theme.pixel(20, relativeTo: .title3))
                                .foregroundColor(Theme.moss)
                            Text(L("Ещё раз сегодня проходить не нужно: повторение раньше срока почти не укрепляет память."))
                                .font(.subheadline)
                        } else {
                            Label(L("Осталось ещё %d %@", plan.total, Plural.words(plan.total)), systemImage: "clock")
                                .font(.headline)
                            Text(L("Продолжите на вкладке «Сегодня»."))
                                .font(.subheadline)
                        }
                        Text(nextReviewText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            Section {
                VStack(spacing: 8) {
                    Text("\(session.percent)%")
                        .font(Theme.pixel(54, relativeTo: .largeTitle))
                        .foregroundColor(session.percent >= 80 ? Theme.moss : Theme.ember)
                    Text(L("Верно с первого раза: %d из %d", session.correctCount, session.totalCount))
                        .foregroundColor(.secondary)
                    if isDaily {
                        EmptyView()
                    } else if session.percent >= 80 {
                        Text(L("Отличный результат! Можно переходить к следующему уровню."))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    } else if session.totalCount > 0 {
                        Text(L("Повторите ещё раз, чтобы слова закрепились."))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !session.accentSlips.isEmpty {
                Section(header: GothicHeader(L("Проверьте акценты")),
                        footer: Text(L("Эти ответы засчитаны, но в них не хватало акцента."))) {
                    ForEach(session.accentSlips) { slip in
                        VStack(alignment: .leading, spacing: 2) {
                            AccentHighlight.text(slip.answer, typed: slip.typed)
                                .font(.headline)
                                .foregroundColor(Theme.text)
                            Text(L("вы написали: %@", slip.typed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if !session.mistakes.isEmpty {
                Section(header: GothicHeader(L("Ошибки"))) {
                    ForEach(session.mistakes) { w in
                        WordRow(word: w, showStatus: false)
                    }
                }
            }

            Section {
                if !isDaily && !bossWon && battle == nil {
                Button {
                    advanceWork?.cancel()
                    session.restart()
                    model.beginExercise(exerciseMode)
                    typed = ""
                    if !currentIsChoice {
                        fieldFocused = true
                    }
                } label: {
                    Label(boss != nil ? L("Сразиться снова") : L("Пройти ещё раз"), systemImage: "arrow.clockwise")
                }
                }
                Button {
                    dismiss()
                } label: {
                    Label(L("Закончить"), systemImage: "checkmark")
                }
            }
        }
    }
}
