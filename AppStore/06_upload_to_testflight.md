# Загрузка в App Store Connect без Mac (workflow «Release to TestFlight»)

Всё делается в браузере. Подпись и загрузку выполняет виртуальный Mac в GitHub Actions (файл `.github/workflows/release.yml`).

**Что нужно заранее:** аккаунт Apple Developer Program уже одобрен (письмо от Apple и доступ на https://developer.apple.com/account).

---

## 1. Выберите Bundle ID (один раз)

Bundle ID — уникальное имя приложения в обратной записи, например `com.ivanov.olapt` (латиница, цифры, точки). Потом его нельзя изменить, поэтому выберите окончательный вариант.

**Выбран:** `com.obe1k.olapt`, он уже прописан в проекте. Если понадобится другой, замена одной командой: `python3 Tools/set_bundle_id.py новый.id` (или попросите Claude).

## 1а. Опубликуйте политику конфиденциальности (GitHub Pages)

Страницы уже лежат в папке `docs/` репозитория. Осталось включить их показ:
1. Репозиторий → **Settings** → слева **Pages**.
2. **Source**: *Deploy from a branch*. **Branch**: `main`, папка **/docs** → **Save**.
3. Через 1–2 минуты страницы откроются по адресам (проверьте в браузере, в том числе с телефона):
   - политика: `https://obe1k.github.io/Olapt/privacy.html`
   - поддержка: `https://obe1k.github.io/Olapt/`

Первый адрес вставьте в App Store Connect в поле **Privacy Policy URL**, второй в **Support URL**.

## 2. Зарегистрируйте Bundle ID

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles** → **Identifiers** → кнопка **+**.
2. Тип **App IDs** → **App** → Continue.
3. Description: `Ola PT`. Bundle ID: **Explicit** и ваш ID из шага 1. Никаких Capabilities включать не нужно. → Continue → Register.

## 3. Создайте карточку приложения

1. https://appstoreconnect.apple.com → **Apps** → **+** → **New App**.
2. Platforms: **iOS**. Name: `Olá PT: португальский (PT)` (проверьте, что имя свободно; если нет, подберите другое). Primary Language: **Russian**. Bundle ID: выберите из списка (шаг 2). SKU: любое, например `olapt1`. User Access: Full Access.

## 4. Создайте ключ API

1. App Store Connect → **Users and Access** → вкладка **Integrations** → **App Store Connect API** → **Team Keys** (именно командные ключи; индивидуальные для этого не подходят).
2. Нажмите **+**, имя `github`, доступ **App Manager** → Generate. Если загрузка позже упадёт на создании сертификата, сделайте новый ключ с доступом **Admin**.
3. Запишите **Issuer ID** (вверху страницы) и **Key ID** (в строке ключа).
4. Нажмите **Download API Key**: файл `AuthKey_XXXXXXXXXX.p8` скачивается **только один раз**. Сохраните его в надёжном месте. Не отправляйте файл никому, в том числе Claude и в репозиторий: с ним можно управлять вашим аккаунтом.

## 5. Team ID

https://developer.apple.com/account → **Membership details** → **Team ID** (10 символов, буквы и цифры).

## 6. Секреты в GitHub

Репозиторий → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Создайте четыре секрета:

| Имя | Значение |
|---|---|
| `ASC_KEY_ID` | Key ID из шага 4 |
| `ASC_ISSUER_ID` | Issuer ID из шага 4 |
| `ASC_KEY_P8` | Откройте файл `.p8` в Блокноте и вставьте **весь** текст, включая строки `-----BEGIN PRIVATE KEY-----` и `-----END PRIVATE KEY-----` |
| `APPLE_TEAM_ID` | Team ID из шага 5 |

Секреты GitHub после сохранения не показываются: это нормально.

## 7. Запуск

1. Вкладка **Actions** → слева **Release to TestFlight** → **Run workflow** → Run workflow.
2. Ждите 10–20 минут. Зелёная галочка означает, что сборка загружена.
3. Если красный крестик: откройте запуск, внизу в блоке **Строки с ошибками** будут строки с `error:`. Пришлите мне их (или полный лог из **Artifacts → release-logs**). Первый запуск часто требует одной-двух правок, это нормально.
4. Каждый запуск получает новый номер сборки автоматически (`CURRENT_PROJECT_VERSION` = номер запуска), так что повторять можно сколько угодно.

## 8. После загрузки

1. App Store Connect → ваше приложение → **TestFlight**. Через 5–30 минут сборка получит статус «Готово к тестированию» (до этого «Обработка»). Если появится вопрос про шифрование, ответ «No»: в проекте уже указано `ITSAppUsesNonExemptEncryption = NO`.
2. Версия для магазина: **iOS App** → **1.0 Prepare for Submission**:
   - скриншоты (папка `OlaPT_screenshots`, размер 6.9″);
   - описание, ключевые слова, подзаголовок: `AppStore/02_listing_ru.md`;
   - **Privacy Policy URL**: `https://obe1k.github.io/Olapt/privacy.html`; **Support URL**: `https://obe1k.github.io/Olapt/`;
   - **App Privacy**: «Data Not Collected»;
   - Age Rating: ответьте «нет» на все вопросы (получится 4+);
   - в блоке **Build** нажмите **+** и выберите загруженную сборку;
   - Pricing: Free.
3. **Add for Review** → **Submit**. Проверка обычно занимает 1–2 дня.

## Как это устроено внутри

Встроенная «облачная подпись» xcodebuild на ключе API не работает (ошибка `Cannot verify client's JWT headers`), поэтому workflow делает подпись сам:
1. `Tools/asc_check.py` проверяет ключ запросом к API Apple и показывает, зарегистрирован ли Bundle ID и есть ли карточка приложения.
2. Архив собирается без подписи.
3. `Tools/asc_release.py` через API выпускает временный сертификат Apple Distribution и профиль App Store, после запуска они удаляются.
4. Архив экспортируется с этой подписью (запасной вариант: `Tools/pack_ipa.sh`), IPA загружается командой `xcrun altool --upload-package`.

## Частые ошибки

Шаги проверки пишут итог в аннотации запуска (страница запуска, блок Annotations).

| Сообщение | Что делать |
|---|---|
| `Не задан секрет …` | Нет секрета или он назван иначе. Имена: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `APPLE_TEAM_ID`. |
| `Apple не принимает ни один из ключей` | Key ID, Issuer ID и текст `.p8` не от одного ключа. Issuer ID берётся на странице Team Keys. |
| `Bundle ID … не зарегистрирован` или `карточка приложения … не найдена` | Выполните шаги 2–3 инструкции. |
| `не удалось выпустить сертификат` | У команды уже максимум сертификатов Apple Distribution: удалите лишние на developer.apple.com → Certificates. |
| `The bundle version must be higher …` | Номер сборки уже использован. Запустите workflow ещё раз. |
