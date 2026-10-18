import SwiftUI

// MARK: - Вкладка «Сегодня»

/// Какая тренировка открыта с экрана «Сегодня».
enum TodaySession: Int, Identifiable {
    case daily      // план дня: повторения + новые слова
    case extraNew   // по желанию: ещё порция новых слов сверх дневной нормы

    var id: Int { return rawValue }
}

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var active: TodaySession?
    /// Меняется при возвращении в приложение, чтобы план пересчитался после полуночи.
    @State private var refreshTick = 0

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    private func dayTitle(offset: Int) -> String {
        switch offset {
        case 1: return "Завтра"
        case 2: return "Послезавтра"
        default:
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let text = TodayView.dayFormatter.string(from: date)
            return text.prefix(1).uppercased() + text.dropFirst()
        }
    }

    /// Есть ли вообще чему учиться: слова в коллекциях или начатые слова.
    private var hasAnyWords: Bool {
        if !model.user.srs.isEmpty { return true }
        return model.user.collections.contains { !$0.wordIDs.isEmpty }
    }

    var body: some View {
        let _ = refreshTick
        let plan = model.dailyPlan()
        ScrollView {
            VStack(spacing: 14) {
                // Сцена во всю ширину, без рамки: снизу растворяется в каменном фоне.
                PetView(isVisible: active == nil)

                VStack(spacing: 14) {
                    towerCard
                    if !hasAnyWords {
                        startCard
                    } else {
                        planCard(plan)
                        forecastCard
                    }
                    linksCard
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .navigationTitle("Сегодня")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshTick += 1 }
        }
        .onAppear { refreshTick += 1 }
        .fullScreenCover(item: $active) { kind in
            switch kind {
            case .daily:
                StudySessionView(level: nil, title: "Сегодня", collectionID: nil, isDaily: true,
                                 generator: { makeDailyQuestions() })
            case .extraNew:
                StudySessionView(level: nil, title: "Новые слова", collectionID: nil, isDaily: true,
                                 generator: { makeExtraNewQuestions() })
            }
        }
    }

    // MARK: Башня

    private var towerCard: some View {
        let room = model.towerRoom
        let inMemory = model.wordsInMemory()
        return VStack(alignment: .leading, spacing: 10) {
            GothicHeader("\(room.title) · \(room.level)")
            Text("Слов в памяти: \(inMemory)")
                .font(Theme.pixel(17, relativeTo: .headline))
                .foregroundColor(Theme.text)
            if let next = model.nextRoomProgress() {
                progressRow(title: "До этажа «\(next.room.title)»: \(next.have) / \(next.need) слов \(next.level)",
                            fraction: Double(next.have) / Double(max(1, next.need)))
            } else {
                Text("Вы на вершине башни.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textDim)
            }
            if let item = model.nextItemProgress() {
                progressRow(title: "Следующая вещь в башне — \(item.title): ещё \(max(0, item.need - item.have)) \(Plural.words(max(0, item.need - item.have)))",
                            fraction: Double(item.have % AppModel.wordsPerItem) / Double(AppModel.wordsPerItem))
            } else {
                Text("Башня обставлена полностью.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textDim)
            }
            Text("Слово «в памяти», если вы помните его хотя бы неделю.")
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tower-card")
    }

    private func progressRow(title: String, fraction: Double) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            PixelProgressBar(fraction: fraction)
        }
    }

    // MARK: План

    @ViewBuilder
    private func planCard(_ plan: AppModel.DailyPlan) -> some View {
        if !plan.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GothicHeader("План на сегодня")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(plan.total)")
                        .font(Theme.pixel(44, relativeTo: .largeTitle))
                        .foregroundColor(Theme.text)
                    Text(Plural.words(plan.total))
                        .font(Theme.pixel(20, relativeTo: .title3))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text("~\(model.estimatedMinutes(questions: plan.total)) мин")
                        .font(Theme.pixel(20, relativeTo: .title3))
                        .foregroundColor(Theme.textDim)
                }
                HStack(spacing: 16) {
                    planChip(value: plan.dueIDs.count, title: "повторить", color: Theme.gold)
                    planChip(value: plan.newIDs.count, title: "новых", color: Theme.bloodBright)
                }
                Button {
                    active = .daily
                } label: {
                    Text(plan.reviewedToday > 0 ? "Продолжить" : "Начать")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.primary))
                .accessibilityIdentifier("today-start")
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    if plan.reviewedToday > 0 {
                        Label("На сегодня всё", systemImage: "checkmark.seal.fill")
                            .font(Theme.pixel(24, relativeTo: .title2))
                            .foregroundColor(Theme.moss)
                        Text("Сегодня пройдено: \(plan.reviewedToday) \(Plural.words(plan.reviewedToday)). Ещё раз проходить не нужно — приходите завтра.")
                            .font(.subheadline)
                            .foregroundColor(Theme.text)
                    } else {
                        Label("Сегодня повторять нечего", systemImage: "moon.stars.fill")
                            .font(Theme.pixel(20, relativeTo: .title3))
                            .foregroundColor(Theme.moss)
                        Text(plan.hasMoreNew
                             ? "Все слова повторены вовремя."
                             : "Все слова повторены вовремя, а новых в коллекциях не осталось. Добавьте слова в коллекцию — они появятся здесь.")
                            .font(.subheadline)
                            .foregroundColor(Theme.text)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today-done")

                if plan.hasMoreNew {
                    Button {
                        active = .extraNew
                    } label: {
                        Text("Ещё \(model.settings.newWordsPerDay) новых слов")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GothicButtonStyle(.secondary))
                    .accessibilityIdentifier("today-extra")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel()
        }
    }

    private func planChip(value: Int, title: String, color: Color) -> some View {
        return HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(value) \(title)")
                .font(.subheadline)
                .foregroundColor(Theme.textDim)
        }
    }

    // MARK: Прогноз

    private var forecastCard: some View {
        let days = model.forecast(days: 7)
        return VStack(alignment: .leading, spacing: 8) {
            GothicHeader("Повторения на неделю")
            ForEach(0..<days.count, id: \.self) { i in
                HStack {
                    Text(dayTitle(offset: i + 1))
                        .foregroundColor(Theme.text)
                    Spacer()
                    if days[i] == 0 {
                        Text("—")
                            .foregroundColor(Theme.textDim)
                    } else {
                        Text("\(days[i]) \(Plural.words(days[i])) · ≈ \(model.estimatedMinutes(questions: days[i])) мин")
                            .foregroundColor(Theme.textDim)
                    }
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    // MARK: Ссылки

    private var linksCard: some View {
        let count = model.difficultWords.count
        return VStack(spacing: 0) {
            NavigationLink {
                DifficultWordsView()
            } label: {
                linkRow(icon: "flame", title: "Трудные слова", value: count > 0 ? "\(count)" : "пока нет")
            }
            .accessibilityIdentifier("open-difficult")
        }
        .pixelPanel(padding: 6)
    }

    private func linkRow(icon: String, title: String, value: String) -> some View {
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Theme.gold)
                .frame(width: 24)
            Text(title)
                .foregroundColor(Theme.text)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textDim)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Theme.goldDark)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    // MARK: Начало

    private var startCard: some View {
        return VStack(alignment: .leading, spacing: 10) {
            EmptyHint(title: "Добавьте слова, чтобы начать",
                      message: "Возьмите готовый набор или сохраните слова из словаря в коллекцию — и здесь появится план на каждый день. Новые слова берутся из коллекций по порядку — до \(model.settings.newWordsPerDay) в день.")
            if !model.index.levels.isEmpty {
                NavigationLink {
                    LevelsView()
                } label: {
                    linkRow(icon: "chart.bar", title: "Наборы по уровням (A1, A2…)", value: "")
                }
            }
            NavigationLink {
                TopicsView()
            } label: {
                linkRow(icon: "square.grid.2x2", title: "Наборы слов по темам", value: "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    // MARK: Вопросы

    /// Слова всех коллекций — для неверных вариантов ответа.
    private func collectionPool() -> [Word] {
        var seen = Set<String>()
        var pool: [Word] = []
        for c in model.user.collections {
            for w in model.words(in: c) where seen.insert(w.id).inserted {
                pool.append(w)
            }
        }
        return pool
    }

    private func makeDailyQuestions() -> [WordQuestion] {
        let plan = model.dailyPlan()
        let due = plan.dueIDs.compactMap { model.index.word($0) }
        let new = plan.newIDs.compactMap { model.index.word($0) }
        let builder = ExerciseBuilder(index: model.index, settings: model.settings)
        return builder.makeDailyQuestions(dueWords: due, newWords: new, states: model.user.srs,
                                          pool: collectionPool() + due)
    }

    private func makeExtraNewQuestions() -> [WordQuestion] {
        let ids = model.unstartedCollectionWords(limit: model.settings.newWordsPerDay)
        let new = ids.compactMap { model.index.word($0) }
        let builder = ExerciseBuilder(index: model.index, settings: model.settings)
        return builder.makeDailyQuestions(dueWords: [], newWords: new, states: model.user.srs,
                                          pool: collectionPool())
    }
}

// MARK: - Трудные слова

/// Автоматическая коллекция: слова, в которых было 2 ошибки и больше и которые ещё не выучены.
struct DifficultWordsView: View {
    @EnvironmentObject var model: AppModel
    @State private var activeLevel: ExerciseLevel?

    var body: some View {
        let words = model.difficultWords
        GothicList {
            if words.isEmpty {
                Section {
                    EmptyHint(title: "Трудных слов пока нет",
                              message: "Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше.")
                }
            } else {
                Section(header: GothicHeader("Учить"),
                        footer: Text("Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше. Слово уходит из списка, когда становится «выученным».")) {
                    ForEach(ExerciseLevel.allCases) { level in
                        Button {
                            activeLevel = level
                        } label: {
                            LevelRow(level: level, best: nil)
                        }
                    }
                }
                Section(header: GothicHeader("Слова (\(words.count))")) {
                    ForEach(words) { w in
                        NavigationLink {
                            WordCardView(word: w)
                        } label: {
                            HStack {
                                WordRow(word: w, showStatus: false)
                                Text("ошибок: \(model.progress(for: w.id).wrong)")
                                    .font(.caption)
                                    .foregroundColor(Theme.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Трудные слова")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeLevel) { level in
            StudySessionView(level: level, title: "Трудные слова", collectionID: nil, generator: {
                let words = model.difficultWords
                let builder = ExerciseBuilder(index: model.index, settings: model.settings)
                return builder.makeQuestions(words: words, level: level, count: model.settings.sessionSize)
            })
        }
    }
}
