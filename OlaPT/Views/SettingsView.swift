import SwiftUI
import UniformTypeIdentifiers

// MARK: - Настройки

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmReset = false

    private func setting<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        return Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                var s = model.settings
                s[keyPath: keyPath] = newValue
                model.settings = s
            }
        )
    }

    private struct LanguageChoice: Identifiable {
        let code: String
        let title: String
        var id: String { return code }
    }

    private var languageChoices: [LanguageChoice] {
        var list: [LanguageChoice] = []
        for code in model.exerciseLanguages {
            list.append(LanguageChoice(code: code, title: Languages.name(code)))
        }
        if model.exerciseLanguages.count > 1 {
            list.append(LanguageChoice(code: "mixed", title: "Все языки вперемешку"))
        }
        return list
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return version + " (" + build + ")"
    }

    var body: some View {
        Form {
            Section(header: Text("Сегодня"),
                    footer: Text("Сколько новых слов из коллекций добавлять в план каждый день. Повторения добавляются сами в нужные дни. 10 новых в день — это около 10 минут занятий, когда наберутся повторения.")) {
                Picker("Новых слов в день", selection: setting(\.newWordsPerDay)) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("30").tag(30)
                }
            }

            Section(header: Text("Упражнения")) {
                Picker("Язык перевода", selection: setting(\.exerciseLanguage)) {
                    ForEach(languageChoices) { choice in
                        Text(choice.title).tag(choice.code)
                    }
                }
                Toggle("Строго учитывать ударения и ç, ã", isOn: setting(\.strictAccents))
                Picker("Слов в тренировке коллекции", selection: setting(\.sessionSize)) {
                    Text("Все слова").tag(0)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("30").tag(30)
                }
            }

            Section(header: Text("Глаголы"),
                    footer: Text("Для тренировки спряжения: сколько верных ответов нужно, чтобы время глагола считалось выученным.")) {
                Stepper(value: setting(\.masteryThreshold), in: 3...30) {
                    Text("«Выучено» после \(model.settings.masteryThreshold) верных")
                }
                Toggle("Ошибка снимает один балл", isOn: setting(\.wrongPenalty))
            }

            Section(header: Text("Озвучка"),
                    footer: Text(Speaker.shared.hasEuropeanVoice
                                 ? "Найден голос европейского португальского (pt-PT)."
                                 : "Голос европейского португальского не найден. Скачайте его: Настройки iPhone → Универсальный доступ → Устный контент → Голоса → Португальский (Португалия).")) {
                Toggle("Произносить слово при открытии карточки", isOn: setting(\.autoSpeak))
            }

            Section(header: Text("Словари")) {
                NavigationLink {
                    DictionariesView()
                } label: {
                    Label("Словари и импорт", systemImage: "books.vertical")
                }
            }

            Section(header: Text("Данные")) {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Label("Сбросить прогресс обучения", systemImage: "arrow.counterclockwise")
                }
            }

            Section(header: Text("О приложении")) {
                HStack {
                    Text("Версия")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                NavigationLink {
                    PrivacyInfoView()
                } label: {
                    Text("Конфиденциальность")
                }
                Text("Словари составлены для европейского португальского (pt-PT), орфография — по Acordo Ortográfico.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Настройки")
        .confirmationDialog("Сбросить весь прогресс?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Сбросить прогресс", role: .destructive) {
                model.resetProgress()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Коллекции и слова останутся, но все слова станут «новыми». Это действие нельзя отменить.")
        }
    }
}

// MARK: - Конфиденциальность

