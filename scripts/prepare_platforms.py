
#!/usr/bin/env python3
"""Generate Flutter native scaffolding and apply VideoForge platform settings."""
from __future__ import annotations

import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# GitHub Actions on Windows may use a legacy code page (e.g. cp1252).
# Keep Russian diagnostic messages from crashing the platform preparation script.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = ("android", "ios", "macos", "windows")


def run(command):
    if os.name == "nt" and command and command[0].lower() == "flutter":
        # На Windows запускаем flutter через командную оболочку,
        # чтобы корректно вызывался flutter.bat.
        subprocess.run(
            subprocess.list2cmdline(command),
            cwd=ROOT,
            check=True,
            shell=True,
        )
    else:
        subprocess.run(command, cwd=ROOT, check=True)


def ensure_macos_file_picker_entitlements(project_root: Path) -> None:
    """Добавляет разрешение на чтение файлов, выбранных пользователем."""
    runner_dir = project_root / "macos" / "Runner"

    for filename in (
        "DebugProfile.entitlements",
        "Release.entitlements",
    ):
        path = runner_dir / filename

        if not path.exists():
            print(f"Предупреждение: файл не найден: {path}")
            continue

        entitlements = plistlib.loads(path.read_bytes())

        # Network time verification requires outgoing HTTPS in the sandbox.
        entitlements["com.apple.security.network.client"] = True
        # File selection needs read access; custom output folders need write access.
        entitlements["com.apple.security.files.user-selected.read-only"] = True
        entitlements["com.apple.security.files.user-selected.read-write"] = True
        entitlements["com.apple.security.assets.movies.read-write"] = True

        path.write_bytes(
            plistlib.dumps(
                entitlements,
                fmt=plistlib.FMT_XML,
                sort_keys=False,
            )
        )

        print(f"Разрешение выбора файлов добавлено: {filename}")


def add_plist_bool(path: Path, key: str) -> None:
    if not path.exists():
        print(f"Предупреждение: файл не найден: {path}")
        return

    text = path.read_text(encoding="utf-8")

    if f"<key>{key}</key>" in text:
        return

    insertion = f"\t<key>{key}</key>\n\t<true/>\n"
    position = text.rfind("</dict>")

    if position < 0:
        print(f"Предупреждение: plist не распознан: {path}")
        return

    text = text[:position] + insertion + text[position:]
    path.write_text(text, encoding="utf-8")


def set_ios_target() -> None:
    podfile = ROOT / "ios" / "Podfile"

    if podfile.exists():
        text = podfile.read_text(encoding="utf-8")

        if re.search(
            r"^\s*#?\s*platform :ios,",
            text,
            flags=re.MULTILINE,
        ):
            text = re.sub(
                r"^\s*#?\s*platform :ios, ['\"][^'\"]+['\"]",
                "platform :ios, '14.0'",
                text,
                count=1,
                flags=re.MULTILINE,
            )
        else:
            text = "platform :ios, '14.0'\n" + text

        podfile.write_text(text, encoding="utf-8")

    project = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"

    if project.exists():
        text = project.read_text(encoding="utf-8")
        text = re.sub(
            r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;",
            "IPHONEOS_DEPLOYMENT_TARGET = 14.0;",
            text,
        )
        project.write_text(text, encoding="utf-8")

    info = ROOT / "ios" / "Runner" / "Info.plist"

    if info.exists():
        text = info.read_text(encoding="utf-8")
        text = re.sub(
            r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
            r"\1VideoForge\2",
            text,
        )
        info.write_text(text, encoding="utf-8")

        add_plist_bool(info, "UIFileSharingEnabled")
        add_plist_bool(info, "LSSupportsOpeningDocumentsInPlace")


def set_android_target() -> None:
    app_gradle = ROOT / "android" / "app" / "build.gradle.kts"

    if app_gradle.exists():
        text = app_gradle.read_text(encoding="utf-8")
        text = re.sub(
            r"minSdk\s*=\s*flutter\.minSdkVersion",
            "minSdk = 24",
            text,
        )
        text = re.sub(
            r"minSdkVersion\s+flutter\.minSdkVersion",
            "minSdkVersion 24",
            text,
        )
        app_gradle.write_text(text, encoding="utf-8")
    else:
        app_gradle_groovy = ROOT / "android" / "app" / "build.gradle"

        if app_gradle_groovy.exists():
            text = app_gradle_groovy.read_text(encoding="utf-8")
            text = re.sub(
                r"minSdkVersion\s+flutter\.minSdkVersion",
                "minSdkVersion 24",
                text,
            )
            app_gradle_groovy.write_text(text, encoding="utf-8")

    manifest = (
        ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "AndroidManifest.xml"
    )

    if manifest.exists():
        text = manifest.read_text(encoding="utf-8")
        text = re.sub(
            r'android:label="[^"]+"',
            'android:label="VideoForge"',
            text,
            count=1,
        )
        internet_permission = '<uses-permission android:name="android.permission.INTERNET" />'
        if internet_permission not in text:
            text = re.sub(r'(<manifest\b[^>]*>)', r'\1\n    ' + internet_permission, text, count=1)
        manifest.write_text(text, encoding="utf-8")


