import SwiftUI

// MARK: - Состояние тренировки

final class WordStudySession: ObservableObject {
    let level: ExerciseLevel
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
    @Published var finished: Bool = false

    init(level: ExerciseLevel, generator: @escaping () -> [WordQuestion]) {
        self.level = level
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
        if verdict == .accentsOnly && model.settings.strictAccents {
            verdict = .wrong
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
        if !q.isRetry {
            totalCount += 1
            if ok {
                correctCount += 1
            } else {
                mistakes.append(q.word)
            }
            model.record(wordID: q.word.id, correct: ok)
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
        if position >= queue.count {
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
    let level: ExerciseLevel
    let collectionID: UUID?

    @State private var typed = ""
    @State private var fieldFocused = false
    /// Автопереход к следующему слову в уровнях с выбором ответа
    @State private var advanceWork: DispatchWorkItem?
    /// Короткая пауза после смены слова: случайное второе касание не должно выбрать вариант в новом вопросе.
    @State private var inputLocked = false

    init(level: ExerciseLevel, collectionID: UUID?, generator: @escaping () -> [WordQuestion]) {
        self.level = level
        self.collectionID = collectionID
        _session = StateObject(wrappedValue: WordStudySession(level: level, generator: generator))
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.finished {
                    summaryView
                } else if let q = session.current {
                    questionView(q)
                } else {
                    Text("Нет вопросов")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(level.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .onChange(of: session.position) { _ in
            typed = ""
            if !level.isChoice && !session.finished {
                fieldFocused = true
            }
            if level.isChoice {
                inputLocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    inputLocked = false
                }
            }
        }
        .onChange(of: session.answered) { answered in
            if answered && level.isChoice {
                scheduleAutoAdvance()
            }
        }
        .onDisappear {
            advanceWork?.cancel()
        }
        .onChange(of: session.finished) { done in
            if done {
                saveBestScore()
            }
        }
        .onAppear {
            if !level.isChoice && !session.finished {
                fieldFocused = true
            }
        }
    }

    private func saveBestScore() {
        if let id = collectionID, session.totalCount > 0 {
            model.setBestScore(collection: id, level: level, percent: session.percent)
        }
    }

    // MARK: Вопрос

    private func caption(_ q: WordQuestion) -> String {
        switch level {
        case .chooseTranslation: return "Выберите перевод"
        case .chooseWord: return "Выберите слово по-португальски"
        case .typeWord: return "Напишите по-португальски · перевод: \(Languages.name(q.lang))"
        }
    }

    @ViewBuilder
    private func questionView(_ q: WordQuestion) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ProgressView(value: Double(session.position), total: Double(max(1, session.queue.count)))
                    .padding(.top, 8)

                if q.isRetry {
                    Text("Повторим слово, в котором была ошибка")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }

                Text(caption(q))
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Text(q.prompt)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    if level.promptIsPortuguese {
                        SpeakButton(text: q.word.pt)
                    }
                }
                .padding(.vertical, 8)

                if level.isChoice {
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
        .safeAreaInset(edge: .bottom) {
            if session.answered && !level.isChoice {
                nextButtonBar
            }
        }
    }

    // MARK: Выбор из вариантов

    private func choiceColor(_ i: Int, _ q: WordQuestion) -> Color {
        if !session.answered { return Color(.secondarySystemFill) }
        if i == q.correctIndex { return Color.green.opacity(0.28) }
        if session.selectedIndex == i { return Color.red.opacity(0.28) }
        return Color(.secondarySystemFill)
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
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if session.answered && i == q.correctIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if session.answered && session.selectedIndex == i {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(choiceColor(i, q))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                placeholder: "Ваш ответ",
                isEnabled: !session.answered,
                correctPrefix: { input in
                    ExerciseBuilder.matchingPrefixLength(input: input, question: q,
                                                         strictAccents: model.settings.strictAccents)
                },
                onSubmit: { check() }
            )
            .frame(height: 52)
            if !session.answered {
                Text("Зелёные буквы — пока всё верно, красные — с места ошибки.")
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
                        Text("Не знаю")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        check()
                    } label: {
                        Text("Проверить")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
            if session.lastCorrect {
                Label("Верно!", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.green)
                if session.lastVerdict == .accentsOnly {
                    Text("Правильно пишется: \(q.answerText)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Label("Неверно", systemImage: "xmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.red)
                Text("Правильный ответ: \(q.answerText)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            if !level.promptIsPortuguese {
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
            Text(session.position + 1 >= session.queue.count ? "Завершить" : "Далее")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
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

    private var summaryView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(session.percent)%")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundColor(session.percent >= 80 ? Color.green : Color.orange)
                    Text("Верно с первого раза: \(session.correctCount) из \(session.totalCount)")
                        .foregroundColor(.secondary)
                    if session.percent >= 80 {
                        Text("Отличный результат! Можно переходить к следующему уровню.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    } else if session.totalCount > 0 {
                        Text("Повторите ещё раз, чтобы слова закрепились.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !session.mistakes.isEmpty {
                Section(header: Text("Ошибки")) {
                    ForEach(session.mistakes) { w in
                        WordRow(word: w, showStatus: false)
                    }
                }
            }

            Section {
                Button {
                    advanceWork?.cancel()
                    session.restart()
                    typed = ""
                    if !level.isChoice {
                        fieldFocused = true
                    }
                } label: {
                    Label("Пройти ещё раз", systemImage: "arrow.clockwise")
                }
                Button {
                    dismiss()
                } label: {
                    Label("Закончить", systemImage: "checkmark")
                }
            }
        }
    }
}
