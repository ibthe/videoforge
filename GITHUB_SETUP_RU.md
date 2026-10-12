# VideoForge: сборка через GitHub Actions (инструкция на русском)

В проект включён workflow `.github/workflows/build.yml`. GitHub Actions сам поднимает облачные сборочные машины и пытается создать артефакты для четырёх платформ.

## Первый запуск

1. На [github.com/new](https://github.com/new) создай репозиторий `videoforge`. Для коммерческого проекта лучше начать с **Private**.
2. Установи [GitHub Desktop](https://desktop.github.com/) и войди в свой GitHub-аккаунт.
3. В GitHub Desktop клонируй только что созданный пустой репозиторий на Mac.
4. Распакуй архив VideoForge и скопируй **содержимое папки `VideoForgeProject`** в папку клонированного репозитория. Скопируй также скрытую папку `.github` — внутри неё находится workflow. Если Finder не показывает скрытые файлы, нажми `Command + Shift + .`.
5. В GitHub Desktop укажи commit summary, например `Add VideoForge source and build workflows`, нажми **Commit to main**, затем **Push origin**.
6. На странице репозитория открой вкладку **Actions**. Если GitHub попросит включить Actions, разреши их для своего репозитория. Открой запуск **VideoForge — build all platforms**.
7. После завершения каждого job скачай соответствующий artifact внизу страницы запуска. В workflow артефакты хранятся 14 дней; скачай их до истечения срока.

Workflow запускается при push в ветки `main`/`master`, при pull request и вручную через **Actions → VideoForge — build all platforms → Run workflow**.

## Какие файлы ожидаются

- **Windows:** `VideoForge-Windows-Setup.exe` и `VideoForge-Windows-Portable.zip`.
- **macOS:** `VideoForge-macOS.dmg` и `VideoForge-macOS.pkg`.
- **Android:** `VideoForge-Android.apk` и `VideoForge-Android.aab`.
- **iPhone:** `VideoForge-iPhone-unsigned.app.zip` — сборка для проверки, **не готовая к установке на обычный iPhone**.

## Важные ограничения первой CI-сборки

- Windows installer, macOS DMG/PKG и Android APK/AAB собираются без коммерческой подписи и без публикации в магазинах. Предупреждения SmartScreen/Gatekeeper и требования магазинов пока не решены.
- iOS job собирает unsigned `.app` только для проверки компиляции. Для установки на реальные iPhone и публикации в App Store нужно настроить Apple signing certificate, provisioning profile, bundle identifier и защищённые GitHub Actions Secrets. Секреты нельзя коммитить в репозиторий.
- Android AAB из текущего workflow не является финальным подписанным релизом Google Play. Перед публикацией нужно включить свою release-подпись и хранить ключ/пароли в GitHub Secrets.
- Если job завершился с ошибкой, открой его, выбери упавший шаг и скопируй сюда текст ошибки — по нему можно поправить workflow или проект. Успешный CI build — это проверка сборки, а не гарантия работы на всех реальных устройствах.
- Репозиторий хранит исходный код. Артефакты workflow временные (14 дней); для постоянной раздачи установщиков позже настроим GitHub Releases.

## Стоимость и минуты сборки

GitHub Actions работает в пределах квот/тарифных условий аккаунта; приватные репозитории имеют лимиты бесплатных минут и хранения. Если часто запускать все четыре сборки, проверь раздел Billing/Usage в GitHub.
