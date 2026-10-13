#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null 2>&1 || { echo "Flutter 3.38.1+ не найден." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Нужен Python 3." >&2; exit 2; }
command -v hdiutil >/dev/null 2>&1 || { echo "Сборка macOS требует macOS." >&2; exit 2; }
python3 scripts/prepare_platforms.py
flutter pub get
flutter build macos --release
APP_DIR="$ROOT/build/macos/Build/Products/Release"
APP="$(find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP" ] && [ -d "$APP" ] || { echo "Не найден macOS .app в $APP_DIR" >&2; exit 3; }

# Re-sign the completed app bundle with the exact Release entitlement plist.
# Flutter/Xcode has previously produced an app whose signature omitted the
# file-picker entitlement even though it existed in the source plist. This
# explicit signing step makes the published artifact self-checking.
ENTITLEMENTS="$ROOT/macos/Runner/Release.entitlements"
[ -f "$ENTITLEMENTS" ] || { echo "Не найден файл $ENTITLEMENTS" >&2; exit 4; }
/usr/bin/codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"

ENTITLEMENTS_DUMP="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS_DUMP"' EXIT
/usr/bin/codesign -d --entitlements :- "$APP" >"$ENTITLEMENTS_DUMP" 2>&1
if ! tr -d '[:space:]' < "$ENTITLEMENTS_DUMP" | grep -Fq '<key>com.apple.security.files.user-selected.read-only</key><true/>'; then
  echo "ОШИБКА: entitlement выбора файлов отсутствует в подписи готового .app." >&2
  cat "$ENTITLEMENTS_DUMP" >&2
  exit 5
fi
if ! tr -d '[:space:]' < "$ENTITLEMENTS_DUMP" | grep -Fq '<key>com.apple.security.assets.movies.read-write</key><true/>'; then
  echo "ОШИБКА: entitlement записи в Movies отсутствует в подписи готового .app." >&2
  cat "$ENTITLEMENTS_DUMP" >&2
  exit 6
fi
rm -f "$ENTITLEMENTS_DUMP"
trap - EXIT
echo "Проверка подписи пройдена: выбор видео и папка Movies разрешены."
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
