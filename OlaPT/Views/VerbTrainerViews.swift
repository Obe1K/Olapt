import SwiftUI

// MARK: - Настройка тренировки глаголов

struct VerbTrainerSetupView: View {
    @EnvironmentObject var model: AppModel

    enum Scope: String, CaseIterable, Identifiable {
        case all
        case irregular
        case collection

        var id: String { return rawValue }

        var title: String {
            switch self {
            case .all: return "Все глаголы"
            case .irregular: return "Только неправильные"
            case .collection: return "Из коллекции"
            }
        }
    }

    let initialCollectionID: UUID?

    @State private var scope: Scope = .all
    @State private var collectionID: UUID?
    @State private var selectedTenses: Set<String> = ["presente"]
    @State private var mode: VerbMode = .choice
    @State private var count: Int = 20
    @State private var request: VerbSessionRequest?
    @State private var didSetup = false

    init(initialCollectionID: UUID? = nil) {
        self.initialCollectionID = initialCollectionID
    }

    /// Коллекции, в которых есть хотя бы один глагол со спряжением.
    private var collectionsWithVerbs: [WordCollection] {
        var result: [WordCollection] = []
        for c in model.user.collections {
            if !verbs(in: c).isEmpty { result.append(c) }
        }
        return result
    }

    private func verbs(in c: WordCollection) -> [Verb] {
        var result: [Verb] = []
        for id in c.wordIDs {
            if let v = model.verbs.verb(forWordID: id) { result.append(v) }
        }
        return result
    }

    private var scopedVerbs: [Verb] {
        switch scope {
        case .all:
            return model.verbs.verbs
        case .irregular:
            return model.verbs.verbs.filter { $0.irregular }
        case .collection:
            if let id = collectionID, let c = model.collection(id) {
                return verbs(in: c)
            }
            return []
        }
    }

    private var chosenTenses: [TenseInfo] {
        return model.verbs.tenses.filter { selectedTenses.contains($0.id) }
    }

    private var canStart: Bool {
        return !scopedVerbs.isEmpty && !chosenTenses.isEmpty
    }

