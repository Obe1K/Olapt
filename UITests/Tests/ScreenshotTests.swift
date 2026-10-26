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
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ui-language", "ru", "-uitest-static", "YES"]
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

    /// Перевод на языке упражнений (русский) и без второго языка через «·».
    private func isRussianOnly(_ text: String) -> Bool {
        return text.range(of: "[а-яё]", options: .regularExpression) != nil && !text.contains("·")
            && text.range(of: "[a-z]", options: .regularExpression) == nil
    }

    /// «Сегодня» → «Фразы» → «Тренировать набор (…)» первого набора.
    @discardableResult
    private func openPhraseSetPractice(english: Bool) -> Bool {
        let all = app.buttons["open-phrases"]
        scrollUntilVisible(all, maxSwipes: 8)
        guard tap(all, "open phrases") else { return false }
        let label = english ? "Practise the set" : "Тренировать набор"
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        return tap(start, "practise phrase set")
    }

    /// Английский интерфейс: на экране не должно быть кириллицы (кроме названия языка «Русский» в настройках).
    private func checkNoCyrillic(_ screen: String) {
        let allowed: Set<String> = ["Русский", "Язык · Language"]
        var bad: [String] = []
        for query in [app.staticTexts, app.buttons, app.textFields, app.searchFields, app.navigationBars] {
            for e in query.allElementsBoundByIndex where e.exists {
                for text in [e.label, (e.placeholderValue ?? "")] where !text.isEmpty && !allowed.contains(text) {
                    if text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil, !bad.contains(text) {
                        bad.append(text)
                    }
                }
            }
        }
        note(bad.isEmpty ? "CHECK ok: no Cyrillic on " + screen
                         : "CHECK FAILED: Cyrillic on " + screen + ": " + bad.prefix(6).joined(separator: " | "))
    }

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
            // Клавиатура может появиться не сразу (лист ещё выезжает) — ждём, при необходимости касаемся ещё раз.
            if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
                note("keyboard not shown, tapping again: " + what)
                field.tap()
                _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
            }
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

    /// Настройки теперь — шестерёнка на «Сегодня» (вкладку заняла «Империя»).
    private func openSettings(english: Bool = false) {
        tapTab(english ? "Today" : "Сегодня")
        tap(app.buttons["open-settings"], "open settings (gear)")
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
        let service = ["Закрыть", "Произнести", "Далее", "Завершить", "Сегодня", "Словарь", "Коллекции", "Глаголы", "Настройки", "Империя", "Не знаю", "Проверить",
                       "Close", "Pronounce", "Next", "Finish", "Today", "Dictionary", "Collections", "Verbs", "Settings", "Empire", "I don't know", "Check"]
        let predicate = NSPredicate(format: "NOT (label IN %@)", service as NSArray)
        return app.buttons.matching(predicate).element(boundBy: 0)
    }

    // MARK: - Тесты

    func testA_SearchAndWordCard() {
        shot("00_today_first_launch")
        tapTab("Словарь")
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

        // Уровней теперь два: выбор вперемешку и ввод слова.
        note(button(containing: "Уровень 3").exists ? "CHECK FAILED: level 3 still listed" : "CHECK ok: only 2 levels")
        note(button(containing: "Напиши слово").exists ? "CHECK ok: typing level listed" : "CHECK FAILED: typing level missing")

        // Уровень 1: выбор вперемешку — после ответа без кнопки «Далее», следующее слово само
        tap(button(containing: "Уровень 1"), "level 1")
        shot("15_level1_question")
        tap(firstOptionButton(), "level 1 option")
        // Проверяем сразу: через 1,5 с после верного ответа слово сменится само.
        let verdict = NSPredicate(format: "label CONTAINS 'Верно!' OR label CONTAINS 'Неверно'")
        note(app.descendants(matching: .any).matching(verdict).firstMatch.waitForExistence(timeout: 1) ? "CHECK ok: level 1 feedback shown" : "CHECK FAILED: level 1 no feedback")
        note(app.buttons["Далее"].exists ? "CHECK FAILED: level 1 still has Next button" : "CHECK ok: level 1 has no Next button")
        shot("16_level1_feedback")
        Thread.sleep(forTimeInterval: 3.2)
        note(app.descendants(matching: .any).matching(verdict).firstMatch.exists ? "CHECK FAILED: level 1 did not auto-advance" : "CHECK ok: level 1 auto-advanced")
        // Второй вопрос — тоже с выбором (направление может быть любым)
        tap(firstOptionButton(), "level 1 option 2")
        shot("18_level1_second_feedback")
        Thread.sleep(forTimeInterval: 3.2)
        shot("17_level1_next")
        tap(app.buttons["Закрыть"], "close level 1")

        // Уровень 2: написать слово
        tap(button(containing: "Уровень 2"), "level 2")
        shot("22_level2_question")
        tap(app.buttons["Не знаю"], "give up level 2")
        shot("23_level2_feedback")
        let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
        if next.waitForExistence(timeout: 3) {
            let low = next.frame.minY > app.frame.height * 0.7
            note(low ? "CHECK ok: Next button at the bottom" : "CHECK FAILED: Next button too high (y=\(Int(next.frame.minY)) of \(Int(app.frame.height)))")
        } else {
            note("CHECK FAILED: level 2 Next button missing")
        }
        tap(app.buttons["Закрыть"], "close level 2")
        back()

        // Подсветка букв: коллекция с одним словом «casa» (её создаёт testA)
        let mine = app.staticTexts["Моя первая коллекция"].firstMatch
        if mine.waitForExistence(timeout: 4) {
            tap(mine, "open my collection")
            tap(button(containing: "Уровень 2"), "level 2 (casa)")
            let field = app.textFields["Ваш ответ"]
            typeInto(field, "cas", "answer field")
            shot("20_level2_typing_green")
            field.typeText("x")
            note("CHECK info: typed value = " + ((field.value as? String) ?? "?"))
            shot("21_level2_typing_red")
            tap(app.buttons["Проверить"], "check answer")
            shot("21b_level2_checked")
            tap(app.buttons["Закрыть"], "close level 2 (casa)")
        } else {
            note("CHECK FAILED: collection «Моя первая коллекция» not found")
        }

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
        let trainerTr = app.staticTexts["verb-translation"]
        note(trainerTr.waitForExistence(timeout: 3) && isRussianOnly(trainerTr.label) ? "CHECK ok: trainer verb translation: " + trainerTr.label : "CHECK FAILED: trainer verb translation: " + trainerTr.label)
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
        openSettings()
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
                if what == "plural casas" && !chip.label.contains("словарная форма casa,") {
                    note("CHECK FAILED: " + what + " -> " + chip.label)
                } else {
                    note("CHECK ok: " + what + " -> " + chip.label)
                }
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
            scrollUntilVisible(custom, maxSwipes: 10)
            shot("57_scan_collection_bottom")
            note(custom.exists ? "CHECK ok: custom word in collection" : "CHECK FAILED: custom word missing in collection")
        } else {
            note("CHECK FAILED: collection not found")
        }
    }

    /// Новые экраны 1.1: наборы по уровням и словарь iOS для ненайденного слова.
    func testF_LevelsAndSystemDictionary() {
        tapTab("Словарь")
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

    /// Текст с трудными случаями: ç, превосходная степень, возвратный глагол, «oiço», старая орфография.
    func testG_ScanTextLemmas() {
        app.terminate()
        app.launchArguments += ["-uitest-scan-sample"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        tapTab("Коллекции")
        let open = app.buttons["open-scan"]
        scrollUntilVisible(open)
        tap(open, "open scan")
        tap(app.buttons["scan-sample-text"], "sample text")
        _ = app.staticTexts["scan-summary"].waitForExistence(timeout: 10)
        shot("58_scan_text_lemmas")
        let expectations: [(String, String)] = [
            ("tranças", "trança"), ("franja", ""), ("penteado", ""), ("oval", ""),
            ("lindíssima", "lindo"), ("Sentei-me", "sentar-se"), ("oiço", "ouvir"),
            ("acção", "ação"), ("Falámos", "falar"),
            // выражения: из таблицы учебника и в живых формах
            ("estar com fome", ""), ("ter fome", ""), ("Estamos com frio", "estar com frio"), ("está cansada", "estar cansado")
        ]
        for (text, lemma) in expectations {
            let chip = app.buttons["scan-chip-" + text]
            if chip.waitForExistence(timeout: 3) {
                let label = chip.label
                if label.contains("нет в словаре") {
                    note("CHECK FAILED: " + text + " not in dictionary")
                } else if !lemma.isEmpty && !label.contains("словарная форма " + lemma) {
                    note("CHECK FAILED: " + text + " -> " + label)
                } else {
                    note("CHECK ok: " + text + " -> " + label)
                }
            } else {
                note("CHECK FAILED: chip " + text + " missing")
            }
        }
    }

    /// «Сегодня»: план дня, тренировка до конца, итог с прогнозом, трудные слова, питомец.
    /// Строка итогов тренировки: «Верно с первого раза: 3 из 6».
    private func firstTryRate() -> XCUIElement {
        return app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Верно с первого раза'")).firstMatch
    }

    /// Отвечаем до итогов (на экране итогов есть «Закончить»): выбор — касание варианта (дальше само), ввод — «Не знаю» и «Далее».
    @discardableResult
    private func answerUntilSummary(limit: Int = 60) -> Int {
        var answered = 0
        while answered < limit {
            if app.buttons["Закончить"].exists || firstTryRate().exists { break }
            if app.buttons["Не знаю"].exists {
                app.buttons["Не знаю"].tap()
                let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
                if next.waitForExistence(timeout: 3) { next.tap() }
            } else {
                let option = firstOptionButton()
                if option.exists && option.isHittable {
                    option.tap()
                    Thread.sleep(forTimeInterval: 2.8)
                } else {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            answered += 1
        }
        return answered
    }

    func testH_TodayAndPet() {
        tapTab("Сегодня")
        shot("70_today")
        note(app.otherElements["pet-screen"].exists || app.images["pet-screen"].exists || app.descendants(matching: .any)["pet-screen"].exists
             ? "CHECK ok: pet shown" : "CHECK FAILED: pet missing")

        let start = app.buttons["today-start"]
        let extra = app.buttons["today-extra"]
        if start.waitForExistence(timeout: 4) {
            note("CHECK ok: plan shown: " + start.label)
            tap(start, "start daily")
        } else if extra.exists {
            note("CHECK info: plan already empty, taking extra new words")
            tap(extra, "extra new words")
        } else {
            note("CHECK FAILED: neither plan nor extra button")
        }
        shot("71_daily_question")

        let answered = answerUntilSummary()
        note("CHECK info: answered \(answered) questions")
        let rate = firstTryRate()
        if rate.waitForExistence(timeout: 4) {
            note("CHECK ok: daily summary: " + rate.label)
        } else {
            note("CHECK FAILED: daily summary not shown")
        }
        shot("72_daily_summary")
        let finishDaily = app.buttons["Закончить"]
        scrollUntilVisible(finishDaily)
        tap(finishDaily, "finish daily")
        shot("73_today_after")
        note(app.descendants(matching: .any)["today-done"].exists ? "CHECK ok: today done state" : "CHECK info: today plan not empty yet")

        let tower = app.descendants(matching: .any)["tower-card"]
        note(tower.waitForExistence(timeout: 3) ? "CHECK ok: tower card: " + tower.label : "CHECK FAILED: tower card missing")

        // Время в приложении — под гримуаром
        let timeRow = app.descendants(matching: .any)["time-in-app"]
        scrollUntilVisible(timeRow, maxSwipes: 8)
        note(timeRow.exists && timeRow.label.contains("Время в приложении") && timeRow.label.contains("мин")
             ? "CHECK ok: time in app: " + timeRow.label : "CHECK FAILED: time in app: " + (timeRow.exists ? timeRow.label : "missing"))

        // Глаголы на сегодня
        let verbs = app.buttons["verbs-start"]
        scrollUntilVisible(verbs)
        if tap(verbs, "start daily verbs") {
            let tr = app.staticTexts["verb-translation"]
            note(tr.waitForExistence(timeout: 3) && isRussianOnly(tr.label) ? "CHECK ok: daily verb translation: " + tr.label : "CHECK FAILED: daily verb translation: " + tr.label)
            shot("78_verbs_daily_question")
            for _ in 0..<3 {
                if app.buttons["Не знаю"].exists {
                    app.buttons["Не знаю"].tap()
                } else {
                    let option = firstOptionButton()
                    if option.exists { option.tap() }
                }
                let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
                if next.waitForExistence(timeout: 3) { next.tap() }
            }
            shot("78b_verbs_after")
            tap(app.buttons["Закрыть"], "close verbs")
        }

        // Гримуар
        let grimoire = app.buttons["open-grimoire"]
        scrollUntilVisible(grimoire)
        tap(grimoire, "open grimoire")
        shot("79_grimoire")
        back()

        // Босс недели: в чистом приложении пока закрыт (нужен десяток начатых слов) — см. testI.
        note(app.buttons["boss-start"].exists ? "CHECK info: boss already available" : "CHECK info: boss not available yet")

        let difficult = app.buttons["open-difficult"]
        scrollUntilVisible(difficult)
        tap(difficult, "open difficult words")
        shot("74_difficult_words")
        back()

        note(app.staticTexts["Пройти ещё раз?"].exists ? "CHECK FAILED: FAQ block still shown" : "CHECK ok: no FAQ block")
        app.swipeUp()
        shot("75_today_bottom")

        // Карточка слова: дата следующего повторения
        tapTab("Словарь")
        let field = app.searchFields.firstMatch
        typeInto(field, "casa", "search field")
        dismissKeyboard()
        tap(app.staticTexts["a casa"].firstMatch, "result: a casa")
        let nextReview = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Следующее повторение'")).firstMatch
        scrollUntilVisible(nextReview)
        note(nextReview.exists ? "CHECK ok: word card: " + nextReview.label : "CHECK FAILED: word card has no next review")
        shot("76_word_card_srs")

        shootTowerPoses()
    }

    /// Только зал башни: все позы мага (быстрый прогон для проверки картинок).
    func testP_TowerPoses() {
        shootTowerPoses()
    }

    /// Все состояния мага в зале башни (застывший кадр): сыт, проголодался, пьёт, колдует, голодает, совсем ослаб.
    private func shootTowerPoses() {
        for mood in ["happy", "ok", "eating", "cast", "angry", "skeleton"] {
            app.terminate()
            app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ui-language", "ru", "-uitest-pet", mood]
            app.launch()
            Thread.sleep(forTimeInterval: 1.5)
            tapTab("Сегодня")
            let screen = app.descendants(matching: .any)["pet-screen"]
            note(screen.waitForExistence(timeout: 4) ? "CHECK ok: pet " + mood + ": " + screen.label : "CHECK FAILED: pet " + mood + " missing")
            note(app.staticTexts["pet-caption"].exists ? "CHECK FAILED: caption under pet still shown" : "CHECK ok: no caption under pet")
            shot("77_pet_" + mood)
        }
    }

    /// Полный гримуар и бой с боссом: приложение запускается с 260 словами «в памяти».
    func testI_TowerGrimoireBoss() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ui-language", "ru", "-uitest-static", "YES", "-uitest-seed", "260",
                               "-uitest-game", "rich"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        tapTab("Сегодня")
        let tower = app.descendants(matching: .any)["tower-card"]
        note(tower.waitForExistence(timeout: 4) ? "CHECK ok: seeded tower: " + tower.label : "CHECK FAILED: tower card missing")
        shot("82_today_seeded")

        let grimoire = app.buttons["open-grimoire"]
        scrollUntilVisible(grimoire)
        if tap(grimoire, "open grimoire") {
            note(app.descendants(matching: .any)["grimoire-empty"].exists ? "CHECK FAILED: grimoire empty" : "CHECK ok: grimoire filled")
            shot("83_grimoire_full")
            app.swipeUp()
            shot("84_grimoire_more")
            back()
        }

        empireBattle()
    }

    /// Империя: карта, карточка поселения и штурм Деревни сетей (бой с боссом, бой, бросок кубика).
    func testQ_EmpireBattle() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ui-language", "ru", "-uitest-static", "YES",
                               "-uitest-seed", "260", "-uitest-game", "rich"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        empireBattle()
        // Середина игры: две деревни ваши, обелиски, пленники
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ui-language", "ru", "-uitest-static", "YES",
                               "-uitest-seed", "260", "-uitest-game", "midgame"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        tapTab("Империя")
        shot("93_empire_midgame")
        // зоны обелисков — только по кнопке на карте
        if tap(app.buttons["toggle-zones"], "show obelisk zones") {
            Thread.sleep(forTimeInterval: 0.5)
            shot("93_empire_zones")
            tap(app.buttons["toggle-zones"], "hide obelisk zones")
        }
        app.swipeUp()
        shot("94_empire_army")
        tap(app.buttons["town-2"], "open Vale do Trigo")
        shot("95_town_owned")
    }

    private func empireBattle() {
        tapTab("Империя")
        let map = app.descendants(matching: .any)["empire-map"]
        note(map.waitForExistence(timeout: 4) ? "CHECK ok: empire map" : "CHECK FAILED: empire map missing")
        shot("87_empire")
        guard tap(app.buttons["town-1"], "open Aldeia das Redes") else { return }
        let odds = app.descendants(matching: .any)["assault-odds"]
        scrollUntilVisible(odds, maxSwipes: 4)
        note(odds.exists ? "CHECK ok: assault odds: " + odds.label : "CHECK FAILED: no assault odds")
        shot("88_town_sheet")
        let start = app.buttons["start-assault"]
        scrollUntilVisible(start, maxSwipes: 4)
        guard tap(start, "start assault") else { return }
        var steps = 0
        var shotArena = false
        while steps < 120 && !app.buttons["battle-report-ok"].exists {
            steps += 1
            if app.buttons["battle-continue"].exists {
                shot("90_battle_summary_\(steps)")
                tap(app.buttons["battle-continue"], "finish battle stage")
                Thread.sleep(forTimeInterval: 1.5)
                continue
            }
            if app.buttons["Не знаю"].exists {
                app.buttons["Не знаю"].tap()
                let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
                if next.waitForExistence(timeout: 3) { next.tap() }
            } else {
                let option = firstOptionButton()
                if option.exists && option.isHittable {
                    if !shotArena && app.descendants(matching: .any)["boss-arena"].exists {
                        shot("89_boss_arena")
                        shotArena = true
                    }
                    option.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                } else {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        let report = app.buttons["battle-report-ok"]
        if report.waitForExistence(timeout: 6) {
            Thread.sleep(forTimeInterval: 2.0)   // кубик докатился
            let title = app.staticTexts["battle-report-title"]
            note("CHECK ok: battle report: " + (title.exists ? title.label : "?"))
            shot("91_battle_report")
            report.tap()
            Thread.sleep(forTimeInterval: 0.8)
            shot("92_empire_after")
        } else {
            note("CHECK FAILED: no battle report after \(steps) steps")
        }
    }

    /// Ответ без акцента: засчитывается, но с напоминанием, где нужен акцент.
    func testJ_AccentLeniency() {
        tapTab("Словарь")
        let field = app.searchFields.firstMatch
        typeInto(field, "lição", "search field")
        dismissKeyboard()
        tap(app.staticTexts["a lição"].firstMatch, "result: a lição")
        let save = app.buttons["Сохранить в коллекцию"]
        scrollUntilVisible(save)
        if tap(save, "save to collection") {
            typeInto(app.textFields["Название"], "Акценты", "collection name field")
            tap(app.buttons["Создать и добавить"], "create and add")
        }

        tapTab("Коллекции")
        tap(app.staticTexts["Акценты"].firstMatch, "open collection Акценты")
        tap(button(containing: "Уровень 2"), "level 2 (lição)")
        let answer = app.textFields["Ваш ответ"]
        typeInto(answer, "licao", "answer field")
        shot("90_accent_typing")
        tap(app.buttons["Проверить"], "check answer without accents")
        let feedback = app.descendants(matching: .any)["accent-feedback"]
        note(feedback.waitForExistence(timeout: 3) ? "CHECK ok: accent-only answer accepted: " + feedback.label : "CHECK FAILED: accent feedback missing")
        shot("91_accent_feedback")

        let next = app.buttons["Завершить"].exists ? app.buttons["Завершить"] : app.buttons["Далее"]
        tap(next, "finish level 2")
        let reminder = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'акцент'")).firstMatch
        note(reminder.waitForExistence(timeout: 3) ? "CHECK ok: summary reminds about accents" : "CHECK FAILED: no accent reminder in summary")
        shot("92_accent_summary")
    }

    /// Фразы: собрать из слов (сначала «Не знаю», затем на повторе — правильно по плиткам), список и карточка.
    func testK_Phrases() {
        tapTab("Сегодня")
        let start = app.buttons["phrases-start"]
        scrollUntilVisible(start, maxSwipes: 6)
        guard tap(start, "start phrases") else {
            note("CHECK FAILED: phrases card missing")
            return
        }
        shot("93_phrase_tiles")
        var answers: [String: String] = [:]   // подсказка → правильная фраза
        var solved = 0
        for _ in 0..<12 {
            if firstTryRate().exists { break }
            let prompt = app.staticTexts["phrase-prompt"]
            guard prompt.waitForExistence(timeout: 3) else { break }
            let key = prompt.label
            if let show = answers[key] {
                // повтор: собираем ответ из плиток
                let words = show.components(separatedBy: CharacterSet(charactersIn: " .,!?")).filter { !$0.isEmpty }
                for (k, w) in words.enumerated() {
                    let word = k == 0 ? w.prefix(1).lowercased() + w.dropFirst() : w
                    let tile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tile-' AND label == %@ AND enabled == true", word)).firstMatch
                    if tile.exists { tile.tap() } else { note("CHECK FAILED: tile " + word + " missing") }
                }
                if solved == 0 { shot("94_phrase_built") }
                tap(app.buttons["phrase-check"], "check phrase")
                let ok = app.descendants(matching: .any)["phrase-correct"]
                note(ok.waitForExistence(timeout: 3) ? "CHECK ok: phrase built from tiles: " + show : "CHECK FAILED: built phrase not accepted: " + show)
                if solved == 0 { shot("95_phrase_correct") }
                solved += 1
            } else {
                tap(app.buttons["Не знаю"], "give up phrase")
                let show = app.staticTexts["phrase-show"]
                if show.waitForExistence(timeout: 3) { answers[key] = show.label }
                if answers.count == 1 { shot("94a_phrase_answer") }
            }
            let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        note(solved > 0 ? "CHECK ok: phrases solved \(solved)" : "CHECK FAILED: no phrase solved")
        shot("96_phrase_summary")
        let finish = app.buttons["Закончить"]
        scrollUntilVisible(finish)
        tap(finish, "finish phrases")

        let all = app.buttons["open-phrases"]
        scrollUntilVisible(all, maxSwipes: 6)
        if tap(all, "open phrases") {
            shot("97_phrases_list")
            tap(app.staticTexts["estar com fome / ter fome"].firstMatch, "open phrase card")
            shot("98_phrase_card")
            back()
            back()
        }
    }

    /// Скриншоты для App Store (полный размер, файлы store_*): башня, фразы, словарь, фото, глаголы, босс, гримуар.
    func testZ_StoreScreenshots() {
        storeScreenshots(lang: "ru", prefix: "store_")
    }

    /// Те же скриншоты на английском (файлы store_en_*) — для английской страницы в App Store.
    func testZ2_StoreScreenshotsEnglish() {
        storeScreenshots(lang: "en", prefix: "store_en_")
    }

    private func storeScreenshots(lang: String, prefix: String) {
        let en = lang == "en"
        func t(_ ru: String, _ english: String) -> String { return en ? english : ru }
        app.terminate()
        app.launchArguments = ["-AppleLanguages", en ? "(en)" : "(ru)", "-AppleLocale", en ? "en_GB" : "ru_RU",
                               "-ui-language", lang, "-uitest-static", "YES", "-uitest-seed", "260", "-uitest-scan-sample",
                               "-uitest-game", "midgame"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)

        // коллекция «Уровень A1» — чтобы в плане были новые слова
        tapTab(t("Коллекции", "Collections"))
        let levels = app.staticTexts[t("Наборы по уровням (A1, A2…)", "Sets by level (A1, A2…)")]
        scrollUntilVisible(levels)
        tap(levels, "levels link")
        tap(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A1'")).firstMatch, "open A1")
        tap(app.staticTexts[t("Все слова уровня", "All words of the level")].firstMatch, "all A1 words")
        if tap(app.buttons[t("Создать коллекцию из набора", "Create a collection from this set")], "create A1 collection") {
            tap(app.alerts.buttons["OK"], "alert OK")
        }
        back(); back(); back()

        // 1. Сегодня: маг в башне и план
        tapTab(t("Сегодня", "Today"))
        Thread.sleep(forTimeInterval: 1.0)
        shot(prefix + "01_today")

        // 2. Фразы: собрать из слов
        let phrases = app.buttons["phrases-start"]
        scrollUntilVisible(phrases, maxSwipes: 6)
        if phrases.exists && phrases.isHittable {
            tap(phrases, "start phrases")
            _ = app.buttons["tile-0"].waitForExistence(timeout: 3)
            shot(prefix + "02_phrases")
            tap(app.buttons[t("Закрыть", "Close")], "close phrases")
        } else if openPhraseSetPractice(english: en) {
            // фраз на сегодня нет (план дня ещё не пройден) — берём набор целиком
            _ = app.buttons["tile-0"].waitForExistence(timeout: 3)
            shot(prefix + "02_phrases")
            tap(app.buttons[t("Закрыть", "Close")], "close phrases")
            back()
        }

        // 3. Словарь: карточка слова
        tapTab(t("Словарь", "Dictionary"))
        let field = app.searchFields.firstMatch
        typeInto(field, "saudade", "search field")
        dismissKeyboard()
        tap(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'saudade'")).firstMatch, "result saudade")
        Thread.sleep(forTimeInterval: 0.8)
        shot(prefix + "03_word_card")
        back()

        // 4. Слова из фото
        tapTab(t("Коллекции", "Collections"))
        let open = app.buttons["open-scan"]
        scrollUntilVisible(open)
        tap(open, "open scan")
        tap(app.buttons["scan-sample-text"], "sample text")
        _ = app.staticTexts["scan-summary"].waitForExistence(timeout: 10)
        shot(prefix + "04_photo_words")
        tap(app.buttons[t("Закрыть", "Close")], "close scan")

        // 5. Глаголы: таблица спряжения
        tapTab(t("Глаголы", "Verbs"))
        typeInto(app.searchFields.firstMatch, "fazer", "verb search")
        dismissKeyboard()
        tap(app.staticTexts["fazer"].firstMatch, "open verb fazer")
        tap(app.staticTexts["Pretérito Perfeito"].firstMatch, "expand Pretérito Perfeito")
        shot(prefix + "05_verbs")
        back()

        // 6. Империя: карта Акта 1
        tapTab(t("Империя", "Empire"))
        Thread.sleep(forTimeInterval: 0.8)
        shot(prefix + "06_empire")

        // 7. Гримуар
        tapTab(t("Сегодня", "Today"))
        let grimoire = app.buttons["open-grimoire"]
        scrollUntilVisible(grimoire, maxSwipes: 6)
        if tap(grimoire, "open grimoire") {
            shot(prefix + "07_grimoire")
            back()
        }

        // 8. Фраза в лицах
        let all = app.buttons["open-phrases"]
        scrollUntilVisible(all, maxSwipes: 6)
        if tap(all, "open phrases") {
            tap(app.staticTexts["estar com fome / ter fome"].firstMatch, "open phrase card")
            shot(prefix + "08_phrase_card")
        }
    }

    /// Английский интерфейс: основные экраны без кириллицы, английские пояснения и подсказки,
    /// переключение языка в настройках туда и обратно.
    func testL_English() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB", "-ui-language", "en",
                               "-uitest-static", "YES", "-uitest-seed", "260", "-uitest-scan-sample"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)

        // Сегодня
        note(app.tabBars.buttons["Today"].waitForExistence(timeout: 5) ? "CHECK ok: English tab bar" : "CHECK FAILED: no English tab bar")
        shot("en_01_today")
        checkNoCyrillic("Today")
        let timeRow = app.descendants(matching: .any)["time-in-app"]
        scrollUntilVisible(timeRow, maxSwipes: 8)
        note(timeRow.exists && timeRow.label.contains("Time in the app") && timeRow.label.contains("min")
             ? "CHECK ok: English time in app: " + timeRow.label : "CHECK FAILED: English time in app: " + (timeRow.exists ? timeRow.label : "missing"))
        app.swipeDown(); app.swipeDown(); app.swipeDown()

        // Тренажёр спряжений: перевод по-английски, местоимение в рамке
        tapTab("Verbs")
        tap(app.staticTexts["Conjugation practice"].firstMatch, "conjugation practice")
        if tap(app.buttons["Start"], "start verb trainer") {
            let tr = app.staticTexts["verb-translation"]
            note(tr.waitForExistence(timeout: 3) && tr.label.range(of: "[А-Яа-яЁё]", options: .regularExpression) == nil
                 ? "CHECK ok: English verb translation: " + tr.label : "CHECK FAILED: verb translation: " + tr.label)
            note(app.descendants(matching: .any)["verb-prompt"].exists ? "CHECK ok: pronoun prompt shown" : "CHECK FAILED: no pronoun prompt")
            shot("en_02_verb_question")
            checkNoCyrillic("verb question")
            tap(app.buttons["Close"], "close verbs")
        } else {
            note("CHECK FAILED: verb trainer did not start")
        }
        back()

        // Фразы: набор целиком, подсказка по-английски
        tapTab("Today")
        if openPhraseSetPractice(english: true) {
            let prompt = app.staticTexts["phrase-prompt"]
            note(prompt.waitForExistence(timeout: 3) && prompt.label.range(of: "[А-Яа-яЁё]", options: .regularExpression) == nil
                 ? "CHECK ok: English phrase prompt: " + prompt.label : "CHECK FAILED: phrase prompt: " + prompt.label)
            shot("en_03_phrase")
            checkNoCyrillic("phrase question")
            tap(app.buttons["Close"], "close phrases")
        } else {
            note("CHECK FAILED: phrase set practice did not start")
        }
        back()

        // Словарь: карточка с английским пояснением
        tapTab("Dictionary")
        typeInto(app.searchFields.firstMatch, "obrigado", "search obrigado")
        dismissKeyboard()
        tap(app.staticTexts["obrigado"].firstMatch, "open obrigado")
        let noteText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A man says'")).firstMatch
        note(noteText.waitForExistence(timeout: 3) ? "CHECK ok: English note on word card" : "CHECK FAILED: English note missing")
        shot("en_04_word_card")
        checkNoCyrillic("word card")
        back()

        // Коллекции и наборы по темам
        tapTab("Collections")
        shot("en_05_collections")
        checkNoCyrillic("Collections")
        let topics = app.staticTexts["Word sets by topic"]
        scrollUntilVisible(topics)
        if tap(topics, "topic sets") {
            note(app.staticTexts["Food and drink"].waitForExistence(timeout: 3) ? "CHECK ok: English topic names" : "CHECK FAILED: topic names")
            checkNoCyrillic("topic sets")
            back()
        }

        // Слова из фото
        let open = app.buttons["open-scan"]
        scrollUntilVisible(open)
        if tap(open, "open scan") {
            tap(app.buttons["scan-sample-text"], "sample text")
            _ = app.staticTexts["scan-summary"].waitForExistence(timeout: 10)
            shot("en_06_photo_words")
            checkNoCyrillic("photo words")
            tap(app.buttons["Close"], "close scan")
        }

        // Глаголы: список по алфавиту и таблица спряжения
        tapTab("Verbs")
        shot("en_07_verbs_list")
        checkNoCyrillic("Verbs list")
        typeInto(app.searchFields.firstMatch, "fazer", "verb search")
        dismissKeyboard()
        tap(app.staticTexts["fazer"].firstMatch, "open verb fazer")
        note(app.staticTexts["Present tense"].waitForExistence(timeout: 3) ? "CHECK ok: English tense description" : "CHECK FAILED: tense description")
        shot("en_08_conjugation")
        checkNoCyrillic("conjugation")
        back()

        // Настройки: переключить на русский и обратно
        openSettings(english: true)
        shot("en_09_settings")
        checkNoCyrillic("Settings")
        let picker = app.segmentedControls["ui-language"]
        if picker.waitForExistence(timeout: 3) {
            tap(picker.buttons["Русский"], "switch to Russian")
            note(app.tabBars.buttons["Сегодня"].waitForExistence(timeout: 4) ? "CHECK ok: switched to Russian live" : "CHECK FAILED: no Russian after switch")
            note(app.segmentedControls["ui-language"].waitForExistence(timeout: 3) ? "CHECK ok: stayed on Settings after switch" : "CHECK FAILED: left Settings after switch")
            shot("en_10_switched_ru")
            tap(app.segmentedControls["ui-language"].buttons["English"], "switch back to English")
            note(app.tabBars.buttons["Today"].waitForExistence(timeout: 4) ? "CHECK ok: switched back to English" : "CHECK FAILED: no English after switching back")
        } else {
            note("CHECK FAILED: language picker missing")
        }
    }
}
