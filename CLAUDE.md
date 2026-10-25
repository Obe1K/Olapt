# OlaPT — что нужно знать Claude перед работой

Приложение для изучения португальского (SwiftUI, iOS 16) и игра «Империя слов» внутри него.
С пользователем говорим по-русски, коротко и простыми словами.

## Жёсткие правила

- **Ключ App Store Connect (.p8) никому не передавать, включая Claude.** Секреты живут только
  в GitHub Actions secrets: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, APPLE_TEAM_ID. Не печатать, не просить.
- **Версия 1.3 (сборка 24) подготовлена в App Store Connect, но НЕ отправлена на проверку.**
  Отправлять только по прямой команде пользователя: workflow `asc-status.yml` с action `submit 1.3`.
- **Игра — только в ветке `game/act1`.** Коммитим и пушим прямо в неё, без pull request.
  `main`, `v1.1`–`v1.3` — линии релизов App Store, их не трогать.
- **Тестовый билд в TestFlight:** сначала поднять версию в ветке до 1.4 (MARKETING_VERSION
  в OlaPT.xcodeproj/project.pbxproj), потом вручную `release.yml`. Пользователь решил ждать,
  пока на карте будут метки и иконки.
- Подпись коммитов — как требует текущая сессия (Co-Authored-By и Claude-Session).

## Как работать с пользователем

- Арт рисует пользователь в ChatGPT по нашим командам. Команды — **полные, готовые к вставке,
  на английском**: стилевой блок + описание целиком, никаких шаблонов с [style]. Рядом по-русски:
  что приложить и что проверить. Правка картинки — отдельная короткая команда «Edit this image…».
- Даём порциями по 5 шагов.
- Картинка без текста = «проверь и поставь»: проверить, вырезать фон, уменьшить, подогнать цвет,
  поставить в приложение, показать превью/скриншот.
- Вкус: мрачная иберийская готика в духе Blasphemous, лучше темнее («грим дарк»); не любит
  крупные полупрозрачные заливки поверх карты (зона обелисков — только тонкий размытый ободок).
- После каждого принятого арта — заметка в ТЗ (документ ниже).

## Документы

Claude Docs, проект `3a6e0ace-cee0-41cb-88e6-6b1408ba55c2`
(https://claude.ai/artifact/8DUpicr9QNMkE49ywpbU5F), вкладки:
- **ТЗ на графику** — node `caf9233f-e424`: пакеты арта 0–7, все команды для ChatGPT, заметки о принятом.
- **Правила Акта 1** — node `b9bdb1fe-c5f8`. **Концепция** — node `ff2451c7-10aa`.

## Сборка и проверка

- Swift-компилятора в облачной сессии нет: всё компилирует CI `build.yml` на каждый пуш
  (там же шаг «Игра, Акт 1» — `Tools/game/swift_check`: проверки правил и бот-симулятор).
- Xcode synchronized folders: новые .swift/.imageset подхватываются сами, pbxproj не правим.
- Логи и артефакты CI из облака скачать нельзя. Ошибки компиляции —
  `gh api repos/Obe1K/Olapt/check-runs/<JOB_ID>/annotations`.
- UI-тесты со скриншотами: `gh workflow run ui-tests.yml --ref game/act1 -f only=testQ_EmpireBattle`
  (несколько — через запятую). Скриншоты: `git fetch origin ui-shots && git archive FETCH_HEAD shots_out | tar -x`.
- Аргументы для UI-тестов: `-uitest-game rich|midgame`, `-uitest-pet happy|ok|angry|skeleton|eating|cast`.
- Локализация: строки через `L("…")`, переводы в `Tools/l10n_en/ui_part1..4.py`
  (игра — ui_part4), затем `python3 Tools/l10n.py build` и `python3 Tools/l10n.py check`.

## Игра «Империя слов», Акт 1 — где что лежит

- Числа и карта правил: `OlaPT/Models/Game/Act1Rules.swift` (5 поселений, дороги, 10 мест обелисков).
- Состояние и движок: `GameState.swift`, `GameEngine.swift` (ночь, захват, бои, вылазки, оборона,
  агенты, указы, патрули; детерминированный RNG SplitMix64), `GameExercise.swift`.
- Связь с учёбой: `OlaPT/Models/AppModel+Game.swift` (Авра за ответы, анти-фарм, план «Сегодня»).
- Экран: `OlaPT/Views/Game/EmpireView.swift` (карта, `MapLayout`), `TownSheet.swift`,
  `BattleViews.swift`, `GameTexts.swift`; бой — `StudySessionView(battle:)`.
- Башня на «Сегодня»: `Models/TowerScene.swift`, `Models/TowerAtlas.swift`, `Views/PetView.swift`, `Views/TodayView.swift`.
- Баланс: `Tools/game/act1_sim.py` и `Tools/game/swift_check` (бот: ежедневно — 100% побед, медиана 41 день).

## Арт-конвейер

- Исходники автора: `Tools/game/art/` — `map_act1_base.png` (финальная карта 1024×1536, всё нарисовано
  на ней), `settle_*.png` (картинки поселений для шапки карточки), `ref/lord_alvaro.png` и
  `ref/villager_fisher_puppet.png` (эталоны стиля — их прикладывают к командам).
  Башня: `Tools/tower/src/*.png` (320×200).
- Сборка: `python3 Tools/game/build_game_assets.py` → `OlaPT/Assets.xcassets/Game` (картинки втрое
  подробнее точек карты, SCALE=3; карта затемняется `grim()` с `MAP_GRADE`);
  `python3 Tools/tower/build_tower.py` → `Assets.xcassets/Tower` + `TowerAtlas.swift`.
- ChatGPT часто рисует «прозрачность» шахматкой или ровным фоном: вырезаем заливкой от краёв
  (шахматка: min канал ≥190 и низкая насыщенность; чёрный: max канал ≤14), обрезаем по содержимому, LANCZOS.
- Карта — 320×480 точек (3.2 px исходника на точку). `MapLayout.towns/area/spots` измерены по
  финальной карте; если карту перерисуют — перемерить.

## Состояние на 26 октября 2026

Готово: сцена башни (5 поз мага), движок Акта 1, вкладка «Империя» с боями и отчётами,
финальная карта (темнее рисунка автора), зона обелисков — тонкий ободок.

Сейчас — пакет 2, метки на карте (команды в ТЗ, раздел «Пакет 2 — метки на карте»):
1. `obelisk_dark.png` — приложить финальную карту;
2. `obelisk_lit.png` — правка obelisk_dark;
3. `obelisk_broken.png` — правка obelisk_dark;
4. `banner_mask.png` — приложить финальную карту;
5. `banner_lord.png` — правка banner_mask + lord_alvaro.png.
Тусклый обелиск смешиваем сами из тёмного и горящего. Когда придут — заменить нарисованные кодом
флажок, обелиск и ромбики (`ownerFlag`, `obeliskIcon`, `spotMarker` в EmpireView) на картинки.

Дальше: `fx_fire`, `map_legion`, `map_patrol`; пакет 3 (жители, культисты, восставший);
пакет 4 (Багровый Поп); пакет 6 (13 значков); пакет 7 (10 портретов); портреты боссов на арене
(сейчас заглушки: лич, гоблин, паук, дракон); ежедневные карточки в духе Reigns (~60) — не начаты.
