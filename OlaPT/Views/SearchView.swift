import SwiftUI

// MARK: - Поиск по словарю

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var showEditor = false

    private var trimmedQuery: String {
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [SearchResult] {
        return model.index.search(query)
    }

    var body: some View {
        List {
            if let error = model.bundleError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
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
    }

    // MARK: Секции

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Введите слово")
                    .font(.headline)
                Text("Можно искать по-португальски, по-русски или по-английски. Работает и поиск по формам глаголов: например, «falámos» найдёт глагол falar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var topicsSection: some View {
        Section(header: Text("Обзор по темам")) {
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
            Section {
                EmptyHint(title: "Ничего не найдено",
                          message: "Проверьте написание или добавьте слово в свой словарь.")
                Button {
                    showEditor = true
                } label: {
                    Label("Добавить «\(trimmedQuery)» как своё слово", systemImage: "plus.circle")
                }
            }
        } else {
            Section(header: Text("Найдено: \(found.count)")) {
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
                    showEditor = true
                } label: {
                    Label("Нет нужного слова? Добавить своё", systemImage: "plus.circle")
                }
            }
        }
    }
}

// MARK: - Список тем

struct TopicsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List {
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
        List {
            Section {
                Button {
                    let created = model.createCollection(name: topic.name, wordIDs: words.map { $0.id })
                    createdMessage = "Коллекция «\(created.name)» создана: \(created.wordIDs.count) слов. Найдите её на вкладке «Коллекции»."
                } label: {
                    Label("Создать коллекцию из набора", systemImage: "rectangle.stack.badge.plus")
                }
            }
            Section(header: Text("Слова (\(words.count))")) {
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
            Form {
                Section(header: Text("Слово по-португальски")) {
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
                Section(header: Text("Переводы"), footer: Text("Несколько переводов разделяйте запятой.")) {
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
