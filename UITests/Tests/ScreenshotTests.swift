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
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-uitest-static", "YES"]
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
        let service = ["Закрыть", "Произнести", "Далее", "Завершить", "Сегодня", "Словарь", "Коллекции", "Глаголы", "Настройки", "Не знаю", "Проверить"]
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

        // Глаголы на сегодня
        let verbs = app.buttons["verbs-start"]
        scrollUntilVisible(verbs)
        if tap(verbs, "start daily verbs") {
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

        // Все состояния питомца (застывший кадр)
        let variants: [(String, String, Int)] = [
            ("happy", "cellar", 1), ("happy", "hall", 4), ("happy", "library", 7), ("happy", "summit", 10),
            ("ok", "library", 3), ("eating", "hall", 5), ("angry", "cellar", 0), ("skeleton", "cellar", 0)
        ]
        for (mood, room, items) in variants {
            app.terminate()
            app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-uitest-pet", mood,
                                   "-uitest-room", room, "-uitest-items", String(items)]
            let withNews = mood == "happy" && room == "hall"
            if withNews {
                app.launchArguments += ["-uitest-news", "Маг поднялся на новый этаж: Зал!\nВ башне появилось: Ворон"]
            }
            app.launch()
            Thread.sleep(forTimeInterval: 1.5)
            tapTab("Сегодня")
            let screen = app.descendants(matching: .any)["pet-screen"]
            note(screen.waitForExistence(timeout: 4) ? "CHECK ok: pet " + mood + ": " + screen.label : "CHECK FAILED: pet " + mood + " missing")
            if withNews {
                let news = app.descendants(matching: .any)["tower-news"]
                note(news.waitForExistence(timeout: 3) ? "CHECK ok: tower news shown" : "CHECK FAILED: tower news missing")
            }
            note(app.staticTexts["pet-caption"].exists ? "CHECK FAILED: caption under pet still shown" : "CHECK ok: no caption under pet")
            shot("77_pet_" + mood + "_" + room)
        }
    }

    /// Башня с вещами, полный гримуар и бой с боссом: приложение запускается с 260 словами «в памяти».
    func testI_TowerGrimoireBoss() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-uitest-static", "YES", "-uitest-seed", "260"]
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

        app.swipeDown(); app.swipeDown()
        let boss = app.buttons["boss-start"]
        scrollUntilVisible(boss, maxSwipes: 4)
        shot("85_boss_card")
        if tap(boss, "start boss") {
            let arena = app.descendants(matching: .any)["boss-arena"]
            note(arena.waitForExistence(timeout: 4) ? "CHECK ok: boss arena: " + arena.label : "CHECK FAILED: boss arena missing")
            shot("80_boss_arena")
            var answered = 0
            while answered < 40 && !app.descendants(matching: .any)["boss-result"].exists {
                if app.buttons["Не знаю"].exists {
                    app.buttons["Не знаю"].tap()
                    let next = app.buttons["Далее"].exists ? app.buttons["Далее"] : app.buttons["Завершить"]
                    if next.waitForExistence(timeout: 3) { next.tap() }
                } else {
                    let option = firstOptionButton()
                    if option.exists && option.isHittable {
                        option.tap()
                        if answered == 0 { shot("81_boss_answer") }
                        Thread.sleep(forTimeInterval: 2.8)
                    } else {
                        Thread.sleep(forTimeInterval: 0.5)
                    }
                }
                answered += 1
            }
            let result = app.descendants(matching: .any)["boss-result"]
            note(result.waitForExistence(timeout: 4) ? "CHECK ok: boss result: " + result.label : "CHECK FAILED: no boss result after \(answered)")
            shot("86_boss_result")
        } else {
            note("CHECK FAILED: boss not available with seeded words")
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
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-uitest-static", "YES",
                               "-uitest-seed", "260", "-uitest-scan-sample"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)

        // коллекция «Уровень A1» — чтобы в плане были новые слова
        tapTab("Коллекции")
        let levels = app.staticTexts["Наборы по уровням (A1, A2…)"]
        scrollUntilVisible(levels)
        tap(levels, "levels link")
        tap(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A1'")).firstMatch, "open A1")
        tap(app.staticTexts["Все слова уровня"].firstMatch, "all A1 words")
        if tap(app.buttons["Создать коллекцию из набора"], "create A1 collection") {
            tap(app.alerts.buttons["OK"], "alert OK")
        }
        back(); back(); back()

        // 1. Сегодня: маг в башне и план
        tapTab("Сегодня")
        Thread.sleep(forTimeInterval: 1.0)
        shot("store_01_today")

        // 2. Фразы: собрать из слов
        let phrases = app.buttons["phrases-start"]
        scrollUntilVisible(phrases, maxSwipes: 6)
        if tap(phrases, "start phrases") {
            let t0 = app.buttons["tile-0"]
            if t0.waitForExistence(timeout: 3) {
                t0.tap()
                app.buttons["tile-1"].tap()
            }
            shot("store_02_phrases")
            tap(app.buttons["Закрыть"], "close phrases")
        }

        // 3. Словарь: карточка слова
        tapTab("Словарь")
        let field = app.searchFields.firstMatch
        typeInto(field, "saudade", "search field")
        dismissKeyboard()
        tap(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'saudade'")).firstMatch, "result saudade")
        Thread.sleep(forTimeInterval: 0.8)
        shot("store_03_word_card")
        back()

        // 4. Слова из фото
        tapTab("Коллекции")
        let open = app.buttons["open-scan"]
        scrollUntilVisible(open)
        tap(open, "open scan")
        tap(app.buttons["scan-sample-text"], "sample text")
        _ = app.staticTexts["scan-summary"].waitForExistence(timeout: 10)
        shot("store_04_photo_words")
        tap(app.buttons["Закрыть"], "close scan")

        // 5. Глаголы: таблица спряжения
        tapTab("Глаголы")
        typeInto(app.searchFields.firstMatch, "fazer", "verb search")
        dismissKeyboard()
        tap(app.staticTexts["fazer"].firstMatch, "open verb fazer")
        tap(app.staticTexts["Pretérito Perfeito"].firstMatch, "expand Pretérito Perfeito")
        shot("store_05_verbs")
        back()

        // 6. Босс недели
        tapTab("Сегодня")
        let boss = app.buttons["boss-start"]
        scrollUntilVisible(boss, maxSwipes: 6)
        if tap(boss, "start boss") {
            Thread.sleep(forTimeInterval: 0.8)
            shot("store_06_boss")
            tap(app.buttons["Закрыть"], "close boss")
        }

        // 7. Гримуар
        let grimoire = app.buttons["open-grimoire"]
        scrollUntilVisible(grimoire, maxSwipes: 6)
        if tap(grimoire, "open grimoire") {
            shot("store_07_grimoire")
            back()
        }

        // 8. Фраза в лицах
        let all = app.buttons["open-phrases"]
        scrollUntilVisible(all, maxSwipes: 6)
        if tap(all, "open phrases") {
            tap(app.staticTexts["estar com fome / ter fome"].firstMatch, "open phrase card")
            shot("store_08_phrase_card")
        }
    }
}
