
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
    """Ensure both macOS signing configurations contain the required sandbox entitlements."""
    runner_dir = project_root / "macos" / "Runner"
    runner_dir.mkdir(parents=True, exist_ok=True)

    required_entitlements = {
        # Required by file_picker when opening user-selected files.
        "com.apple.security.files.user-selected.read-only": True,
        # Lets the sandboxed app save processed files in ~/Movies/Processed_New.
        "com.apple.security.assets.movies.read-write": True,
    }

    for filename in ("DebugProfile.entitlements", "Release.entitlements"):
        path = runner_dir / filename

        if path.exists():
            try:
                entitlements = plistlib.loads(path.read_bytes())
            except Exception as error:
                raise RuntimeError(
                    f"Не удалось прочитать entitlements {path}: {error}"
                ) from error
        else:
            # Create a minimal valid sandbox entitlement file if Flutter's
            # generated template ever stops providing it.
            entitlements = {"com.apple.security.app-sandbox": True}

        entitlements["com.apple.security.app-sandbox"] = True
        entitlements.update(required_entitlements)

        path.write_bytes(
            plistlib.dumps(
                entitlements,
                fmt=plistlib.FMT_XML,
                sort_keys=False,
            )
        )
        print(f"Entitlements обновлены: {path.relative_to(project_root)}")


def ensure_macos_code_sign_entitlements(project_root: Path) -> None:
    """Explicitly connect Runner build configurations to the right entitlement files."""
    project = project_root / "macos" / "Runner.xcodeproj" / "project.pbxproj"
    if not project.exists():
        raise RuntimeError(f"Не найден Xcode-проект macOS: {project}")

    text = project.read_text(encoding="utf-8")
    configurations = {
        "Debug": "Runner/DebugProfile.entitlements",
        "Profile": "Runner/DebugProfile.entitlements",
        "Release": "Runner/Release.entitlements",
    }

    for configuration, entitlement_path in configurations.items():
        # Match only the Runner target's configuration. Flutter's template
        # references Runner/Configs/AppInfo.xcconfig in these three blocks.
        pattern = re.compile(
            rf"(?P<head>[0-9A-Fa-f]+ /\* {configuration} \*/ = \{{\s*"
            rf"isa = XCBuildConfiguration;\s*"
            rf"baseConfigurationReference = [^;]*AppInfo\.xcconfig[^;]*;\s*"
            rf"buildSettings = \{{)"
            rf"(?P<settings>.*?)"
            rf"(?P<tail>\n\s*\}};\s*name = {configuration};\s*\}})",
            flags=re.DOTALL,
        )

        def update_settings(match: re.Match[str]) -> str:
            settings = match.group("settings")
            assignment = f"CODE_SIGN_ENTITLEMENTS = {entitlement_path};"
            if re.search(r"(?m)^\s*CODE_SIGN_ENTITLEMENTS\s*=\s*[^;]+;", settings):
                settings = re.sub(
                    r"(?m)^(\s*)CODE_SIGN_ENTITLEMENTS\s*=\s*[^;]+;",
                    lambda m: f"{m.group(1)}{assignment}",
                    settings,
                    count=1,
                )
            else:
                settings = settings.rstrip() + f"\n\t\t\t\t{assignment}\n\t\t\t"
            return match.group("head") + settings + match.group("tail")

        text, count = pattern.subn(update_settings, text, count=1)
        if count != 1:
            raise RuntimeError(
                f"Не удалось настроить CODE_SIGN_ENTITLEMENTS для Runner ({configuration}). "
                "Ожидался стандартный Flutter Xcode project."
            )

    project.write_text(text, encoding="utf-8")
    print("Xcode: entitlement-файлы явно подключены для Debug/Profile/Release.")


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
        manifest.write_text(text, encoding="utf-8")


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

    # Do this after Flutter generates/copies the macOS scaffold so the files
    # used by the actual Xcode target—not a temporary template—are updated.
    ensure_macos_file_picker_entitlements(ROOT)
    ensure_macos_code_sign_entitlements(ROOT)


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