struct PrivacyInfoView: View {
    var body: some View {
        List {
            Section {
                Text("Приложение не собирает, не передаёт и не продаёт никакие данные. У него нет аккаунтов, рекламы и аналитики.")
                Text("Коллекции, прогресс и добавленные вами слова хранятся только на вашем устройстве. Если включено резервное копирование iCloud, они могут попасть в резервную копию устройства средствами iOS.")
                Text("Импортируемые словари читаются только из выбранных вами файлов и никуда не отправляются.")
                Text("Озвучка слов выполняется системным синтезатором речи прямо на устройстве.")
            }
        }
        .navigationTitle("Конфиденциальность")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Словари

struct DictionariesView: View {
    @EnvironmentObject var model: AppModel
    @State private var showImporter = false
    @State private var message: String?
    @State private var pendingText: String?
    @State private var pendingName = ""
    @State private var showCSVSheet = false

    var body: some View {
        List {
            Section(header: Text("Установленные словари"),
                    footer: Text("Отключённый словарь не участвует в поиске и упражнениях. Переводы из всех включённых словарей показываются на одной карточке слова.")) {
                ForEach(model.packs) { pack in
                    Toggle(isOn: Binding(
                        get: { model.isPackEnabled(pack.id) },
                        set: { model.setPack(pack.id, enabled: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name)
                            Text("\(pack.langName) · \(pack.entryCount) слов" + (pack.isBundled ? "" : " · добавлен вами"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .deleteDisabled(pack.isBundled)
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.packs[$0].id }
                    for id in ids {
                        model.deletePack(id)
                    }
                }
            }

            Section(header: Text("Добавить словарь")) {
                Button {
                    showImporter = true
                } label: {
                    Label("Импортировать файл…", systemImage: "square.and.arrow.down")
                }
                NavigationLink {
                    DictionaryFormatHelpView()
                } label: {
                    Label("Как составить свой словарь", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("Словари")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showCSVSheet) {
            CSVImportSheet(text: pendingText ?? "", defaultName: pendingName) { text in
                message = text
            }
        }
        .alert("Словари", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            message = "Не удалось открыть файл: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                if let pack = PackImporter.parseJSON(data) {
                    _ = try model.installPack(pack)
                    message = "Словарь «\(pack.name)» добавлен: \(pack.entries.count) слов."
                } else if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) {
                    pendingText = text
                    pendingName = url.deletingPathExtension().lastPathComponent
                    showCSVSheet = true
                } else {
                    message = PackImporter.ImportError.unreadable.localizedDescription
                }
            } catch {
                message = "Не удалось прочитать файл: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Импорт CSV

struct CSVImportSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let text: String
    let defaultName: String
    let onDone: (String) -> Void

    @State private var name = ""
    @State private var lang = "en"
    @State private var errorText: String?
    @State private var didSetup = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Название словаря")) {
                    TextField("Например, Португальский ↔ украинский", text: $name)
                }
                Section(header: Text("Язык переводов в файле")) {
                    Picker("Язык", selection: $lang) {
                        ForEach(Languages.importable, id: \.self) { code in
                            Text(Languages.name(code)).tag(code)
                        }
                    }
                }
                if let e = errorText {
                    Section {
                        Text(e)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Импорт файла")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Импорт") { runImport() }
                }
            }
            .onAppear {
                if !didSetup {
                    didSetup = true
                    name = defaultName
                }
            }
        }
    }

    private func runImport() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Мой словарь" : trimmed
        do {
            let pack = try PackImporter.parseCSV(text: text, name: finalName, lang: lang)
            _ = try model.installPack(pack)
            onDone("Словарь «\(finalName)» добавлен: \(pack.entries.count) слов.")
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Справка по формату

struct DictionaryFormatHelpView: View {
    private let csvExample = """
    casa; будинок | дім
    obrigado; дякую
    pequeno-almoço; сніданок
    """

    private let jsonExample = """
    {
      "id": "uk-pt-eu",
      "name": "Українська ↔ Португальська (Європа)",
      "lang": "uk",
      "entries": [
        { "pt": "casa", "pos": "n", "g": "f", "tr": ["будинок", "дім"] },
        { "pt": "falar", "pos": "v", "tr": ["говорити"] }
      ]
    }
    """

    var body: some View {
        List {
            Section(header: Text("Самый простой способ: CSV или TXT")) {
                Text("Текстовый файл в кодировке UTF-8. В каждой строке — португальское слово, затем точка с запятой (или табуляция) и перевод. Несколько переводов разделяйте знаком «|».")
                    .font(.subheadline)
                Text(csvExample)
                    .font(.system(.footnote, design: .monospaced))
                Text("При импорте приложение спросит название словаря и язык переводов. Переводы добавятся к тем же португальским словам, которые уже есть в приложении.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Расширенный формат: JSON")) {
                Text("Такой же файл, как у встроенных словарей. Можно указать часть речи (pos: n, v, adj, adv, phrase …), род (g: m, f, mf), женскую форму (f) и бразильский вариант (br).")
                    .font(.subheadline)
                Text(jsonExample)
                    .font(.system(.footnote, design: .monospaced))
            }

            Section(header: Text("Советы")) {
                Text("Для европейского португальского используйте орфографию Португалии: autocarro, comboio, telemóvel, pequeno-almoço.")
                    .font(.footnote)
                Text("Если слов в файле много, сначала проверьте на небольшом образце: импортированный словарь можно удалить свайпом на экране «Словари».")
                    .font(.footnote)
            }
        }
        .navigationTitle("Свой словарь")
        .navigationBarTitleDisplayMode(.inline)
    }
}
