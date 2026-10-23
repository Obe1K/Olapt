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
            case .all: return L("Все глаголы")
            case .irregular: return L("Только неправильные")
            case .collection: return L("Из коллекции")
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
            Section(header: GothicHeader(L("Какие глаголы"))) {
                Picker(L("Глаголы"), selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                if scope == .collection {
                    if collectionsWithVerbs.isEmpty {
                        Text(L("Нет коллекций с глаголами. Добавьте глаголы в коллекцию через карточку слова."))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Picker(L("Коллекция"), selection: $collectionID) {
                            ForEach(collectionsWithVerbs) { c in
                                Text(c.name).tag(Optional(c.id))
                            }
                        }
                    }
                }
                Text(L("Выбрано глаголов: %d", scopedVerbs.count))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: GothicHeader(L("Времена")),
                    footer: Text(L("Можно выбрать несколько. Для новичка достаточно Presente, затем добавляйте Pretérito Perfeito и Imperfeito."))) {
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
                Button(L("Основные: настоящее, прошедшие, будущее")) {
                    selectedTenses = ["presente", "perfeito", "imperfeito", "futuro"]
                }
            }

            Section(header: GothicHeader(L("Режим"))) {
                Picker(L("Режим"), selection: $mode) {
                    ForEach(VerbMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                Picker(L("Количество вопросов"), selection: $count) {
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
                Text(L("Начать"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .controlSize(.large)
            .disabled(!canStart)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.background.opacity(0.95))
        }
        .navigationTitle(L("Тренировка глаголов"))
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
    /// Как проверен последний ответ и что было введено (для подсветки акцентов)
    @Published var lastVerdict: VerbVerdict = .wrong
    @Published var lastTyped: String = ""
    /// Формы, засчитанные без нужного акцента
    @Published var accentSlips: [AccentSlip] = []
    @Published var finished: Bool = false

    init(request: VerbSessionRequest, library: VerbLibrary, progress: [String: WordProgress]) {
        self.request = request
        self.queue = VerbStudySession.makeQueue(request: request, library: library, progress: progress)
        self.finished = queue.isEmpty
    }

    var current: VerbQuestion? {
        if position >= 0 && position < queue.count { return queue[position] }
        return nil
    }

    /// Текущий вопрос — с вводом формы (у вопросов с выбором есть варианты)
    var currentIsTyping: Bool {
        return current.map { $0.options.isEmpty } ?? false
    }

    static func makeQueue(request: VerbSessionRequest, library: VerbLibrary, progress: [String: WordProgress]) -> [VerbQuestion] {
        let builder = VerbExerciseBuilder(library: library, progress: progress)
        if !request.dailyPairs.isEmpty {
            var result: [VerbQuestion] = []
            for pair in request.dailyPairs {
                let persons = library.activePersons(pair.tense).filter { !pair.verb.form(pair.tense.id, $0).isEmpty }
                guard let p = persons.randomElement() else { continue }
                result.append(builder.makeQuestion(verb: pair.verb, tense: pair.tense, person: p,
                                                   mode: pair.typing ? .typing : .choice))
            }
            return result.shuffled()
        }
        return builder.makeQuestions(verbs: request.verbs, tenses: request.tenses,
                                     mode: request.mode, count: request.count)
    }

    var percent: Int {
        if totalCount == 0 { return 0 }
        return Int((Double(correctCount) / Double(totalCount) * 100.0).rounded())
    }

    func restart(library: VerbLibrary, progress: [String: WordProgress]) {
        queue = VerbStudySession.makeQueue(request: request, library: library, progress: progress)
        position = 0
        answered = false
        selectedIndex = nil
        correctCount = 0
        totalCount = 0
        mistakes = []
        accentSlips = []
        finished = queue.isEmpty
    }

    func answerChoice(_ choice: Int, model: AppModel) {
        guard !answered, let q = current else { return }
        selectedIndex = choice
        lastVerdict = choice == q.correctIndex ? .exact : .wrong
        finish(ok: choice == q.correctIndex, question: q, model: model)
    }

    func answerText(_ text: String, model: AppModel) {
        guard !answered, let q = current else { return }
        let verdict = VerbExerciseBuilder.verdict(input: text, question: q, tenses: model.verbs.tenses)
        lastVerdict = verdict
        lastTyped = text
        // Строгий режим (Настройки → Упражнения): без акцента — ошибка
        let accentOK = verdict == .accentsOnly && !model.settings.strictAccents
        if accentOK && !q.isRetry {
            let key = q.verb.inf + "|" + q.tense.id + "|\(q.person)"
            if !accentSlips.contains(where: { $0.key == key }) {
                accentSlips.append(AccentSlip(key: key, typed: text, answer: q.lead + " " + q.answer))
            }
        }
        finish(ok: verdict == .exact || accentOK, accentsOnly: accentOK, question: q, model: model)
    }

    func giveUp(model: AppModel) {
        guard !answered, let q = current else { return }
        lastVerdict = .wrong
        finish(ok: false, question: q, model: model)
    }

    private func finish(ok: Bool, accentsOnly: Bool = false, question q: VerbQuestion, model: AppModel) {
        answered = true
        lastCorrect = ok
        SoundFX.shared.play(ok ? .correct : .wrong)
        if !q.isRetry {
            totalCount += 1
            if ok {
                correctCount += 1
            } else {
                mistakes.append(q)
            }
            model.recordVerb(verb: q.verb, tense: q.tense, correct: ok, recognition: !q.options.isEmpty,
                             accentsOnly: accentsOnly)
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
                    Text(L("Нет вопросов"))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(L("Спряжение"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Закрыть")) { dismiss() }
                }
            }
        }
        .onAppear {
            if !started {
                session.restart(library: model.verbs, progress: model.user.verbProgress)
                started = true
                if session.currentIsTyping {
                    fieldFocused = true
                }
            }
        }
        .onChange(of: session.position) { _ in
            typed = ""
            if session.currentIsTyping && !session.finished {
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
                PixelProgressBar(fraction: Double(session.position + (session.answered ? 1 : 0)) / Double(max(1, session.queue.count)),
                                 fill: Theme.bloodBright)
                    .padding(.top, 8)

                if q.isRetry {
                    Text(L("Повторим форму, в которой была ошибка"))
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

                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Text(q.verb.inf)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Theme.text)
                        SpeakButton(text: q.verb.base)
                    }
                    let translation = model.verbExerciseTranslation(q.verb)
                    if !translation.isEmpty {
                        Text(translation)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("verb-translation")
                    }
                }

                // Главное в задании — лицо, в которое ставим глагол: крупно, золотом, в рамке.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        leadText(q)
                        blankText(q)
                    }
                    VStack(spacing: 6) {
                        leadText(q)
                        blankText(q)
                    }
                }
                .frame(maxWidth: .infinity)
                .pixelPanel(fill: Theme.panelRaised, border: Theme.gold, padding: 14)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("verb-prompt")

                if !q.options.isEmpty {
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

    /// «que» / «quando» — светлым, само местоимение — золотом; всё жирным и крупно.
    private func leadText(_ q: VerbQuestion) -> some View {
        let pronoun = Text(q.pronoun).foregroundColor(Theme.goldBright)
        let lead = q.tense.prefix.isEmpty ? pronoun : Text(q.tense.prefix + " ").foregroundColor(Theme.text) + pronoun
        return lead
            .font(.system(size: 30, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func blankText(_ q: VerbQuestion) -> some View {
        return Text(session.answered ? q.answer : "_____")
            .font(.system(size: 30, weight: .semibold))
            .foregroundColor(answerColor(q))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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
            TextField(L("Форма глагола"), text: $typed)
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
                Text(L("Забытый акцент засчитаем с напоминанием, но falamos ≠ falámos — это разные времена."))
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    @ViewBuilder
    private func feedback(_ q: VerbQuestion) -> some View {
        VStack(spacing: 10) {
            if session.lastCorrect && session.lastVerdict == .accentsOnly {
                Label(L("Верно, но с акцентом"), systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(20, relativeTo: .title3))
                    .foregroundColor(Theme.goldBright)
                    .accessibilityIdentifier("accent-feedback")
                AccentHighlight.text(q.answer, typed: session.lastTyped, lead: q.lead + " ")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.text)
                Text(L("Засчитано. Не забывайте акцент: в глаголах он часто отличает одно время от другого."))
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
                switch session.lastVerdict {
                case let .otherForm(form, tenseName, pronoun):
                    Text(L("«%@» — это %@%@. Здесь нужен акцент:", form, tenseName, pronoun.isEmpty ? "" : " (" + pronoun + ")"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("other-form-feedback")
                    AccentHighlight.text(q.answer, typed: session.lastTyped, lead: q.lead + " ")
                        .font(.headline)
                        .foregroundColor(Theme.text)
                case .accentsOnly:
                    AccentHighlight.text(q.answer, typed: session.lastTyped, lead: q.lead + " ")
                        .font(.headline)
                        .foregroundColor(Theme.text)
                    Text(L("Включена строгая проверка ударений (Настройки → Упражнения)."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                default:
                    Text(L("Правильно: %@ %@", q.lead, q.answer))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
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
                Text(session.position + 1 >= session.queue.count ? L("Завершить") : L("Далее"))
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
                    Text(L("Верно с первого раза: %d из %d", session.correctCount, session.totalCount))
                        .foregroundColor(.secondary)
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
                    if session.currentIsTyping {
                        fieldFocused = true
                    }
                } label: {
                    Label(L("Пройти ещё раз"), systemImage: "arrow.clockwise")
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
