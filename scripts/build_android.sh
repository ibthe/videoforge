#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null 2>&1 || { echo "Flutter 3.38.1+ не найден." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Нужен Python 3." >&2; exit 2; }
python3 scripts/prepare_platforms.py
flutter pub get
flutter build apk --release
flutter build appbundle --release
mkdir -p "$ROOT/dist"
cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/dist/VideoForge-Android.apk"
cp "$ROOT/build/app/outputs/bundle/release/app-release.aab" "$ROOT/dist/VideoForge-Android.aab"
echo "Готово: dist/VideoForge-Android.apk и dist/VideoForge-Android.aab"
echo "Перед публикацией в Google Play настройте релизную подпись в android/app/build.gradle(.kts)."
