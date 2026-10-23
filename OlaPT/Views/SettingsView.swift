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
            list.append(LanguageChoice(code: "mixed", title: L("Все языки вперемешку")))
        }
        return list
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return version + " (" + build + ")"
    }

    /// Язык интерфейса: переключается сразу.
    private var uiLanguage: Binding<String> {
        return Binding(
            get: { model.settings.uiLanguage },
            set: { model.setUILanguage($0) }
        )
    }

    var body: some View {
        GothicForm {
            // Заголовок на двух языках — чтобы его нашёл тот, кто случайно включил чужой язык
            Section(header: GothicHeader("Язык · Language"),  // l10n-ok: одинаково на обоих языках
                    footer: Text(L("Язык меню и подсказок. Переводы слов в упражнениях переключаются на тот же язык — его можно поменять ниже."))) {
                Picker(L("Язык приложения"), selection: uiLanguage) {
                    ForEach(Loc.supported, id: \.self) { code in
                        Text(Loc.nativeName(code)).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ui-language")
            }

            Section(header: GothicHeader(L("Сегодня")),
                    footer: Text(L("Сколько новых слов из коллекций добавлять в план каждый день. Повторения добавляются сами в нужные дни. 10 новых в день — это около 10 минут занятий, когда наберутся повторения."))) {
                Picker(L("Новых слов в день"), selection: setting(\.newWordsPerDay)) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("30").tag(30)
                }
            }

            Section(header: GothicHeader(L("Упражнения")),
                    footer: Text(L("Без строгой проверки ответ без акцента засчитывается, но приложение покажет, где он нужен. Со строгой — такой ответ считается ошибкой."))) {
                Picker(L("Язык перевода"), selection: setting(\.exerciseLanguage)) {
                    ForEach(languageChoices) { choice in
                        Text(choice.title).tag(choice.code)
                    }
                }
                Toggle(L("Строго учитывать ударения и ç, ã"), isOn: setting(\.strictAccents))
                Picker(L("Слов в тренировке коллекции"), selection: setting(\.sessionSize)) {
                    Text(L("Все слова")).tag(0)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("30").tag(30)
                }
            }

            Section(header: GothicHeader(L("Глаголы")),
                    footer: Text(L("Для тренировки спряжения: сколько верных ответов нужно, чтобы время глагола считалось выученным."))) {
                Stepper(value: setting(\.masteryThreshold), in: 3...30) {
                    Text(L("«Выучено» после %d верных", model.settings.masteryThreshold))
                }
                Toggle(L("Ошибка снимает один балл"), isOn: setting(\.wrongPenalty))
            }

            Section(header: GothicHeader(L("Звуки")),
                    footer: Text(L("Короткие 8-битные звуки на верный и неверный ответ и тихая музыка башни на вкладке «Сегодня». В беззвучном режиме iPhone молчат."))) {
                Toggle(L("Звуки ответов"), isOn: setting(\.soundsOn))
                Toggle(L("Музыка башни"), isOn: setting(\.musicOn))
            }

            Section(header: GothicHeader(L("Озвучка")),
                    footer: Text(Speaker.shared.hasEuropeanVoice
                                 ? L("Найден голос европейского португальского (pt-PT).")
                                 : L("Голос европейского португальского не найден. Скачайте его: Настройки iPhone → Универсальный доступ → Устный контент → Голоса → Португальский (Португалия)."))) {
                Toggle(L("Произносить слово при открытии карточки"), isOn: setting(\.autoSpeak))
            }

            Section(header: GothicHeader(L("Словари"))) {
                NavigationLink {
                    DictionariesView()
                } label: {
                    Label(L("Словари и импорт"), systemImage: "books.vertical")
                }
            }

            Section(header: GothicHeader(L("Данные"))) {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Label(L("Сбросить прогресс обучения"), systemImage: "arrow.counterclockwise")
                }
            }

            Section(header: GothicHeader(L("О приложении"))) {
                HStack {
                    Text(L("Версия"))
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                NavigationLink {
                    PrivacyInfoView()
                } label: {
                    Text(L("Конфиденциальность"))
                }
                Text(L("Словари составлены для европейского португальского (pt-PT), орфография — по Acordo Ortográfico. Шрифты Tiny5 и Jacquarda Bastarda 9 — SIL Open Font License 1.1."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(L("Настройки"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("Сбросить весь прогресс?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L("Сбросить прогресс"), role: .destructive) {
                model.resetProgress()
            }
            Button(L("Отмена"), role: .cancel) {}
        } message: {
            Text(L("Коллекции и слова останутся, но все слова станут «новыми». Это действие нельзя отменить."))
        }
    }
}

// MARK: - Конфиденциальность

struct PrivacyInfoView: View {
    var body: some View {
        GothicList {
            Section {
                Text(L("Приложение не собирает, не передаёт и не продаёт никакие данные. У него нет аккаунтов, рекламы и аналитики."))
                Text(L("Коллекции, прогресс и добавленные вами слова хранятся только на вашем устройстве. Если включено резервное копирование iCloud, они могут попасть в резервную копию устройства средствами iOS."))
                Text(L("Импортируемые словари читаются только из выбранных вами файлов и никуда не отправляются."))
                Text(L("Озвучка слов выполняется системным синтезатором речи прямо на устройстве."))
            }
        }
        .navigationTitle(L("Конфиденциальность"))
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
        GothicList {
            Section(header: GothicHeader(L("Установленные словари")),
                    footer: Text(L("Отключённый словарь не участвует в поиске и упражнениях. Переводы из всех включённых словарей показываются на одной карточке слова."))) {
                ForEach(model.packs) { pack in
                    Toggle(isOn: Binding(
                        get: { model.isPackEnabled(pack.id) },
                        set: { model.setPack(pack.id, enabled: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name)
                            Text(L("%@ · %d %@", Languages.name(pack.lang), pack.entryCount, Plural.words(pack.entryCount)) + (pack.isBundled ? "" : L(" · добавлен вами")))
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

            Section(header: GothicHeader(L("Добавить словарь"))) {
                Button {
                    showImporter = true
                } label: {
                    Label(L("Импортировать файл…"), systemImage: "square.and.arrow.down")
                }
                NavigationLink {
                    DictionaryFormatHelpView()
                } label: {
                    Label(L("Как составить свой словарь"), systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle(L("Словари"))
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
        .alert(L("Словари"), isPresented: Binding(
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
            message = L("Не удалось открыть файл: %@", error.localizedDescription)
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
                    message = L("Словарь «%@» добавлен: %d %@.", pack.name, pack.entries.count, Plural.words(pack.entries.count))
                } else if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) {
                    pendingText = text
                    pendingName = url.deletingPathExtension().lastPathComponent
                    showCSVSheet = true
                } else {
                    message = PackImporter.ImportError.unreadable.localizedDescription
                }
            } catch {
                message = L("Не удалось прочитать файл: %@", error.localizedDescription)
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
            GothicForm {
                Section(header: GothicHeader(L("Название словаря"))) {
                    TextField(L("Например, Португальский ↔ украинский"), text: $name)
                }
                Section(header: GothicHeader(L("Язык переводов в файле"))) {
                    Picker(L("Язык"), selection: $lang) {
                        ForEach(Languages.importable, id: \.self) { code in
                            Text(Languages.name(code)).tag(code)
                        }
                    }
                }
                if let e = errorText {
                    Section {
                        Text(e)
                            .foregroundColor(Theme.red)
                    }
                }
            }
            .navigationTitle(L("Импорт файла"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Отмена")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Импорт")) { runImport() }
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
        let finalName = trimmed.isEmpty ? L("Мой словарь") : trimmed
        do {
            let pack = try PackImporter.parseCSV(text: text, name: finalName, lang: lang)
            _ = try model.installPack(pack)
            onDone(L("Словарь «%@» добавлен: %d %@.", finalName, pack.entries.count, Plural.words(pack.entries.count)))
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Справка по формату

struct DictionaryFormatHelpView: View {
    // l10n-ok: пример файла словаря (украинский)
    private let csvExample = """
    casa; будинок | дім
    obrigado; дякую
    pequeno-almoço; сніданок
    """

    // l10n-ok: пример файла словаря (украинский)
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
        GothicList {
            Section(header: GothicHeader(L("Самый простой способ: CSV или TXT"))) {
                Text(L("Текстовый файл в кодировке UTF-8. В каждой строке — португальское слово, затем точка с запятой (или табуляция) и перевод. Несколько переводов разделяйте знаком «|»."))
                    .font(.subheadline)
                Text(csvExample)
                    .font(.system(.footnote, design: .monospaced))
                Text(L("При импорте приложение спросит название словаря и язык переводов. Переводы добавятся к тем же португальским словам, которые уже есть в приложении."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: GothicHeader(L("Расширенный формат: JSON"))) {
                Text(L("Такой же файл, как у встроенных словарей. Можно указать часть речи (pos: n, v, adj, adv, phrase …), род (g: m, f, mf), женскую форму (f) и бразильский вариант (br)."))
                    .font(.subheadline)
                Text(jsonExample)
                    .font(.system(.footnote, design: .monospaced))
            }

            Section(header: GothicHeader(L("Советы"))) {
                Text(L("Для европейского португальского используйте орфографию Португалии: autocarro, comboio, telemóvel, pequeno-almoço."))
                    .font(.footnote)
                Text(L("Если слов в файле много, сначала проверьте на небольшом образце: импортированный словарь можно удалить свайпом на экране «Словари»."))
                    .font(.footnote)
            }
        }
        .navigationTitle(L("Свой словарь"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
