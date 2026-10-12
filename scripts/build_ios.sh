#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null 2>&1 || { echo "Flutter 3.38.1+ не найден." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Нужен Python 3." >&2; exit 2; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Сборка iPhone-приложения требует macOS и Xcode." >&2; exit 2; }
python3 scripts/prepare_platforms.py
flutter pub get
cat <<'MSG'
Важно: перед release IPA откройте ios/Runner.xcworkspace в Xcode,
выберите Runner → Signing & Capabilities → Team и задайте уникальный Bundle Identifier.
Затем можно продолжить сборку.
MSG
flutter build ipa --release
mkdir -p "$ROOT/dist"
IPA="$(find "$ROOT/build/ios/ipa" -maxdepth 1 -name '*.ipa' -print -quit)"
if [ -z "$IPA" ]; then echo "IPA не найден; проверьте настройки подписи Xcode." >&2; exit 3; fi
cp "$IPA" "$ROOT/dist/VideoForge-iPhone.ipa"
echo "Готово: dist/VideoForge-iPhone.ipa"
echo "Установка на обычные iPhone выполняется через App Store/TestFlight или разрешённый профиль распространения."
