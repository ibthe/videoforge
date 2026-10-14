# Исправления по логам CI — этап 2

## Причины падения сборок

1. **Android, macOS и Windows:** `lib/main.dart:325` использовал `FilePicker.platform.getDirectoryPath()`, но установленная версия `file_picker` предоставляет новый статический API. Вызов заменён на `FilePicker.getDirectoryPath()`.
2. **Windows:** `scripts/prepare_platforms.py` падал на печати русскоязычного сообщения из-за системной кодировки `cp1252`. Для stdout/stderr включена UTF-8-кодировка с безопасной заменой неподдерживаемых символов.
3. **iOS CI:** сборка без подписи всё равно остановилась на проверке provisioning profile. В GitHub Actions добавлена временная настройка Xcode `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGNING_REQUIRED = NO`, пустая `CODE_SIGN_IDENTITY`. Изменение применяется только к рабочей копии CI, а не к исходному проекту.

## Проверки

- Удалено использование `FilePicker.platform.getDirectoryPath`.
- Python-скрипт проверяется на синтаксис.
- Полную сборку Flutter для четырёх платформ в этой среде выполнить нельзя; после отправки изменений в GitHub Actions нужно подтвердить результат реальными runner-сборками.
