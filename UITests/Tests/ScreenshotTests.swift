import XCTest

/// Автопрогон основных экранов Olá PT в симуляторе.
/// Шаги «мягкие»: если элемент не найден, тест не падает, а записывает это в журнал (steps-*.txt)
/// и идёт дальше, чтобы по скриншотам и журналу было видно, что именно не сработало.
final class ScreenshotTests: XCTestCase {

    /// Bundle ID приложения. Если вы смените его в Xcode, поменяйте и здесь.
    private let bundleID = "com.obe1k.olapt"

    private var app: XCUIApplication!
    private var steps: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true
        steps = []
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
    }

    override func tearDownWithError() throws {
        let safe = name.replacingOccurrences(of: "[^A-Za-z0-9_]", with: "", options: .regularExpression)
        let attachment = XCTAttachment(string: steps.joined(separator: "\n"))
        attachment.name = "steps-" + safe
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    // MARK: - Помощники

    private func note(_ text: String) {
        steps.append(text)
        print("STEP " + text)
    }

    private func shot(_ title: String) {
        Thread.sleep(forTimeInterval: 0.9)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
        note("shot " + title)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 6) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            note("tap ok: " + what)
            return true
        }
        note("tap FAILED (not found): " + what)
        return false
    }

    private func typeInto(_ field: XCUIElement, _ text: String, _ what: String) {
        if tap(field, "focus " + what) {
            field.typeText(text)
            note("typed into " + what + ": " + text)
        }
    }

    private func clear(_ field: XCUIElement, count: Int) {
        // После скрытия клавиатуры у поля нет фокуса — сначала касаемся его.
        if field.waitForExistence(timeout: 4) {
            field.tap()
        }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: count)
        field.typeText(deletes)
    }

    private func tapTab(_ title: String) {
        let inBar = app.tabBars.buttons[title]
        if inBar.waitForExistence(timeout: 4) {
            tap(inBar, "tab " + title)
        } else {
            tap(app.buttons[title], "tab " + title)
        }
    }

    private func back() {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        if button.waitForExistence(timeout: 3) {
            button.tap()
            note("back")
        } else {
            note("back FAILED: no nav button")
        }
    }

    /// Скрывает клавиатуру нажатием клавиши «Найти»/«Готово» (поиск остаётся активным).
    private func dismissKeyboard() {
        for label in ["Найти", "Search", "search", "Готово", "Done", "return"] {
            let key = app.keyboards.buttons[label]
            if key.exists {
                key.tap()
                note("keyboard dismissed via " + label)
                return
            }
        }
        note("keyboard: no dismiss key found")
    }

    private func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    private func button(containing text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.buttons.matching(predicate).firstMatch
    }

    /// Первая кнопка с вариантом ответа (не служебная).
    private func firstOptionButton() -> XCUIElement {
        let service = ["Закрыть", "Произнести", "Далее", "Завершить", "Словарь", "Коллекции", "Глаголы", "Настройки"]
        let predicate = NSPredicate(format: "NOT (label IN %@)", service as NSArray)
        return app.buttons.matching(predicate).element(boundBy: 0)
    }

    // MARK: - Тесты

    func testA_SearchAndWordCard() {
        shot("01_dictionary_home")

        let field = app.searchFields.firstMatch
        typeInto(field, "casa", "search field")
        dismissKeyboard()
        shot("02_search_casa")

        // Другие запросы: английский и форма глагола.
        clear(field, count: 4)
        typeInto(field, "house", "search field")
        dismissKeyboard()
        shot("03_search_house")
        clear(field, count: 5)
        typeInto(field, "falamos", "search field")
        dismissKeyboard()
        shot("04_search_verb_form")
        clear(field, count: 7)
        typeInto(field, "casa", "search field")
        dismissKeyboard()

        tap(app.staticTexts["a casa"].firstMatch, "result: a casa")
        shot("05_word_card")
        app.swipeUp()
        shot("06_word_card_bottom")

        let save = app.buttons["Сохранить в коллекцию"]
        scrollUntilVisible(save)
        if tap(save, "save to collection") {
            shot("07_collection_picker")
            typeInto(app.textFields["Название"], "Моя первая коллекция", "collection name field")
            shot("08_collection_name_typed")
            tap(app.buttons["Создать и добавить"], "create and add")
            shot("09_card_after_save")
        }

        // Карточка глагола со ссылкой на спряжение.
        back()
        clear(field, count: 4)
        typeInto(field, "falar", "search field")
        dismissKeyboard()
        tap(app.staticTexts["falar"].firstMatch, "result: falar")
        shot("09b_verb_card")
    }

    func testB_CollectionsAndExercises() {
        tapTab("Коллекции")
        shot("10_collections_start")

        tap(app.staticTexts["Наборы слов по темам"], "topics link")
        tap(app.staticTexts["Приветствия и фразы"], "topic greetings")
        shot("11_topic_words")
        tap(app.buttons["Создать коллекцию из набора"], "create collection from topic")
        shot("12_collection_created")
        tap(app.alerts.buttons["OK"], "alert OK")
        back()
        back()

        shot("13_collections_list")
        tap(app.staticTexts["Приветствия и фразы"].firstMatch, "open collection")
        shot("14_collection_detail")

        // Уровень 1: выбрать перевод
        tap(button(containing: "Уровень 1"), "level 1")
        shot("15_level1_question")
        tap(firstOptionButton(), "level 1 option")
        shot("16_level1_feedback")
        tap(app.buttons["Далее"], "next question")
        shot("17_level1_next")
        tap(app.buttons["Закрыть"], "close level 1")

        // Уровень 2: выбрать слово
        tap(button(containing: "Уровень 2"), "level 2")
        shot("18_level2_question")
        tap(firstOptionButton(), "level 2 option")
        shot("19_level2_feedback")
        tap(app.buttons["Закрыть"], "close level 2")

        // Уровень 3: написать перевод
        tap(button(containing: "Уровень 3"), "level 3")
        typeInto(app.textFields["Ваш ответ"], "cas", "answer field")
        shot("20_level3_typing")
        tap(app.buttons["Не знаю"], "give up")
        shot("21_level3_feedback")
        tap(app.buttons["Закрыть"], "close level 3")

        // Уровень 4: написать слово
        tap(button(containing: "Уровень 4"), "level 4")
        shot("22_level4_question")
        tap(app.buttons["Не знаю"], "give up level 4")
        shot("23_level4_feedback")
        tap(app.buttons["Закрыть"], "close level 4")

        shot("24_collection_after_exercises")
    }

    func testC_Verbs() {
        tapTab("Глаголы")
        shot("30_verbs_list")

        typeInto(app.searchFields.firstMatch, "fazer", "verb search")
        shot("31_verbs_search")
        tap(app.staticTexts["fazer"].firstMatch, "open verb fazer")
        shot("32_conjugation_presente")
        tap(app.staticTexts["Pretérito Perfeito"].firstMatch, "expand Pretérito Perfeito")
        shot("33_conjugation_perfeito")
        back()

        tap(app.staticTexts["Тренировка спряжений"].firstMatch, "verb trainer link")
        shot("34_verb_trainer_setup")
        tap(app.buttons["Начать"], "start verb trainer (choice)")
        shot("35_verb_question_choice")
        tap(firstOptionButton(), "verb option")
        shot("36_verb_feedback")
        tap(app.buttons["Закрыть"], "close verb trainer")

        let typingMode = app.segmentedControls.buttons["Написать форму"]
        scrollUntilVisible(typingMode)
        tap(typingMode, "mode: typing")
        tap(app.buttons["Начать"], "start verb trainer (typing)")
        typeInto(app.textFields["Форма глагола"], "fa", "verb answer field")
        shot("37_verb_question_typing")
        tap(app.buttons["Не знаю"], "give up verb")
        shot("38_verb_typing_feedback")
        tap(app.buttons["Закрыть"], "close verb trainer 2")
    }

    func testD_Settings() {
        tapTab("Настройки")
        shot("40_settings")
        tap(app.staticTexts["Словари и импорт"], "dictionaries link")
        shot("42_dictionaries")
        back()
        let privacy = app.staticTexts["Конфиденциальность"]
        scrollUntilVisible(privacy)
        shot("41_settings_bottom")
        tap(privacy, "privacy link")
        shot("43_privacy")
    }

    /// «Слова из фото»: тестовая картинка → распознавание → выбор слов → коллекция.
    func testE_ScanWords() {
        app.terminate()
        app.launchArguments += ["-uitest-scan-sample"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)

        tapTab("Коллекции")
        let open = app.buttons["open-scan"]
        scrollUntilVisible(open)
        tap(open, "open scan")
        shot("50_scan_pick")
        tap(app.buttons["scan-sample"], "sample image")

        let summary = app.staticTexts["scan-summary"]
        if summary.waitForExistence(timeout: 40) {
            note("CHECK ok: summary = " + summary.label)
        } else {
            note("CHECK FAILED: no result screen")
        }
        shot("51_scan_result")

        let expectations: [(String, String)] = [
            ("fal", "verb form falámos"), ("casas", "plural casas"), ("Bom dia", "phrase bom dia"),
            ("autocarro", "word autocarro"), ("minha", "possessive minha"), ("ornitorrinco", "unknown word")
        ]
        for (prefix, what) in expectations {
            let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scan-chip-" + prefix)).firstMatch
            if chip.waitForExistence(timeout: 3) {
                note("CHECK ok: " + what + " -> " + chip.label)
            } else {
                note("CHECK FAILED: " + what + " not found")
            }
        }
        let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-chip-'"))
        var ids: [String] = []
        for i in 0..<min(chips.count, 60) {
            ids.append(chips.element(boundBy: i).identifier.replacingOccurrences(of: "scan-chip-", with: ""))
        }
        note("CHECK info: chips = " + ids.joined(separator: " | "))

        tap(app.buttons["Выбрать новые"], "select new")
        shot("52_scan_selected")
        let unknown = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-chip-ornitorrinco'")).firstMatch
        scrollUntilVisible(unknown)
        tap(unknown, "select unknown word")
        tap(app.buttons["scan-add"], "add selected")

        let field = app.textFields.matching(NSPredicate(format: "placeholderValue BEGINSWITH 'Перевод'")).firstMatch
        if field.waitForExistence(timeout: 6) {
            typeInto(field, "утконос", "translation field")
            shot("53_unknown_sheet")
            tap(app.navigationBars.buttons["Добавить"], "add unknown words")
        } else {
            note("CHECK FAILED: unknown-word sheet not shown")
        }

        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 8) {
            let texts = alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " / ")
            note("CHECK ok: alert = " + texts)
            shot("54_scan_done")
            tap(alert.buttons["Остаться"], "alert stay")
        } else {
            note("CHECK FAILED: no completion alert")
        }

        tap(app.buttons["Закрыть"], "close scan")
        shot("55_collections_after_scan")
        let created = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Из фото'")).firstMatch
        if created.waitForExistence(timeout: 5) {
            note("CHECK ok: collection created: " + created.label)
            tap(created, "open created collection")
            shot("56_scan_collection")
            let custom = app.staticTexts["ornitorrinco"]
            note(custom.waitForExistence(timeout: 3) ? "CHECK ok: custom word in collection" : "CHECK FAILED: custom word missing in collection")
        } else {
            note("CHECK FAILED: collection not found")
        }
    }

    /// Новые экраны 1.1: наборы по уровням и словарь iOS для ненайденного слова.
    func testF_LevelsAndSystemDictionary() {
        let field = app.searchFields.firstMatch
        typeInto(field, "zzzqqq", "search field")
        dismissKeyboard()
        let ios = button(containing: "словаре iOS")
        note(ios.waitForExistence(timeout: 4) ? "CHECK ok: iOS dictionary button shown" : "CHECK FAILED: iOS dictionary button missing")
        shot("60_not_found")
        clear(field, count: 6)
        typeInto(field, "falámos", "search field")
        dismissKeyboard()
        note(app.staticTexts["falar"].firstMatch.waitForExistence(timeout: 4) ? "CHECK ok: verb form search" : "CHECK FAILED: verb form search")
        clear(field, count: 7)
        typeInto(field, "senhorio", "search field")
        dismissKeyboard()
        note(app.staticTexts["o senhorio"].firstMatch.waitForExistence(timeout: 4) ? "CHECK ok: new word senhorio found" : "CHECK FAILED: new word senhorio")
        shot("61_new_word")

        tapTab("Коллекции")
        let levels = app.staticTexts["Наборы по уровням (A1, A2…)"]
        scrollUntilVisible(levels)
        tap(levels, "levels link")
        shot("62_levels")
        let a1 = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A1'")).firstMatch
        note(a1.waitForExistence(timeout: 4) ? "CHECK ok: level A1 row" : "CHECK FAILED: no A1 row")
        tap(a1, "open A1")
        shot("63_level_A1_topics")
    }
}
