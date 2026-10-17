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
        List {
            Section {
                PetView(isVisible: active == nil)
                    .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            if !hasAnyWords {
                startSection
            } else {
                planSection(plan)
                forecastSection
            }

            difficultSection

            howItWorksSection
        }
        .navigationTitle("Сегодня")
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

    // MARK: План

    @ViewBuilder
    private func planSection(_ plan: AppModel.DailyPlan) -> some View {
        Section {
            if !plan.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("План на сегодня")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(plan.total)")
                            .font(.system(size: 44, weight: .bold))
                        Text(Plural.words(plan.total))
                            .font(.title3)
                        Spacer()
                        Text("≈ \(model.estimatedMinutes(questions: plan.total)) мин")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 16) {
                        planChip(value: plan.dueIDs.count, title: "повторить", color: .orange)
                        planChip(value: plan.newIDs.count, title: "новых", color: .accentColor)
                    }
                    Button {
                        active = .daily
                    } label: {
                        Text(plan.reviewedToday > 0 ? "Продолжить" : "Начать")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("today-start")
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if plan.reviewedToday > 0 {
                        Label("На сегодня всё", systemImage: "checkmark.seal.fill")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.green)
                        Text("Сегодня пройдено: \(plan.reviewedToday) \(Plural.words(plan.reviewedToday)). Ещё раз проходить не нужно — приходите завтра.")
                            .font(.subheadline)
                    } else {
                        Label("Сегодня повторять нечего", systemImage: "cup.and.saucer.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.green)
                        Text(plan.hasMoreNew
                             ? "Все слова повторены вовремя."
                             : "Все слова повторены вовремя, а новых в коллекциях не осталось. Добавьте слова в коллекцию — они появятся здесь.")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityIdentifier("today-done")

                if plan.hasMoreNew {
                    Button {
                        active = .extraNew
                    } label: {
                        Label("Есть время и желание? Ещё \(model.settings.newWordsPerDay) новых слов", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("today-extra")
                }
            }
        }
    }

    private func planChip(value: Int, title: String, color: Color) -> some View {
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(value) \(title)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Прогноз

    private var forecastSection: some View {
        let days = model.forecast(days: 7)
        return Section(header: Text("Повторения на неделю"),
                       footer: Text("Сюда добавятся новые слова — до \(model.settings.newWordsPerDay) в день, пока в коллекциях есть неначатые. Число новых слов в день меняется в Настройках.")) {
            ForEach(0..<days.count, id: \.self) { i in
                HStack {
                    Text(dayTitle(offset: i + 1))
                    Spacer()
                    if days[i] == 0 {
                        Text("—")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(days[i]) \(Plural.words(days[i])) · ≈ \(model.estimatedMinutes(questions: days[i])) мин")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: Трудные слова

    private var difficultSection: some View {
        let count = model.difficultWords.count
        return Section {
            NavigationLink {
                DifficultWordsView()
            } label: {
                HStack {
                    Label("Трудные слова", systemImage: "flame")
                    Spacer()
                    Text(count > 0 ? "\(count)" : "пока нет")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityIdentifier("open-difficult")
        }
    }

    // MARK: Начало

    private var startSection: some View {
        Section(footer: Text("Новые слова берутся из ваших коллекций по порядку — до \(model.settings.newWordsPerDay) в день.")) {
            EmptyHint(title: "Добавьте слова, чтобы начать",
                      message: "Возьмите готовый набор или сохраните слова из словаря в коллекцию — и здесь появится план на каждый день.")
            if !model.index.levels.isEmpty {
                NavigationLink {
                    LevelsView()
                } label: {
                    Label("Наборы по уровням (A1, A2…)", systemImage: "chart.bar")
                }
            }
            NavigationLink {
                TopicsView()
            } label: {
                Label("Наборы слов по темам", systemImage: "square.grid.2x2")
            }
        }
    }

    // MARK: Как это работает

    private var howItWorksSection: some View {
        Section(header: Text("Как заниматься")) {
            faqRow(question: "Сколько заниматься сегодня?",
                   answer: "Ровно план дня. Когда он выполнен, на сегодня всё.")
            faqRow(question: "Пройти ещё раз?",
                   answer: "Не нужно. Повторение раньше срока почти не укрепляет память. Приложение само вернёт слово в тот день, когда вы начнёте его забывать.")
            faqRow(question: "Завтра или можно через день?",
                   answer: "Лучше каждый день — тогда план короткий. Пропуск дня не страшен: слова подождут, просто следующий план будет больше.")
            faqRow(question: "Когда слово «выучено»?",
                   answer: "Верный ответ отодвигает следующее повторение: завтра → через 4 дня → через 2 недели → через месяц и дальше. Ошибка возвращает слово на завтра. «Выучено» — когда слово держится в памяти 3 недели и дольше.")
        }
    }

    private func faqRow(question: String, answer: String) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.subheadline.weight(.semibold))
            Text(answer)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
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
        List {
            if words.isEmpty {
                Section {
                    EmptyHint(title: "Трудных слов пока нет",
                              message: "Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше.")
                }
            } else {
                Section(header: Text("Учить"),
                        footer: Text("Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше. Слово уходит из списка, когда становится «выученным».")) {
                    ForEach(ExerciseLevel.allCases) { level in
                        Button {
                            activeLevel = level
                        } label: {
                            LevelRow(level: level, best: nil)
                        }
                    }
                }
                Section(header: Text("Слова (\(words.count))")) {
                    ForEach(words) { w in
                        NavigationLink {
                            WordCardView(word: w)
                        } label: {
                            HStack {
                                WordRow(word: w, showStatus: false)
                                Text("ошибок: \(model.progress(for: w.id).wrong)")
                                    .font(.caption)
                                    .foregroundColor(.red)
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