    var body: some View {
        GothicForm {
            Section(header: GothicHeader("Какие глаголы")) {
                Picker("Глаголы", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                if scope == .collection {
                    if collectionsWithVerbs.isEmpty {
                        Text("Нет коллекций с глаголами. Добавьте глаголы в коллекцию через карточку слова.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Коллекция", selection: $collectionID) {
                            ForEach(collectionsWithVerbs) { c in
                                Text(c.name).tag(Optional(c.id))
                            }
                        }
                    }
                }
                Text("Выбрано глаголов: \(scopedVerbs.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: GothicHeader("Времена"),
                    footer: Text("Можно выбрать несколько. Для новичка достаточно Presente, затем добавляйте Pretérito Perfeito и Imperfeito.")) {
                ForEach(model.verbs.tenses) { t in
                    Toggle(isOn: tenseBinding(t.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name)
                            Text(t.ru)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Button("Основные: настоящее, прошедшие, будущее") {
                    selectedTenses = ["presente", "perfeito", "imperfeito", "futuro"]
                }
            }

            Section(header: GothicHeader("Режим")) {
                Picker("Режим", selection: $mode) {
                    ForEach(VerbMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Количество вопросов", selection: $count) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("30").tag(30)
                    Text("50").tag(50)
                }
                .pickerStyle(.segmented)
            }

        }
        // Кнопка всегда видна внизу, а не спрятана в конце длинного списка времён.
        .safeAreaInset(edge: .bottom) {
            Button {
                start()
            } label: {
                Text("Начать")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .controlSize(.large)
            .disabled(!canStart)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background.opacity(0.95))
        }
        .navigationTitle("Тренировка глаголов")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didSetup {
                didSetup = true
                if let id = initialCollectionID {
                    scope = .collection
                    collectionID = id
                }
            }
        }
        .onChange(of: scope) { newScope in
            if newScope == .collection && collectionID == nil {
                collectionID = collectionsWithVerbs.first?.id
            }
        }
        .fullScreenCover(item: $request) { req in
            VerbSessionView(request: req)
        }
    }

    private func tenseBinding(_ id: String) -> Binding<Bool> {
        return Binding(
            get: { selectedTenses.contains(id) },
            set: { isOn in
                if isOn {
                    selectedTenses.insert(id)
                } else {
                    selectedTenses.remove(id)
                }
            }
        )
    }

    private func start() {
        request = VerbSessionRequest(verbs: scopedVerbs, tenses: chosenTenses, mode: mode, count: count)
    }
}

// MARK: - Состояние тренировки глаголов

final class VerbStudySession: ObservableObject {
    let request: VerbSessionRequest

    @Published var queue: [VerbQuestion] = []
    @Published var position: Int = 0
    @Published var answered: Bool = false
    @Published var selectedIndex: Int? = nil
    @Published var lastCorrect: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var mistakes: [VerbQuestion] = []
    @Published var finished: Bool = false

    init(request: VerbSessionRequest, library: VerbLibrary, progress: [String: WordProgress]) {
        self.request = request
        let builder = VerbExerciseBuilder(library: library, progress: progress)
        self.queue = builder.makeQuestions(verbs: request.verbs, tenses: request.tenses,
                                           mode: request.mode, count: request.count)
        self.finished = queue.isEmpty
    }

    var current: VerbQuestion? {
        if position >= 0 && position < queue.count { return queue[position] }
        return nil
    }

    var percent: Int {
        if totalCount == 0 { return 0 }
        return Int((Double(correctCount) / Double(totalCount) * 100.0).rounded())
    }

    func restart(library: VerbLibrary, progress: [String: WordProgress]) {
        let builder = VerbExerciseBuilder(library: library, progress: progress)
        queue = builder.makeQuestions(verbs: request.verbs, tenses: request.tenses,
                                      mode: request.mode, count: request.count)
        position = 0
        answered = false
        selectedIndex = nil
        correctCount = 0
        totalCount = 0
        mistakes = []
        finished = queue.isEmpty
    }

    func answerChoice(_ choice: Int, model: AppModel) {
        guard !answered, let q = current else { return }
        selectedIndex = choice
        finish(ok: choice == q.correctIndex, question: q, model: model)
    }

    func answerText(_ text: String, model: AppModel) {
        guard !answered, let q = current else { return }
        finish(ok: VerbExerciseBuilder.isCorrect(input: text, question: q), question: q, model: model)
    }

    func giveUp(model: AppModel) {
        guard !answered, let q = current else { return }
        finish(ok: false, question: q, model: model)
    }

    private func finish(ok: Bool, question q: VerbQuestion, model: AppModel) {
        answered = true
        lastCorrect = ok
        if !q.isRetry {
            totalCount += 1
            if ok {
                correctCount += 1
            } else {
                mistakes.append(q)
            }
            model.recordVerb(verb: q.verb, tense: q.tense, correct: ok)
            if !ok {
                var retry = q
                retry.isRetry = true
                queue.append(retry)
            }
        }
    }

    func next() {
        position += 1
        answered = false
        selectedIndex = nil
        if position >= queue.count {
            finished = true
        }
    }
}

// MARK: - Экран тренировки глаголов

struct VerbSessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: VerbStudySession
    let request: VerbSessionRequest

    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    init(request: VerbSessionRequest) {
        self.request = request
        // Библиотека и прогресс подставляются в onAppear (EnvironmentObject недоступен в init),
        // поэтому стартуем с пустой очереди и сразу перезапускаем.
        _session = StateObject(wrappedValue: VerbStudySession(request: request,
                                                              library: VerbLibrary(tenses: [], verbs: []),
                                                              progress: [:]))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !started {
                    ProgressView()
                } else if session.finished {
                    summaryView
                } else if let q = session.current {
                    questionView(q)
                } else {
                    Text("Нет вопросов")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Спряжение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .onAppear {
            if !started {
                session.restart(library: model.verbs, progress: model.user.verbProgress)
                started = true
                if request.mode == .typing {
                    fieldFocused = true
                }
            }
        }
        .onChange(of: session.position) { _ in
            typed = ""
            if request.mode == .typing && !session.finished {
                fieldFocused = true
            }
        }
    }

    @State private var started = false

    // MARK: Вопрос

    @ViewBuilder
    private func questionView(_ q: VerbQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelProgressBar(fraction: Double(session.position) / Double(max(1, session.queue.count)),
                                 fill: Theme.bloodBright)
                    .padding(.top, 8)

                if q.isRetry {
                    Text("Повторим форму, в которой была ошибка")
                        .font(.footnote)
                        .foregroundColor(Theme.ember)
                }

                VStack(spacing: 4) {
                    Text(q.tense.name)
                        .font(Theme.pixel(17, relativeTo: .headline))
                        .foregroundColor(Theme.goldBright)
                    Text(q.tense.ru)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Text(q.verb.inf)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Theme.text)
                    SpeakButton(text: q.verb.base)
                }

                HStack(spacing: 8) {
                    Text(q.lead)
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(session.answered ? q.answer : "_____")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(answerColor(q))
                }
                .padding(.vertical, 6)

                if request.mode == .choice {
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
    }

    private func answerColor(_ q: VerbQuestion) -> Color {
        if !session.answered { return Theme.text }
        return session.lastCorrect ? Theme.moss : Theme.red
    }

    private func choiceColor(_ i: Int, _ q: VerbQuestion) -> Color {
        if !session.answered { return Theme.panel }
        if i == q.correctIndex { return Theme.mossDark }
        if session.selectedIndex == i { return Theme.bloodDark }
        return Theme.panel
    }

    @ViewBuilder
    private func choiceList(_ q: VerbQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(q.options.indices, id: \.self) { i in
                Button {
                    session.answerChoice(i, model: model)
                } label: {
                    HStack {
                        Text(q.options[i])
                            .font(.title3)
                            .foregroundColor(Theme.text)
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

    @ViewBuilder
    private func typingArea(_ q: VerbQuestion) -> some View {
        VStack(spacing: 12) {
            TextField("Форма глагола", text: $typed)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundColor(Theme.text)
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(PixelFrame(fill: Theme.panelDeep))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($fieldFocused)
                .disabled(session.answered)
                .onSubmit {
                    check()
                }
            if !session.answered {
                Text("Ударения важны: falamos ≠ falámos.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button {
                        session.giveUp(model: model)
                        fieldFocused = false
                    } label: {
                        Text("Не знаю")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GothicButtonStyle(.secondary))

                    Button {
                        check()
                    } label: {
                        Text("Проверить")
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

    @ViewBuilder
    private func feedback(_ q: VerbQuestion) -> some View {
        VStack(spacing: 10) {
            if session.lastCorrect {
                Label("Верно!", systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.moss)
            } else {
                Label("Неверно", systemImage: "xmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.red)
                Text("Правильно: \(q.lead) \(q.answer)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                Text("\(q.lead) \(q.answer)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                SpeakButton(text: q.answer)
            }
            Button {
                session.next()
            } label: {
                Text(session.position + 1 >= session.queue.count ? "Завершить" : "Далее")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .controlSize(.large)
        }
        .padding(.top, 6)
    }

    // MARK: Итоги

    private var summaryView: some View {
        GothicList {
            Section {
                VStack(spacing: 8) {
                    Text("\(session.percent)%")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundColor(session.percent >= 80 ? Theme.moss : Theme.ember)
                    Text("Верно с первого раза: \(session.correctCount) из \(session.totalCount)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !session.mistakes.isEmpty {
                Section(header: GothicHeader("Ошибки")) {
                    ForEach(session.mistakes) { q in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(q.verb.inf) · \(q.tense.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(q.lead) \(q.answer)")
                                .font(.headline)
                        }
                    }
                }
            }

            Section {
                Button {
                    session.restart(library: model.verbs, progress: model.user.verbProgress)
                    typed = ""
                    if request.mode == .typing {
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
