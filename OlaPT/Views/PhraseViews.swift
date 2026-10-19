import SwiftUI

// MARK: - Тренировка фраз

/// Ход тренировки «Фразы»: собрать фразу из слов или набрать её целиком.
final class PhraseStudySession: ObservableObject {
    @Published var queue: [PhraseQuestion] = []
    @Published var position = 0
    @Published var answered = false
    @Published var lastCorrect = false
    @Published var lastVerdict: AnswerVerdict = .wrong
    /// Что ответил пользователь (для подсветки акцентов и «Можно и так»)
    @Published var lastAnswer = ""
    @Published var lastMatch = ""
    /// Выбранные плитки (индексы в question.tiles) по порядку
    @Published var picked: [Int] = []
    @Published var correctCount = 0
    @Published var totalCount = 0
    @Published var mistakes: [PhraseQuestion] = []
    @Published var accentSlips: [AccentSlip] = []
    @Published var finished = false

    private let generator: () -> [PhraseQuestion]

    init(generator: @escaping () -> [PhraseQuestion]) {
        self.generator = generator
        restart()
    }

    var current: PhraseQuestion? {
        return position < queue.count ? queue[position] : nil
    }

    var percent: Int {
        return totalCount == 0 ? 0 : Int((Double(correctCount) / Double(totalCount) * 100).rounded())
    }

    func restart() {
        queue = generator()
        position = 0
        answered = false
        picked = []
        correctCount = 0
        totalCount = 0
        mistakes = []
        accentSlips = []
        finished = queue.isEmpty
    }

    /// Собранная из плиток фраза
    var builtText: String {
        guard let q = current else { return "" }
        return picked.map { q.tiles[$0] }.joined(separator: " ")
    }

    func toggleTile(_ i: Int) {
        guard !answered else { return }
        if let k = picked.firstIndex(of: i) {
            picked.remove(at: k)
        } else {
            picked.append(i)
            SoundFX.shared.play(.tap)
        }
    }

    func answer(_ text: String, model: AppModel) {
        guard !answered, let q = current else { return }
        var verdict = PhraseBank.verdict(text, line: q.line)
        lastAnswer = text
        lastMatch = PhraseBank.accentMatch(text, line: q.line) ?? q.line.show
        if verdict == .accentsOnly && model.settings.strictAccents { verdict = .wrong }
        if verdict == .accentsOnly && !q.isRetry && !accentSlips.contains(where: { $0.key == q.item.id }) {
            accentSlips.append(AccentSlip(key: q.item.id, typed: text, answer: lastMatch))
        }
        finish(ok: verdict != .wrong, verdict: verdict, model: model)
    }

    func giveUp(model: AppModel) {
        guard !answered, current != nil else { return }
        lastAnswer = ""
        finish(ok: false, verdict: .wrong, model: model)
    }

    private func finish(ok: Bool, verdict: AnswerVerdict, model: AppModel) {
        guard let q = current else { return }
        answered = true
        lastCorrect = ok
        lastVerdict = verdict
        SoundFX.shared.play(ok ? .correct : .wrong)
        if !q.isRetry {
            totalCount += 1
            if ok { correctCount += 1 } else { mistakes.append(q) }
            model.recordPhrase(id: q.item.id, correct: ok, recognition: !q.typing,
                               accentsOnly: verdict == .accentsOnly)
            if !ok {
                // ещё раз в конце — та же фраза, слова перемешаны заново
                var retry = PhraseQuestion.make(item: q.item, line: q.line, typing: q.typing)
                retry.isRetry = true
                queue.append(retry)
            }
        }
    }

    func next() {
        position += 1
        answered = false
        picked = []
        if position >= queue.count { finished = true }
    }
}