def set_macos_code_sign_entitlements(project: Path) -> None:
    """Bind the Runner app target to its Debug and Release entitlement files."""
    if not project.exists():
        print(f"Предупреждение: Xcode project не найден: {project}")
        return

    text = project.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(isa = XCBuildConfiguration;\s*buildSettings = \{)(.*?)(\};\s*name = (Debug|Release|Profile);)",
        flags=re.DOTALL,
    )

    def update_config(match: re.Match[str]) -> str:
        settings = match.group(2)
        config_name = match.group(4)
        bundle_match = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", settings)
        if bundle_match is None:
            return match.group(0)
        bundle_id = bundle_match.group(1).strip()
        if "RunnerTests" in bundle_id or ".RunnerTests" in bundle_id:
            return match.group(0)

        entitlement_file = (
            "Runner/DebugProfile.entitlements"
            if config_name == "Debug"
            else "Runner/Release.entitlements"
        )
        entitlement_line = f"CODE_SIGN_ENTITLEMENTS = {entitlement_file};"
        if re.search(r"CODE_SIGN_ENTITLEMENTS\s*=\s*[^;]+;", settings):
            settings = re.sub(
                r"CODE_SIGN_ENTITLEMENTS\s*=\s*[^;]+;",
                entitlement_line,
                settings,
                count=1,
            )
        else:
            settings = settings.rstrip() + "\n\t\t\t\t" + entitlement_line + "\n"
        return match.group(1) + settings + match.group(3)

    updated, count = pattern.subn(update_config, text)
    project.write_text(updated, encoding="utf-8")
    if count == 0:
        print("Предупреждение: не удалось автоматически проверить Xcode build settings.")
    else:
        print("Настройки подписи macOS привязаны к файлам entitlements.")


def set_macos_target() -> None:
    project = ROOT / "macos" / "Runner.xcodeproj" / "project.pbxproj"

    if project.exists():
        text = project.read_text(encoding="utf-8")
        text = re.sub(
            r"MACOSX_DEPLOYMENT_TARGET = [0-9.]+;",
            "MACOSX_DEPLOYMENT_TARGET = 10.15;",
            text,
        )
        text = text.replace(
            "PRODUCT_NAME = Runner;",
            "PRODUCT_NAME = VideoForge;",
        )
        project.write_text(text, encoding="utf-8")

    info = ROOT / "macos" / "Runner" / "Info.plist"

    if info.exists():
        text = info.read_text(encoding="utf-8")
        text = re.sub(
            r"(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)",
            r"\1VideoForge\2",
            text,
        )
        info.write_text(text, encoding="utf-8")

    # Явно связываем Runner target с нужными файлами разрешений и
    # записываем разрешения в Debug/Profile и Release entitlements.
    set_macos_code_sign_entitlements(project)
    ensure_macos_file_picker_entitlements(ROOT)

    # Сохраняем разрешение на доступ к папке Movies,
    # если оно требуется существующей конфигурации проекта.
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        entitlements = ROOT / "macos" / "Runner" / name
        add_plist_bool(
            entitlements,
            "com.apple.security.assets.movies.read-write",
        )


def set_windows_title() -> None:
    candidates = [
        ROOT / "windows" / "runner" / "main.cpp",
        ROOT / "windows" / "runner" / "flutter_window.cpp",
    ]

    for path in candidates:
        if not path.exists():
            continue

        text = path.read_text(encoding="utf-8")
        text = text.replace('L"Runner"', 'L"VideoForge"')
        text = text.replace('L"videoforge"', 'L"VideoForge"')
        path.write_text(text, encoding="utf-8")


def main() -> int:
    if shutil.which("flutter") is None:
        print(
            "ОШИБКА: Flutter не найден. Установите Flutter 3.38.1+ "
            "и добавьте flutter/bin в PATH.",
            file=sys.stderr,
        )
        return 2

    missing = [
        platform
        for platform in PLATFORMS
        if not (ROOT / platform).is_dir()
    ]

    if missing:
        with tempfile.TemporaryDirectory(
            prefix="videoforge_flutter_"
        ) as temporary:
            scaffold = Path(temporary) / "videoforge"

            run([
                "flutter",
                "create",
                "--no-pub",
                "--platforms=" + ",".join(PLATFORMS),
                "--org",
                "com.videoforge",
                "--project-name",
                "videoforge",
                str(scaffold),
            ])

            for platform in missing:
                source = scaffold / platform

                if not source.is_dir():
                    raise RuntimeError(
                        f"Flutter не создал платформу: {platform}"
                    )

                shutil.copytree(source, ROOT / platform)

            metadata = scaffold / ".metadata"

            if metadata.exists() and not (ROOT / ".metadata").exists():
                shutil.copy2(metadata, ROOT / ".metadata")

            gitignore = scaffold / ".gitignore"

            if gitignore.exists() and not (ROOT / ".gitignore").exists():
                shutil.copy2(gitignore, ROOT / ".gitignore")

    set_android_target()
    set_ios_target()
    set_macos_target()
    set_windows_title()

    print(
        "Платформенные проекты готовы. "
        "Теперь выполните: flutter pub get"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        print(
            f"Команда завершилась с кодом {error.returncode}.",
            file=sys.stderr,
        )
        raise SystemExit(error.returncode)
