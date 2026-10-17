import SwiftUI

// MARK: - Карточка слова

struct WordCardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let word: Word

    @State private var showPicker = false
    @State private var confirmDelete = false

    private var verb: Verb? {
        if !word.isVerb { return nil }
        return model.verbs.verb(forWordID: word.id)
    }

    var body: some View {
        List {
            headerSection

            ForEach(model.index.languages, id: \.self) { lang in
                if word.hasTranslation(lang: lang) {
                    Section(header: Text(Languages.name(lang))) {
                        ForEach(word.tr(lang), id: \.self) { t in
                            Text(t)
                        }
                    }
                }
            }

            if !word.brazilian.isEmpty {
                Section(header: Text("В Бразилии говорят")) {
                    Text(word.brazilian)
                }
            }

            if !word.note.isEmpty {
                Section(header: Text("Заметка")) {
                    Text(word.note)
                        .font(.subheadline)
                }
            }

            if let verb = verb {
                Section {
                    NavigationLink {
                        ConjugationView(verb: verb)
                    } label: {
                        Label("Спряжение глагола", systemImage: "tablecells")
                    }
                }
            }

            progressSection

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Сохранить в коллекцию", systemImage: "plus.rectangle.on.folder")
                }
            }

            if word.isCustom {
                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Удалить своё слово", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(word.pt)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CollectionPickerSheet(wordIDs: [word.id])
        }
        .confirmationDialog("Удалить слово «\(word.pt)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                model.deleteCustomWord(wordID: word.id)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear {
            if model.settings.autoSpeak {
                Speaker.shared.speak(word.pt)
            }
        }
    }

    // MARK: Шапка

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(word.titleWithArticle)
                        .font(.largeTitle.weight(.bold))
                        .minimumScaleFactor(0.6)
                    Spacer()
                    SpeakButton(text: word.pt)
                }
                if !word.posLine.isEmpty {
                    Text(word.posLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if !word.feminine.isEmpty && word.feminine != word.pt {
                    Text("женский род: \(word.feminine)")
                        .font(.subheadline)
                }
                if !word.plural.isEmpty {
                    Text("мн. число: \(word.plural)")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Прогресс

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    /// «сегодня», «завтра», «через 5 дней (23 октября)»
    private func whenText(_ due: Date) -> String {
        let d = FSRS.days(from: Date(), to: due)
        if d <= 0 { return "сегодня" }
        if d == 1 { return "завтра" }
        if d == 2 { return "послезавтра" }
        return "через \(d) \(Plural.days(d)) (\(WordCardView.dateFormatter.string(from: due)))"
    }

    /// «4 дня», «2 недели», «3 месяца»
    private func spanText(_ stability: Double) -> String {
        let days = FSRS.intervalDays(stability: stability)
        if days < 14 { return "\(days) \(Plural.days(days))" }
        if days < 60 {
            let w = Int((Double(days) / 7).rounded())
            return "\(w) \(Plural.weeks(w))"
        }
        let m = Int((Double(days) / 30).rounded())
        return "\(m) \(Plural.months(m))"
    }

    private var progressSection: some View {
        let p = model.progress(for: word.id)
        let status = model.status(for: word.id)
        let state = model.srsState(for: word.id)
        return Section(header: Text("Прогресс"),
                       footer: Text("«Выучено» — когда слово держится в памяти 3 недели и дольше.")) {
            HStack {
                StatusBadge(status: status)
                Spacer()
                if let s = state {
                    Text("помню ≈ \(spanText(s.stability))")
                        .foregroundColor(.secondary)
                }
            }
            MasteryBar(fraction: model.fraction(for: word.id))
            if let s = state {
                Text("Следующее повторение: \(whenText(s.due))")
                    .font(.subheadline)
            }
            if p.attempts > 0 {
                Text("Верных ответов: \(p.correct) · ошибок: \(p.wrong)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if state == nil {
                Text(model.user.collections.contains { $0.wordIDs.contains(word.id) }
                     ? "Слово появится в плане «Сегодня», когда до него дойдёт очередь новых слов."
                     : "Добавьте слово в коллекцию — оно появится в плане «Сегодня».")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Выбор коллекции

struct CollectionPickerSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let wordIDs: [String]
    @State private var newName = ""

    private func containsAll(_ c: WordCollection) -> Bool {
        if wordIDs.isEmpty { return false }
        for id in wordIDs where !c.wordIDs.contains(id) {
            return false
        }
        return true
    }

    private func toggle(_ c: WordCollection) {
        if containsAll(c) {
            for id in wordIDs {
                model.remove(wordID: id, from: c.id)
            }
        } else {
            model.add(wordIDs: wordIDs, to: c.id)
        }
    }

    private func createAndAdd() {
        model.createCollection(name: newName, wordIDs: wordIDs)
        newName = ""
        dismiss()
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Мои коллекции")) {
                    if model.user.collections.isEmpty {
                        Text("Коллекций пока нет. Создайте первую ниже.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(model.user.collections) { c in
                        Button {
                            toggle(c)
                        } label: {
                            HStack {
                                Text(c.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(c.wordIDs.count)")
                                    .foregroundColor(.secondary)
                                if containsAll(c) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Новая коллекция")) {
                    TextField("Название", text: $newName)
                    Button("Создать и добавить") {
                        createAndAdd()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("В коллекцию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
