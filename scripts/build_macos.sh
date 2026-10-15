#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null 2>&1 || { echo "Flutter 3.38.1+ не найден." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Нужен Python 3." >&2; exit 2; }
command -v hdiutil >/dev/null 2>&1 || { echo "Сборка macOS требует macOS." >&2; exit 2; }
python3 scripts/prepare_platforms.py
flutter pub get
flutter build macos --release --dart-define="LICENSE_SERVER_URL=${LICENSE_SERVER_URL:-}"
APP_DIR="$ROOT/build/macos/Build/Products/Release"
APP="$(find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP" ] && [ -d "$APP" ] || { echo "Не найден macOS .app в $APP_DIR" >&2; exit 3; }
ENTITLEMENTS_FILE="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS_FILE"' EXIT
if ! codesign -d --entitlements - --xml "$APP" >"$ENTITLEMENTS_FILE" 2>&1; then
  echo "ОШИБКА: не удалось прочитать entitlements собранного macOS-приложения." >&2
  cat "$ENTITLEMENTS_FILE" >&2 || true
  exit 4
fi
if ! grep -q 'com.apple.security.files.user-selected.read-only' "$ENTITLEMENTS_FILE"; then
  echo "ОШИБКА: в подписи VideoForge отсутствует entitlement выбора файлов." >&2
  echo "Проверьте CODE_SIGN_ENTITLEMENTS в macos/Runner.xcodeproj/project.pbxproj." >&2
  cat "$ENTITLEMENTS_FILE" >&2
  exit 4
fi
if ! grep -q 'com.apple.security.assets.movies.read-write' "$ENTITLEMENTS_FILE"; then
  echo "ОШИБКА: в подписи VideoForge отсутствует доступ к папке Movies." >&2
  cat "$ENTITLEMENTS_FILE" >&2
  exit 4
fi
echo "Разрешения macOS проверены: выбор файлов и запись в Movies доступны."
mkdir -p "$ROOT/dist" "$ROOT/.dmg_stage" "$ROOT/.pkg_stage"
rm -rf "$ROOT/.dmg_stage/VideoForge.app" "$ROOT/.dmg_stage/Applications" "$ROOT/.pkg_stage/VideoForge.app"
cp -R "$APP" "$ROOT/.dmg_stage/VideoForge.app"
cp -R "$APP" "$ROOT/.pkg_stage/VideoForge.app"
ln -s /Applications "$ROOT/.dmg_stage/Applications"
DMG="$ROOT/dist/VideoForge-macOS.dmg"
PKG="$ROOT/dist/VideoForge-macOS.pkg"
rm -f "$DMG" "$PKG"
hdiutil create -volname "VideoForge" -srcfolder "$ROOT/.dmg_stage" -ov -format UDZO "$DMG"
rm -rf "$ROOT/.dmg_stage"
if command -v pkgbuild >/dev/null 2>&1; then
  pkgbuild --component "$ROOT/.pkg_stage/VideoForge.app" --install-location /Applications "$PKG"
fi
rm -rf "$ROOT/.pkg_stage"
echo "Готово: $DMG"
if [ -f "$PKG" ]; then echo "Также создан установщик: $PKG"; fi
echo "Перед коммерческой раздачей подпишите приложение Developer ID, подпишите установщик и выполните notarization."
