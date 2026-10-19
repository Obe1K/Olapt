import SwiftUI
import PhotosUI
import UIKit

/// Черновик своего слова, которого нет в словаре.
struct UnknownDraft: Identifiable {
    let id = UUID()
    var pt: String
    var translation: String = ""
}

/// «Слова из фото»: фото, скриншот или вставленный текст → слова-кнопки → выбранные слова в коллекцию.
struct PhotoWordsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Коллекция, в которую добавляем. nil — выбрать или создать на экране результата.
    let collectionID: UUID?

    private enum Stage: Equatable {
        case pick
        case working
        case result
        case failed(String)
    }

    @State private var stage: Stage = .pick
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPaste = false
    @State private var tokens: [ScanToken] = []
    @State private var selected: Set<String> = []
    @State private var target: UUID?
    @State private var newName = ""
    @State private var showUnknown = false
    @State private var unknownDrafts: [UnknownDraft] = []
    @State private var pendingKnown: [String] = []
    @State private var doneMessage: String?
    @State private var cardWord: Word?
    @State private var dictionaryTerm: IdentifiedTerm?

    private var isUITestSample: Bool {
        return ProcessInfo.processInfo.arguments.contains("-uitest-scan-sample")
    }

    /// Коллекция, куда сейчас попадут слова (для отметки «уже в коллекции»).
    private var destinationID: UUID? {
        if let fixed = collectionID { return fixed }
        if let t = target, model.collection(t) != nil { return t }
        return nil
    }

    private var defaultNewName: String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return "Из фото " + f.string(from: Date())
    }

    /// Язык, на котором просим перевод своих слов.
    private var translationLanguage: String {
        let langs = model.index.languages
        let pref = model.settings.exerciseLanguage
        if langs.contains(pref) { return pref }
        if langs.contains("ru") { return "ru" }
        return langs.first ?? "ru"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick:
                    pickView
                case .working:
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Распознаю текст…")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .result:
                    resultView
                case .failed(let message):
                    VStack(spacing: 16) {
                        EmptyHint(title: "Не получилось", message: message)
                        Button("Попробовать снова") { stage = .pick }
                            .buttonStyle(GothicButtonStyle(.primary))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Слова из фото")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                if stage == .result {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Другой текст") { reset() }
                    }
                }
            }
        }
        .onChange(of: pickerItem) { item in
            guard let item = item else { return }
            stage = .working
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                pickerItem = nil
                if let data = data, let image = UIImage(data: data) {
                    process(image: image)
                } else {
                    stage = .failed("Не удалось открыть это изображение. Попробуйте другое.")
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                process(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaste) {
            PasteTextSheet { text in
                process(text: text)
            }
        }
        .sheet(isPresented: $showUnknown) {
            UnknownWordsSheet(drafts: $unknownDrafts,
                              languageName: Languages.name(translationLanguage),
                              onAdd: {
                                  showUnknown = false
                                  // Сообщение показываем после того, как лист закроется.
                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                      finishWithUnknown(skip: false)
                                  }
                              },
                              onSkip: {
                                  showUnknown = false
                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                      finishWithUnknown(skip: true)
                                  }
                              })
            .environmentObject(model)
        }
        .sheet(item: $cardWord) { w in
            NavigationStack {
                WordCardView(word: w)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") { cardWord = nil }
                        }
                    }
            }
            .environmentObject(model)
        }
        .sheet(item: $dictionaryTerm) { term in
            SystemDictionaryView(term: term.text)
        }
        .alert("Готово", isPresented: Binding(
            get: { doneMessage != nil },
            set: { if !$0 { doneMessage = nil } }
        )) {
            Button("Закрыть экран") { dismiss() }
            Button("Остаться", role: .cancel) {}
        } message: {
            Text(doneMessage ?? "")
        }
    }

    // MARK: - Выбор источника

    private var pickView: some View {
        GothicList {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Найдите слова в тексте")
                        .font(.headline)
                    Text("Сфотографируйте текст или выберите скриншот. Приложение распознает слова и подсветит те, что есть в словаре. Отметьте нужные — они попадут в коллекцию с переводами.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section(footer: Text("Текст распознаётся прямо на iPhone. Фото никуда не отправляется и не сохраняется.")) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Выбрать фото или скриншот", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Сфотографировать текст", systemImage: "camera")
                    }
                }
                Button {
                    showPaste = true
                } label: {
                    Label("Вставить текст", systemImage: "doc.on.clipboard")
                }
                if isUITestSample {
                    Button {
                        process(image: TextRecognizer.sampleImage())
                    } label: {
                        Label("Тестовое изображение", systemImage: "photo")
                    }
                    .accessibilityIdentifier("scan-sample")
                    Button {
                        process(text: "Ela tem tranças e franja. O penteado é oval.\nA casa é lindíssima. Sentei-me e oiço música.\nA acção decorre em Lisboa. Falámos ontem.\nestar com fome / ter fome\nEstamos com frio. Ela está cansada.")
                    } label: {
                        Label("Тестовый текст", systemImage: "text.alignleft")
                    }
                    .accessibilityIdentifier("scan-sample-text")
                }
            }
        }
    }

    // MARK: - Результат

    private var knownCount: Int {
        return Set(tokens.compactMap { $0.word?.id }).count
    }

    private var unknownCount: Int {
        return Set(tokens.filter { $0.word == nil }.map { $0.key }).count
    }

    @ViewBuilder
    private var resultView: some View {
        if tokens.isEmpty {
            VStack(spacing: 16) {
                EmptyHint(title: "Текст не найден",
                          message: "На изображении не удалось распознать слова. Попробуйте более чёткое фото или скриншот.")
                Button("Выбрать другое") { reset() }
                    .buttonStyle(GothicButtonStyle(.primary))
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Есть в словаре: \(knownCount) · нет в словаре: \(unknownCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("scan-summary")
                    HStack(spacing: 10) {
                        Button("Выбрать новые") { selectNew() }
                            .buttonStyle(GothicButtonStyle(.secondary))
                        Button("Снять выбор") { selected.removeAll() }
                            .buttonStyle(GothicButtonStyle(.secondary))
                            .disabled(selected.isEmpty)
                    }
                    FlowLayout(spacing: 6, lineSpacing: 8) {
                        ForEach(tokens) { t in
                            chip(t)
                        }
                    }
                    legend
                }
                .padding()
            }
            .background(StoneBackground().ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Золотистые — есть в словаре, серые — нет (их можно добавить со своим переводом). Отмеченные — красные. Под словом показана словарная форма. Нажмите, чтобы отметить; долгое нажатие — карточка слова или словарь iOS.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func chip(_ t: ScanToken) -> some View {
        let isSelected = selected.contains(t.key)
        let known = t.word != nil
        let inCollection = t.word.map { w in destinationID.map { model.isWord(w.id, in: $0) } ?? false } ?? false

        let background: Color
        let foreground: Color
        if isSelected {
            background = known ? Theme.blood : Color(red: 0.42, green: 0.24, blue: 0.08)
            foreground = Theme.text
        } else if inCollection {
            background = Theme.mossDark
            foreground = .primary
        } else if known {
            background = Theme.gold.opacity(0.16)
            foreground = .primary
        } else {
            background = Theme.panelRaised
            foreground = .secondary
        }

        return Button {
            toggle(t)
        } label: {
            VStack(spacing: 1) {
                Text(t.text)
                    .font(.body)
                if let lemma = t.lemma {
                    Text(lemma)
                        .font(.caption2)
                        .foregroundColor(isSelected ? Theme.text.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundColor(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if inCollection && !isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(Theme.moss)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let w = t.word {
                Button {
                    cardWord = w
                } label: {
                    Label("Карточка слова", systemImage: "text.book.closed")
                }
            }
            Button {
                Speaker.shared.speak(t.word?.pt ?? t.text)
            } label: {
                Label("Произнести", systemImage: "speaker.wave.2")
            }
            Button {
                dictionaryTerm = IdentifiedTerm(text: t.word?.pt ?? t.text)
            } label: {
                Label("Словарь iOS", systemImage: "character.book.closed")
            }
        }
        .accessibilityLabel(accessibilityText(t, selected: isSelected, inCollection: inCollection))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("scan-chip-" + t.text)
    }

    private func accessibilityText(_ t: ScanToken, selected: Bool, inCollection: Bool) -> String {
        var parts = [t.text]
        if let lemma = t.lemma { parts.append("словарная форма " + lemma) }
        if let w = t.word {
            let tr = w.translationText(lang: translationLanguage, limit: 2)
            if !tr.isEmpty { parts.append(tr) }
        } else {
            parts.append("нет в словаре")
        }
        if inCollection { parts.append("уже в коллекции") }
        if selected { parts.append("отмечено") }
        return parts.joined(separator: ", ")
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if collectionID == nil {
                HStack {
                    Text("В коллекцию:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Коллекция", selection: $target) {
                        Text("Новая коллекция").tag(UUID?.none)
                        ForEach(model.user.collections) { c in
                            Text(c.name).tag(UUID?.some(c.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                if target == nil {
                    TextField(defaultNewName, text: $newName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Button {
                addSelected()
            } label: {
                Text(selected.isEmpty ? "Отметьте слова" : "Добавить: \(selected.count) \(Plural.words(selected.count))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GothicButtonStyle(.primary))
            .controlSize(.large)
            .disabled(selected.isEmpty)
            .accessibilityIdentifier("scan-add")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.background.opacity(0.95))
    }

    // MARK: - Действия

    private func reset() {
        tokens = []
        selected = []
        stage = .pick
    }

    private func process(image: UIImage) {
        stage = .working
        Task {
            do {
                let lines = try await TextRecognizer.recognize(image)
                show(lines: lines)
            } catch {
                stage = .failed("Не удалось распознать текст: \(error.localizedDescription)")
            }
        }
    }

    private func process(text: String) {
        let lines = text.components(separatedBy: .newlines)
        show(lines: lines)
    }

    private func show(lines: [String]) {
        tokens = TextScanner.tokens(from: lines, index: model.index)
        selected = []
        stage = .result
    }

    private func toggle(_ t: ScanToken) {
        if selected.contains(t.key) {
            selected.remove(t.key)
        } else {
            selected.insert(t.key)
        }
    }

    /// Отмечает знаменательные слова из словаря, которые ещё не начаты и не лежат в коллекции.
    private func selectNew() {
        for t in tokens {
            guard let w = t.word else { continue }
            if TextScanner.functionPOS.contains(w.pos) { continue }
            if let dest = destinationID, model.isWord(w.id, in: dest) { continue }
            if model.status(for: w.id) != .new { continue }
            selected.insert(t.key)
        }
    }

    private func addSelected() {
        var known: [String] = []
        var unknown: [String] = []
        var seenUnknown = Set<String>()
        for t in tokens where selected.contains(t.key) {
            if let w = t.word {
                if !known.contains(w.id) { known.append(w.id) }
            } else {
                let key = TextUtil.fold(t.text)
                if !seenUnknown.contains(key) {
                    seenUnknown.insert(key)
                    unknown.append(t.text.lowercased())
                }
            }
        }
        if unknown.isEmpty {
            finish(ids: known, skipped: 0)
        } else {
            pendingKnown = known
            unknownDrafts = unknown.map { UnknownDraft(pt: $0) }
            showUnknown = true
        }
    }

    private func finishWithUnknown(skip: Bool) {
        var ids = pendingKnown
        var skipped = unknownDrafts.count
        if !skip {
            let items = unknownDrafts
                .filter { !$0.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { (pt: $0.pt, translations: [translationLanguage: [$0.translation]]) }
            let added = model.addCustomWords(items)
            ids.append(contentsOf: added)
            skipped = unknownDrafts.count - added.count
        }
        pendingKnown = []
        unknownDrafts = []
        finish(ids: ids, skipped: skipped)
    }

    private func finish(ids: [String], skipped: Int) {
        let destID: UUID
        if let d = destinationID {
            destID = d
        } else {
            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            destID = model.createCollection(name: name.isEmpty ? defaultNewName : name).id
            target = destID
        }
        let before = model.collection(destID)?.wordIDs.count ?? 0
        model.add(wordIDs: ids, to: destID)
        let after = model.collection(destID)?.wordIDs.count ?? 0
        let added = after - before
        let name = model.collection(destID)?.name ?? ""
        var message = "Добавлено \(added) \(Plural.words(added)) в коллекцию «\(name)»."
        let already = ids.count - added
        if already > 0 { message += " Уже были в коллекции: \(already)." }
        if skipped > 0 { message += " Без перевода не добавлены: \(skipped)." }
        selected.removeAll()
        doneMessage = message
    }
}

// MARK: - Вставка текста

struct PasteTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onDone: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Вставьте или наберите текст на португальском.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                PasteButton(payloadType: String.self) { strings in
                    let pasted = strings.joined(separator: "\n")
                    DispatchQueue.main.async {
                        text = pasted
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Текст")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Найти слова") {
                        let value = text
                        dismiss()
                        onDone(value)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Слова, которых нет в словаре

struct UnknownWordsSheet: View {
    @Binding var drafts: [UnknownDraft]
    let languageName: String
    let onAdd: () -> Void
    let onSkip: () -> Void
    @State private var lookup: IdentifiedTerm?

    var body: some View {
        NavigationStack {
            GothicList {
                Section(footer: Text("Слова без перевода не добавятся. Перевод можно подсмотреть в словаре iOS (кнопка с книгой).")) {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Слово", text: $draft.pt)
                                    .font(.headline)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                Button {
                                    lookup = IdentifiedTerm(text: draft.pt)
                                } label: {
                                    Image(systemName: "character.book.closed")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Словарь iOS")
                            }
                            TextField("Перевод (\(languageName.lowercased()))", text: $draft.translation)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Нет в словаре")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Пропустить") { onSkip() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { onAdd() }
                }
            }
            .sheet(item: $lookup) { term in
                SystemDictionaryView(term: term.text)
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Склонение «слово»

enum Plural {
    /// 1 форма, 2 формы, 5 форм
    static func forms(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "форм" }
        if mod10 == 1 { return "форма" }
        if mod10 >= 2 && mod10 <= 4 { return "формы" }
        return "форм"
    }

    /// 1 фраза, 2 фразы, 5 фраз
    static func phrases(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "фраз" }
        if mod10 == 1 { return "фраза" }
        if mod10 >= 2 && mod10 <= 4 { return "фразы" }
        return "фраз"
    }

    /// 1 заклинание, 2 заклинания, 5 заклинаний
    static func spells(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "заклинаний" }
        if mod10 == 1 { return "заклинание" }
        if mod10 >= 2 && mod10 <= 4 { return "заклинания" }
        return "заклинаний"
    }

    /// 1 неделя, 2 недели, 5 недель
    static func weeks(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "недель" }
        if mod10 == 1 { return "неделя" }
        if mod10 >= 2 && mod10 <= 4 { return "недели" }
        return "недель"
    }

    /// 1 месяц, 2 месяца, 5 месяцев
    static func months(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "месяцев" }
        if mod10 == 1 { return "месяц" }
        if mod10 >= 2 && mod10 <= 4 { return "месяца" }
        return "месяцев"
    }

    /// 1 день, 2 дня, 5 дней
    static func days(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        if mod10 == 1 { return "день" }
        if mod10 >= 2 && mod10 <= 4 { return "дня" }
        return "дней"
    }

    /// 1 слово, 2 слова, 5 слов
    static func words(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "слов" }
        if mod10 == 1 { return "слово" }
        if mod10 >= 2 && mod10 <= 4 { return "слова" }
        return "слов"
    }
}
