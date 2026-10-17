import SwiftUI

// MARK: - Поиск по словарю

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var showEditor = false
    @State private var dictionaryTerm: IdentifiedTerm?

    private var trimmedQuery: String {
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [SearchResult] {
        return model.index.search(query)
    }

    var body: some View {
        GothicList {
            if let error = model.bundleError {
                Section {
                    Text(error)
                        .foregroundColor(Theme.red)
                }
            }

            if trimmedQuery.isEmpty {
                introSection
                topicsSection
            } else {
                resultsSection
            }
        }
        .navigationTitle("Словарь")
        .searchable(text: $query, prompt: "По-португальски, по-русски или по-английски")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .sheet(isPresented: $showEditor) {
            CustomWordEditor(prefill: trimmedQuery)
        }
        .sheet(item: $dictionaryTerm) { term in
            SystemDictionaryView(term: term.text)
        }
    }

    // MARK: Секции

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Olá PT")
                    .font(Theme.gothic(44))
                    .foregroundColor(Theme.goldBright)
                    .shadow(color: Theme.blood, radius: 0, x: 2, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
                Text("Введите слово")
                    .font(Theme.pixel(17, relativeTo: .headline))
                    .foregroundColor(Theme.goldBright)
                Text("Можно искать по-португальски, по-русски или по-английски. Работает и поиск по формам глаголов: например, «falámos» найдёт глагол falar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var topicsSection: some View {
        if !model.index.levels.isEmpty {
            Section(header: GothicHeader("Обзор по уровням")) {
                ForEach(model.index.levels, id: \.self) { level in
                    NavigationLink {
                        LevelTopicsView(level: level)
                    } label: {
                        HStack {
                            Text(Levels.title(level))
                            Spacer()
                            Text("\(model.index.words(inLevel: level).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        Section(header: GothicHeader("Обзор по темам")) {
            ForEach(model.index.topics) { topic in
                NavigationLink {
                    TopicWordsView(topic: topic)
                } label: {
                    HStack {
                        Text(topic.name)
                        Spacer()
                        Text("\(model.index.words(inTopic: topic.id).count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        let found = results
        if found.isEmpty {
            Section(footer: Text("Словарь iOS работает без интернета, если он загружен: при первом открытии нажмите «Управлять» и скачайте, например, «Português — English».")) {
                EmptyHint(title: "Ничего не найдено",
                          message: "Проверьте написание, посмотрите слово в словаре iOS или добавьте его в свой словарь.")
                Button {
                    dictionaryTerm = IdentifiedTerm(text: trimmedQuery)
                } label: {
                    Label("Посмотреть «\(trimmedQuery)» в словаре iOS", systemImage: "character.book.closed")
                }
                Button {
                    showEditor = true
                } label: {
                    Label("Добавить «\(trimmedQuery)» как своё слово", systemImage: "plus.circle")
                }
            }
        } else {
            Section(header: GothicHeader("Найдено: \(found.count)")) {
                ForEach(found) { result in
                    NavigationLink {
                        WordCardView(word: result.word)
                    } label: {
                        WordRow(word: result.word, hint: result.hint)
                    }
                }
            }
            Section {
                Button {
                    dictionaryTerm = IdentifiedTerm(text: trimmedQuery)
                } label: {
                    Label("Посмотреть в словаре iOS", systemImage: "character.book.closed")
                }
                Button {
                    showEditor = true
                } label: {
                    Label("Нет нужного слова? Добавить своё", systemImage: "plus.circle")
                }
            }
        }
    }
}

// MARK: - Наборы по уровням

enum Levels {
    static func title(_ level: String) -> String {
        switch level {
        case "A1": return "A1 — начальный"
        case "A2": return "A2 — элементарный"
        case "B1": return "B1 — средний"
        case "B2": return "B2 — выше среднего"
        default: return level
        }
    }
}

struct LevelsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        GothicList {
            Section(footer: Text("Уровни по шкале CEFR. Откройте уровень и выберите тему, чтобы создать коллекцию поменьше, или возьмите все слова уровня сразу.")) {
                ForEach(model.index.levels, id: \.self) { level in
                    NavigationLink {
                        LevelTopicsView(level: level)
                    } label: {
                        HStack {
                            Text(Levels.title(level))
                            Spacer()
                            Text("\(model.index.words(inLevel: level).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("По уровням")
    }
}

struct LevelTopicsView: View {
    @EnvironmentObject var model: AppModel
    let level: String

    var body: some View {
        let groups = model.index.topics(inLevel: level)
        let all = model.index.words(inLevel: level)
        GothicList {
            Section {
                NavigationLink {
                    WordSetView(title: "Уровень \(level)", collectionName: "Уровень \(level)", words: all)
                } label: {
                    HStack {
                        Text("Все слова уровня")
                        Spacer()
                        Text("\(all.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section(header: GothicHeader("По темам")) {
                ForEach(groups, id: \.topic.id) { g in
                    NavigationLink {
                        WordSetView(title: "\(level) · \(g.topic.name)",
                                    collectionName: "\(level) · \(g.topic.name)",
                                    words: g.words)
                    } label: {
                        HStack {
                            Text(g.topic.name)
                            Spacer()
                            Text("\(g.words.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(Levels.title(level))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Набор слов с кнопкой «Создать коллекцию».
struct WordSetView: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let collectionName: String
    let words: [Word]
    @State private var createdMessage: String?

    var body: some View {
        GothicList {
            Section {
                Button {
                    let created = model.createCollection(name: collectionName, wordIDs: words.map { $0.id })
                    createdMessage = "Коллекция «\(created.name)» создана: \(created.wordIDs.count) \(Plural.words(created.wordIDs.count)). Найдите её на вкладке «Коллекции»."
                } label: {
                    Label("Создать коллекцию из набора", systemImage: "rectangle.stack.badge.plus")
                }
            }
            Section(header: GothicHeader("Слова (\(words.count))")) {
                ForEach(words) { w in
                    NavigationLink {
                        WordCardView(word: w)
                    } label: {
                        WordRow(word: w)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Готово", isPresented: Binding(
            get: { createdMessage != nil },
            set: { if !$0 { createdMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(createdMessage ?? "")
        }
    }
}

// MARK: - Список тем

struct TopicsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        GothicList {
            Section(footer: Text("Откройте набор и нажмите «Создать коллекцию», чтобы начать учить слова из него.")) {
                ForEach(model.index.topics) { topic in
                    NavigationLink {
                        TopicWordsView(topic: topic)
                    } label: {
                        HStack {
                            Text(topic.name)
                            Spacer()
                            Text("\(model.index.words(inTopic: topic.id).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Готовые наборы")
    }
}

struct TopicWordsView: View {
    @EnvironmentObject var model: AppModel
    let topic: TopicInfo
    @State private var createdMessage: String?

    private var words: [Word] {
        return model.index.words(inTopic: topic.id)
    }

    var body: some View {
        GothicList {
            Section {
                Button {
                    let created = model.createCollection(name: topic.name, wordIDs: words.map { $0.id })
                    createdMessage = "Коллекция «\(created.name)» создана: \(created.wordIDs.count) слов. Найдите её на вкладке «Коллекции»."
                } label: {
                    Label("Создать коллекцию из набора", systemImage: "rectangle.stack.badge.plus")
                }
            }
            Section(header: GothicHeader("Слова (\(words.count))")) {
                ForEach(words) { w in
                    NavigationLink {
                        WordCardView(word: w)
                    } label: {
                        WordRow(word: w)
                    }
                }
            }
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Готово", isPresented: Binding(
            get: { createdMessage != nil },
            set: { if !$0 { createdMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(createdMessage ?? "")
        }
    }
}

// MARK: - Добавление своего слова

struct CustomWordEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let prefill: String
    @State private var pt = ""
    @State private var pos = "n"
    @State private var gender = "m"
    @State private var translationTexts: [String: String] = [:]
    @State private var didSetup = false

    private var canSave: Bool {
        if pt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        for (_, text) in translationTexts {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            GothicForm {
                Section(header: GothicHeader("Слово по-португальски")) {
                    TextField("Например, saudade", text: $pt)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Picker("Часть речи", selection: $pos) {
                        ForEach(PartOfSpeech.choices, id: \.self) { p in
                            Text(PartOfSpeech.label(p)).tag(p)
                        }
                    }
                    if pos == "n" {
                        Picker("Род", selection: $gender) {
                            Text("м. р. (o)").tag("m")
                            Text("ж. р. (a)").tag("f")
                            Text("м./ж. р.").tag("mf")
                        }
                    }
                }
                Section(header: GothicHeader("Переводы"), footer: Text("Несколько переводов разделяйте запятой.")) {
                    ForEach(model.index.languages, id: \.self) { lang in
                        TextField(Languages.name(lang), text: bindingFor(lang))
                            .autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle("Новое слово")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if !didSetup {
                    pt = prefill
                    didSetup = true
                }
            }
        }
    }

    private func bindingFor(_ lang: String) -> Binding<String> {
        return Binding(
            get: { translationTexts[lang] ?? "" },
            set: { translationTexts[lang] = $0 }
        )
    }

    private func save() {
        var result: [String: [String]] = [:]
        for (lang, text) in translationTexts {
            let items = text.split(separator: ",").map { String($0) }
            result[lang] = items
        }
        let g = pos == "n" ? gender : ""
        model.addCustomWord(pt: pt, pos: pos, gender: g, translations: result)
        dismiss()
    }
}
