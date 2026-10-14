import SwiftUI

// MARK: - Список коллекций

struct CollectionsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        List {
            if !model.user.progress.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Выучено слов: \(model.totalLearnedWords)")
                            .font(.headline)
                    }
                }
            }

            Section(header: Text("Мои коллекции")) {
                if model.user.collections.isEmpty {
                    EmptyHint(title: "Пока пусто",
                              message: "Найдите слово в словаре и сохраните его в коллекцию. Либо начните с готового набора по теме ниже.")
                }
                ForEach(model.user.collections) { c in
                    NavigationLink {
                        CollectionDetailView(collectionID: c.id)
                    } label: {
                        CollectionRow(collection: c)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.user.collections[$0].id }
                    for id in ids {
                        model.deleteCollection(id)
                    }
                }
            }

            Section(header: Text("Готовые наборы")) {
                NavigationLink {
                    TopicsView()
                } label: {
                    Label("Наборы слов по темам", systemImage: "square.grid.2x2")
                }
            }
        }
        .navigationTitle("Коллекции")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Новая коллекция")
            }
        }
        .alert("Новая коллекция", isPresented: $showNew) {
            TextField("Название", text: $newName)
            Button("Создать") {
                model.createCollection(name: newName)
                newName = ""
            }
            Button("Отмена", role: .cancel) {
                newName = ""
            }
        }
    }
}

struct CollectionRow: View {
    @EnvironmentObject var model: AppModel
    let collection: WordCollection

    var body: some View {
        let words = model.words(in: collection)
        let counts = model.counts(for: collection.wordIDs)
        VStack(alignment: .leading, spacing: 6) {
            Text(collection.name)
                .font(.headline)
            Text("\(words.count) слов · выучено \(counts.learned)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            MasteryBar(fraction: model.learnedFraction(of: collection.wordIDs))
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Одна коллекция

struct CollectionDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID

    @State private var showAdd = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var confirmDelete = false
    @State private var activeLevel: ExerciseLevel?

    var body: some View {
        Group {
            if let c = model.collection(collectionID) {
                content(c)
            } else {
                Text("Коллекция удалена")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func content(_ c: WordCollection) -> some View {
        let words = model.words(in: c)
        let counts = model.counts(for: c.wordIDs)
        let verbsInside = words.filter { $0.isVerb && model.verbs.verb(forWordID: $0.id) != nil }

        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        statBox(title: "Новые", value: counts.new, color: .gray)
                        statBox(title: "Учу", value: counts.learning, color: .orange)
                        statBox(title: "Выучено", value: counts.learned, color: .green)
                    }
                    MasteryBar(fraction: model.learnedFraction(of: c.wordIDs))
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("Учить"),
                    footer: Text("Каждый верный ответ приближает слово к статусу «выучено» (сейчас нужно \(model.settings.masteryThreshold) верных ответов). Ошибка снимает один балл.")) {
                ForEach(ExerciseLevel.allCases) { level in
                    Button {
                        activeLevel = level
                    } label: {
                        LevelRow(level: level, best: c.bestScores[String(level.rawValue)])
                    }
                    .disabled(words.isEmpty)
                }
            }

            if !verbsInside.isEmpty {
                Section(header: Text("Глаголы из коллекции")) {
                    NavigationLink {
                        VerbTrainerSetupView(initialCollectionID: c.id)
                    } label: {
                        Label("Тренировать спряжение (\(verbsInside.count))", systemImage: "textformat.abc")
                    }
                }
            }

            Section(header: Text("Слова (\(words.count))")) {
                if words.isEmpty {
                    EmptyHint(title: "В коллекции нет слов",
                              message: "Нажмите «Добавить слова» или сохраните слово из карточки словаря.")
                }
                ForEach(words) { w in
                    NavigationLink {
                        WordCardView(word: w)
                    } label: {
                        WordRow(word: w)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { words[$0].id }
                    for id in ids {
                        model.remove(wordID: id, from: c.id)
                    }
                }
                Button {
                    showAdd = true
                } label: {
                    Label("Добавить слова", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(c.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Добавить слова", systemImage: "plus")
                    }
                    Button {
                        renameText = c.name
                        showRename = true
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Удалить коллекцию", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWordsView(collectionID: c.id)
        }
        .alert("Переименовать", isPresented: $showRename) {
            TextField("Название", text: $renameText)
            Button("Сохранить") {
                model.renameCollection(c.id, to: renameText)
            }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog("Удалить коллекцию «\(c.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                model.deleteCollection(c.id)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Прогресс по самим словам сохранится.")
        }
        .fullScreenCover(item: $activeLevel) { level in
            StudySessionView(level: level, collectionID: c.id, generator: {
                let current = model.collection(c.id).map { model.words(in: $0) } ?? []
                let builder = ExerciseBuilder(index: model.index, settings: model.settings)
                return builder.makeQuestions(words: current, level: level, count: model.settings.sessionSize)
            })
        }
    }

    private func statBox(title: String, value: Int, color: Color) -> some View {
        return VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Добавление слов в коллекцию

struct AddWordsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID
    @State private var query = ""

    private var found: [SearchResult] {
        return model.index.search(query)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Введите слово, чтобы найти его и добавить в коллекцию. Нажатие добавляет или убирает слово.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if found.isEmpty {
                    Text("Ничего не найдено")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(found) { r in
                        Button {
                            toggle(r.word)
                        } label: {
                            HStack {
                                WordRow(word: r.word, hint: r.hint, showStatus: false)
                                Spacer()
                                Image(systemName: model.isWord(r.word.id, in: collectionID) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Добавить слова")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Найти слово")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ word: Word) {
        if model.isWord(word.id, in: collectionID) {
            model.remove(wordID: word.id, from: collectionID)
        } else {
            model.add(wordIDs: [word.id], to: collectionID)
        }
    }
}
