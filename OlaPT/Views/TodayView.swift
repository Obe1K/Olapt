import SwiftUI

// MARK: - Вкладка «Сегодня»

/// Какая тренировка открыта с экрана «Сегодня».
enum TodaySession: Int, Identifiable {
    case daily      // план дня: повторения + новые слова
    case extraNew   // по желанию: ещё порция новых слов сверх дневной нормы
    case boss       // бой с боссом недели
    case verbs      // глаголы на сегодня
    case phrases    // фразы на сегодня

    var id: Int { return rawValue }
}

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var active: TodaySession?
    /// Меняется при возвращении в приложение, чтобы план пересчитался после полуночи.
    @State private var refreshTick = 0
    /// «В башне появилось: Ворон» — показывается несколько секунд поверх сцены

    private static let ruDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    private static let enDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    /// «Суббота, 25 октября» / «Saturday, 25 October» — по языку интерфейса.
    private static var dayFormatter: DateFormatter {
        return Loc.isEnglish ? enDayFormatter : ruDayFormatter
    }

    private func dayTitle(offset: Int) -> String {
        switch offset {
        case 1: return L("Завтра")
        case 2: return L("Послезавтра")
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
                        verbsCard
                        phrasesCard
                        if model.bossAvailable {
                            bossCard
                        }
                        forecastCard
                    }
                    linksCard
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(StoneBackground().ignoresSafeArea())
        .navigationTitle(L("Сегодня"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshTick += 1
                SoundFX.shared.resumeMusic()
            }
        }
        .onAppear {
            refreshTick += 1
            SoundFX.shared.startMusic()
        }
        .onDisappear { SoundFX.shared.stopMusic() }
        .fullScreenCover(item: $active) { kind in
            switch kind {
            case .daily:
                StudySessionView(level: nil, title: L("Сегодня"), collectionID: nil, isDaily: true,
                                 generator: { makeDailyQuestions() })
            case .extraNew:
                StudySessionView(level: nil, title: L("Новые слова"), collectionID: nil, isDaily: true,
                                 generator: { makeExtraNewQuestions() })
            case .verbs:
                let vp = model.dailyVerbPlan()
                VerbSessionView(request: VerbSessionRequest(verbs: [], tenses: [], mode: .choice, count: 0,
                                                            dailyPairs: vp.due + vp.new))
            case .phrases:
                PhraseSessionView(title: L("Фразы"), isDaily: true) { makeDailyPhraseQuestions() }
            case .boss:
                let cfg = model.bossConfig()
                StudySessionView(level: nil, title: L("Босс недели"), collectionID: nil, boss: cfg,
                                 generator: { makeBossQuestions(count: cfg.hp) })
            }
        }
    }

    // MARK: Башня

    private var towerCard: some View {
        let inMemory = model.wordsInMemory()
        return VStack(alignment: .leading, spacing: 10) {
            GothicHeader(L("Башня"))
            Text(L("Слов в памяти: %d", inMemory))
                .font(Theme.pixel(17, relativeTo: .headline))
                .foregroundColor(Theme.text)
            Text(L("Слово «в памяти», если вы помните его хотя бы неделю."))
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tower-card")
    }

    // MARK: План

    @ViewBuilder
    private func planCard(_ plan: AppModel.DailyPlan) -> some View {
        if !plan.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GothicHeader(L("План на сегодня"))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(plan.total)")
                        .font(Theme.pixel(44, relativeTo: .largeTitle))
                        .foregroundColor(Theme.text)
                    Text(Plural.words(plan.total))
                        .font(Theme.pixel(20, relativeTo: .title3))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text(L("~%d мин", model.estimatedMinutes(questions: plan.total)))
                        .font(Theme.pixel(20, relativeTo: .title3))
                        .foregroundColor(Theme.textDim)
                }
                HStack(spacing: 16) {
                    planChip(value: plan.dueIDs.count, title: L("повторить"), color: Theme.gold)
                    planChip(value: plan.newIDs.count, title: L("новых"), color: Theme.bloodBright)
                }
                Button {
                    active = .daily
                } label: {
                    Text(plan.reviewedToday > 0 ? L("Продолжить") : L("Начать"))
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
                        Label(L("На сегодня всё"), systemImage: "checkmark.seal.fill")
                            .font(Theme.pixel(24, relativeTo: .title2))
                            .foregroundColor(Theme.moss)
                        Text(L("Сегодня пройдено: %d %@. Ещё раз проходить не нужно — приходите завтра.", plan.reviewedToday, Plural.words(plan.reviewedToday)))
                            .font(.subheadline)
                            .foregroundColor(Theme.text)
                    } else {
                        Label(L("Сегодня повторять нечего"), systemImage: "moon.stars.fill")
                            .font(Theme.pixel(20, relativeTo: .title3))
                            .foregroundColor(Theme.moss)
                        Text(plan.hasMoreNew
                             ? L("Все слова повторены вовремя.")
                             : L("Все слова повторены вовремя, а новых в коллекциях не осталось. Добавьте слова в коллекцию — они появятся здесь."))
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
                        Text(L("Ещё %d новых слов", model.settings.newWordsPerDay))
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
            GothicHeader(L("Повторения на неделю"))
            ForEach(0..<days.count, id: \.self) { i in
                HStack {
                    Text(dayTitle(offset: i + 1))
                        .foregroundColor(Theme.text)
                    Spacer()
                    if days[i] == 0 {
                        Text("—")
                            .foregroundColor(Theme.textDim)
                    } else {
                        Text(L("%d %@ · ≈ %d мин", days[i], Plural.words(days[i]), model.estimatedMinutes(questions: days[i])))
                            .foregroundColor(Theme.textDim)
                    }
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    // MARK: Глаголы

    private var verbsCard: some View {
        let vp = model.dailyVerbPlan()
        return VStack(alignment: .leading, spacing: 10) {
            GothicHeader(L("Глаголы на сегодня"))
            if vp.isEmpty {
                Label(L("Спряжения на сегодня повторены"), systemImage: "checkmark.seal.fill")
                    .font(Theme.pixel(16, relativeTo: .headline))
                    .foregroundColor(Theme.moss)
                    .accessibilityIdentifier("verbs-done")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(vp.total)")
                        .font(Theme.pixel(32, relativeTo: .title))
                        .foregroundColor(Theme.text)
                    Text(Plural.forms(vp.total))
                        .font(Theme.pixel(18, relativeTo: .title3))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text(L("~%d мин", model.estimatedMinutes(questions: vp.total)))
                        .font(Theme.pixel(18, relativeTo: .title3))
                        .foregroundColor(Theme.textDim)
                }
                HStack(spacing: 16) {
                    planChip(value: vp.due.count, title: L("повторить"), color: Theme.gold)
                    planChip(value: vp.new.count, title: L("новых"), color: Theme.bloodBright)
                }
                Text(vp.new.map { "\($0.verb.inf) — \($0.tense.name)" }.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
                    .lineLimit(2)
                Button {
                    active = .verbs
                } label: {
                    Text(L("Спрягать"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.secondary))
                .accessibilityIdentifier("verbs-start")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    // MARK: Фразы

    private var phrasesCard: some View {
        let pp = model.dailyPhrasePlan()
        return VStack(alignment: .leading, spacing: 10) {
            GothicHeader(L("Фразы на сегодня"))
            if pp.isEmpty {
                Label(L("Фразы на сегодня повторены"), systemImage: "checkmark.seal.fill")
                    .font(Theme.pixel(16, relativeTo: .headline))
                    .foregroundColor(Theme.moss)
                    .accessibilityIdentifier("phrases-done")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(pp.total)")
                        .font(Theme.pixel(32, relativeTo: .title))
                        .foregroundColor(Theme.text)
                    Text(Plural.phrases(pp.total))
                        .font(Theme.pixel(18, relativeTo: .title3))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text(L("~%d мин", model.estimatedMinutes(questions: pp.total * 2)))
                        .font(Theme.pixel(18, relativeTo: .title3))
                        .foregroundColor(Theme.textDim)
                }
                HStack(spacing: 16) {
                    planChip(value: pp.due.count, title: L("повторить"), color: Theme.gold)
                    planChip(value: pp.new.count, title: L("новых"), color: Theme.bloodBright)
                }
                Text((pp.new + pp.due).prefix(2).map { $0.title }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
                    .lineLimit(2)
                Button {
                    active = .phrases
                } label: {
                    Text(L("Говорить фразами"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GothicButtonStyle(.secondary))
                .accessibilityIdentifier("phrases-start")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    private func makeDailyPhraseQuestions() -> [PhraseQuestion] {
        let pp = model.dailyPhrasePlan()
        let due = pp.due.shuffled().map { PhraseQuestion.make(item: $0, typing: model.phraseTyping($0.id)) }
        let new = pp.new.map { PhraseQuestion.make(item: $0, typing: false) }
        return new + due
    }

    // MARK: Босс недели

    private var bossCard: some View {
        let b = model.bossOfWeek
        let defeated = model.bossDefeatedThisWeek
        return HStack(alignment: .top, spacing: 12) {
            Image("pet_boss_\(b.key)0")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .padding(6)
                .background(PixelFrame(fill: Color.black))
                .opacity(defeated ? 0.45 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                GothicHeader(L("Босс недели"))
                Text(b.title)
                    .font(Theme.pixel(18, relativeTo: .headline))
                    .foregroundColor(Theme.goldBright)
                Text(defeated
                     ? L("Повержен! Новый босс появится в понедельник.")
                     : L("Бой со словами, которые вы повторяли на этой неделе. Ошибётесь %d раза — маг выбьется из сил.", model.bossConfig().hearts))
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !defeated {
                    Button {
                        active = .boss
                    } label: {
                        Text(L("Бросить вызов"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GothicButtonStyle(.primary))
                    .accessibilityIdentifier("boss-start")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    // MARK: Ссылки

    private var linksCard: some View {
        let count = model.difficultWords.count
        let spells = model.wordsInMemory()
        return VStack(spacing: 0) {
            NavigationLink {
                GrimoireView()
            } label: {
                linkRow(icon: "book.closed", title: L("Гримуар"), value: spells > 0 ? "\(spells) \(Plural.spells(spells))" : L("пока пуст"))
            }
            .accessibilityIdentifier("open-grimoire")
            Rectangle().fill(Theme.goldDark).frame(height: 1).padding(.horizontal, 8)
            // Сколько времени проведено в приложении; пока экран открыт, обновляется раз в 30 секунд
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                statRow(icon: "hourglass", title: L("Время в приложении"),
                        value: AppModel.durationText(model.totalTimeInApp))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("time-in-app")
            Rectangle().fill(Theme.goldDark).frame(height: 1).padding(.horizontal, 8)
            NavigationLink {
                PhrasesView()
            } label: {
                linkRow(icon: "text.bubble", title: L("Фразы"), value: "\(model.phrases.allItems.count)")
            }
            .accessibilityIdentifier("open-phrases")
            Rectangle().fill(Theme.goldDark).frame(height: 1).padding(.horizontal, 8)
            NavigationLink {
                DifficultWordsView()
            } label: {
                linkRow(icon: "flame", title: L("Трудные слова"), value: count > 0 ? "\(count)" : L("пока нет"))
            }
            .accessibilityIdentifier("open-difficult")
        }
        .pixelPanel(padding: 6)
    }

    /// Строка со значением, но без перехода (без стрелки).
    private func statRow(icon: String, title: String, value: String) -> some View {
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Theme.gold)
                .frame(width: 24)
            Text(title)
                .foregroundColor(Theme.text)
            Spacer()
            Text(value)
                .foregroundColor(Theme.goldBright)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
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
            EmptyHint(title: L("Добавьте слова, чтобы начать"),
                      message: L("Возьмите готовый набор или сохраните слова из словаря в коллекцию — и здесь появится план на каждый день. Новые слова берутся из коллекций по порядку — до %d в день.", model.settings.newWordsPerDay))
            if !model.index.levels.isEmpty {
                NavigationLink {
                    LevelsView()
                } label: {
                    linkRow(icon: "chart.bar", title: L("Наборы по уровням (A1, A2…)"), value: "")
                }
            }
            NavigationLink {
                TopicsView()
            } label: {
                linkRow(icon: "square.grid.2x2", title: L("Наборы слов по темам"), value: "")
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

    private func makeBossQuestions(count: Int) -> [WordQuestion] {
        let words = model.bossWords(limit: count)
        let builder = ExerciseBuilder(index: model.index, settings: model.settings)
        return builder.makeDailyQuestions(dueWords: words, newWords: [], states: model.user.srs,
                                          pool: collectionPool() + words)
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
                    EmptyHint(title: L("Трудных слов пока нет"),
                              message: L("Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше."))
                }
            } else {
                Section(header: GothicHeader(L("Учить")),
                        footer: Text(L("Сюда сами попадают слова, в которых вы ошиблись 2 раза и больше. Слово уходит из списка, когда становится «выученным»."))) {
                    ForEach(ExerciseLevel.allCases) { level in
                        Button {
                            activeLevel = level
                        } label: {
                            LevelRow(level: level, best: nil)
                        }
                    }
                }
                Section(header: GothicHeader(L("Слова (%d)", words.count))) {
                    ForEach(words) { w in
                        NavigationLink {
                            WordCardView(word: w)
                        } label: {
                            HStack {
                                WordRow(word: w, showStatus: false)
                                Text(L("ошибок: %d", model.progress(for: w.id).wrong))
                                    .font(.caption)
                                    .foregroundColor(Theme.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L("Трудные слова"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeLevel) { level in
            StudySessionView(level: level, title: L("Трудные слова"), collectionID: nil, generator: {
                let words = model.difficultWords
                let builder = ExerciseBuilder(index: model.index, settings: model.settings)
                return builder.makeQuestions(words: words, level: level, count: model.settings.sessionSize)
            })
        }
    }
}