struct PhraseSessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: PhraseStudySession
    let title: String
    /// Тренировка из плана «Сегодня»: «Пройти ещё раз» не показываем
    let isDaily: Bool

    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    init(title: String, isDaily: Bool = false, generator: @escaping () -> [PhraseQuestion]) {
        self.title = title
        self.isDaily = isDaily
        _session = StateObject(wrappedValue: PhraseStudySession(generator: generator))
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.finished {
                    summaryView
                } else if let q = session.current {
                    questionView(q)
                } else {
                    Text("Нет фраз").foregroundColor(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .onChange(of: session.position) { _ in
            typed = ""
            fieldFocused = session.current?.typing ?? false
        }
        .onAppear {
            fieldFocused = session.current?.typing ?? false
        }
    }

    // MARK: Вопрос

    @ViewBuilder
    private func questionView(_ q: PhraseQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelProgressBar(fraction: Double(session.position) / Double(max(1, session.queue.count)),
                                 fill: Theme.bloodBright)
                    .padding(.top, 8)
                if q.isRetry {
                    Text("Повторим фразу, в которой была ошибка")
                        .font(.footnote)
                        .foregroundColor(Theme.ember)
                }
                Text(q.typing ? "Напишите по-португальски" : "Соберите фразу по-португальски")
                    .font(.footnote)
                    .foregroundColor(Theme.textDim)
                Text(q.line.ru)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("phrase-prompt")
                if q.item.isPerson {
                    Text(q.item.title)
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                }

                if q.typing {
                    typingArea(q)
                } else {
                    tilesArea(q)
                }

                if session.answered {
                    feedback(q)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            session.giveUp(model: model)
                            fieldFocused = false
                        } label: {
                            Text("Не знаю").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GothicButtonStyle(.secondary))
                        Button {
                            check(q)
                        } label: {
                            Text("Проверить").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GothicButtonStyle(.primary))
                        .disabled(q.typing ? typed.trimmingCharacters(in: .whitespaces).isEmpty : session.picked.isEmpty)
                        .accessibilityIdentifier("phrase-check")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if session.answered {
                Button {
                    session.next()
                } label: {
                    Text(session.position + 1 >= session.queue.count ? "Завершить" : "Далее")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.primary))
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
            }
        }
    }

    private func check(_ q: PhraseQuestion) {
        if q.typing {
            session.answer(typed, model: model)
            fieldFocused = false
        } else {
            session.answer(session.builtText, model: model)
        }
    }

    // MARK: Собрать из слов

    @ViewBuilder
    private func tilesArea(_ q: PhraseQuestion) -> some View {
        VStack(spacing: 14) {
            // строка ответа: выбранные слова, касание возвращает слово обратно
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(session.picked, id: \.self) { i in
                    tile(q.tiles[i], selected: true) { session.toggleTile(i) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(10)
            .background(PixelFrame(fill: Theme.panelDeep, border: answerBorder))
            .accessibilityIdentifier("phrase-answer")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(q.tiles.indices, id: \.self) { i in
                    let used = session.picked.contains(i)
                    tile(q.tiles[i], selected: false) { session.toggleTile(i) }
                        .opacity(used ? 0.2 : 1)
                        .disabled(used || session.answered)
                        .accessibilityIdentifier("tile-\(i)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var answerBorder: Color {
        if !session.answered { return Theme.goldDark }
        return session.lastCorrect ? Theme.moss : Theme.red
    }

    private func tile(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.title3)
                .foregroundColor(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PixelFrame(fill: selected ? Theme.panelRaised : Theme.panel,
                                       border: selected ? Theme.gold : Theme.goldDark))
        }
        .buttonStyle(.plain)
        .disabled(session.answered)
    }

    // MARK: Набрать

    @ViewBuilder
    private func typingArea(_ q: PhraseQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Фраза по-португальски", text: $typed, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundColor(Theme.text)
                .lineLimit(1...3)
                .padding(12)
                .background(PixelFrame(fill: Theme.panelDeep))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($fieldFocused)
                .disabled(session.answered)
                .onSubmit { check(q) }
                .accessibilityIdentifier("phrase-field")
            if !session.answered {
                Text("Регистр и знаки препинания не важны. Забытый акцент засчитаем с напоминанием.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Результат

    @ViewBuilder
    private func feedback(_ q: PhraseQuestion) -> some View {
        let line = q.line
        let others = ([line.show] + line.also).filter {
            PhraseBank.normalize($0) != PhraseBank.normalize(session.lastMatch) || !session.lastCorrect
        }
        VStack(spacing: 10) {
            if session.lastCorrect && session.lastVerdict == .accentsOnly {
                Label("Верно, но с акцентом", systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(20, relativeTo: .title3))
                    .foregroundColor(Theme.goldBright)
                    .accessibilityIdentifier("accent-feedback")
                AccentHighlight.text(session.lastMatch, typed: session.lastAnswer)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.text)
            } else if session.lastCorrect {
                Label("Верно!", systemImage: "checkmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.moss)
                    .accessibilityIdentifier("phrase-correct")
            } else {
                Label("Неверно", systemImage: "xmark.circle.fill")
                    .font(Theme.pixel(22, relativeTo: .title3))
                    .foregroundColor(Theme.red)
                    .accessibilityIdentifier("phrase-wrong")
                HStack(spacing: 8) {
                    Text(line.show)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("phrase-show")
                    SpeakButton(text: line.show)
                }
            }
            let rest = session.lastCorrect ? others : Array(others.dropFirst())
            if !rest.isEmpty {
                Text((session.lastCorrect ? "Можно и так: " : "Или: ") + rest.joined(separator: "  ·  "))
                    .font(.subheadline)
                    .foregroundColor(Theme.goldBright)
                    .multilineTextAlignment(.center)
            }
            if !q.item.note.isEmpty {
                Text(q.item.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            if session.lastCorrect {
                SpeakButton(text: session.lastMatch.isEmpty ? line.show : session.lastMatch)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Итоги

    private var summaryView: some View {
        GothicList {
            Section {
                VStack(spacing: 8) {
                    Text("\(session.percent)%")
                        .font(Theme.pixel(54, relativeTo: .largeTitle))
                        .foregroundColor(session.percent >= 80 ? Theme.moss : Theme.ember)
                    Text("Верно с первого раза: \(session.correctCount) из \(session.totalCount)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            if !session.accentSlips.isEmpty {
                Section(header: GothicHeader("Проверьте акценты"),
                        footer: Text("Эти ответы засчитаны, но в них не хватало акцента.")) {
                    ForEach(session.accentSlips) { slip in
                        VStack(alignment: .leading, spacing: 2) {
                            AccentHighlight.text(slip.answer, typed: slip.typed)
                                .font(.headline)
                                .foregroundColor(Theme.text)
                            Text("вы написали: \(slip.typed)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            if !session.mistakes.isEmpty {
                Section(header: GothicHeader("Ошибки")) {
                    ForEach(session.mistakes) { q in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.line.ru)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(q.line.show)
                                .font(.headline)
                                .foregroundColor(Theme.text)
                        }
                    }
                }
            }
            Section {
                if !isDaily {
                    Button {
                        session.restart()
                        typed = ""
                    } label: {
                        Label("Пройти ещё раз", systemImage: "arrow.clockwise")
                    }
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

// MARK: - Все фразы

struct PhrasesView: View {
    @EnvironmentObject var model: AppModel
    @State private var training: PhraseSet?

    var body: some View {
        GothicList {
            Section(footer: Text("Выражения в лицах: «estar com fome» — «Estou com fome», «Ela está com fome». Новые фразы собираются из слов, знакомые — пишутся целиком. По три новые фразы в день попадают в план «Сегодня».")) {
                EmptyView()
            }
            ForEach(model.phrases.sets) { set in
                Section(header: GothicHeader("\(set.name) · \(set.level)")) {
                    Button {
                        training = set
                    } label: {
                        Label("Тренировать набор (\(set.items.count) \(Plural.phrases(set.items.count)))",
                              systemImage: "text.word.spacing")
                            .foregroundColor(Theme.gold)
                    }
                    .accessibilityIdentifier("train-\(set.id)")
                    ForEach(set.items) { item in
                        NavigationLink {
                            PhraseItemView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .foregroundColor(Theme.text)
                                Text(item.ru)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Фразы")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $training) { set in
            PhraseSessionView(title: set.name) {
                set.items.map { PhraseQuestion.make(item: $0, typing: model.phraseTyping($0.id)) }.shuffled()
            }
        }
    }
}

/// Карточка фразы: смысл, пояснение и таблица по лицам.
struct PhraseItemView: View {
    let item: PhraseItem

    var body: some View {
        GothicList {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(Theme.text)
                    Text(item.ru)
                        .foregroundColor(Theme.goldBright)
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section(header: GothicHeader(item.isPerson ? "По лицам" : "Как сказать")) {
                ForEach(item.lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line.show)
                                .foregroundColor(Theme.text)
                            if !line.also.isEmpty {
                                Text(line.also.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundColor(Theme.gold)
                            }
                            Text(line.ru)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        SpeakButton(text: line.show)
                    }
                }
            }
        }
        .navigationTitle(item.isPerson ? (item.pt.first ?? "") : "Фраза")
        .navigationBarTitleDisplayMode(.inline)
    }
}
