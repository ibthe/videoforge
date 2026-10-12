#!/usr/bin/env python3
"""Generate Flutter native scaffolding and apply VideoForge platform settings."""
from __future__ import annotations

import os
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
        if re.search(r"^\s*#?\s*platform :ios,", text, flags=re.MULTILINE):
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
        text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;", text)
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
        text = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", text)
        text = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", text)
        app_gradle.write_text(text, encoding="utf-8")
    else:
        app_gradle_groovy = ROOT / "android" / "app" / "build.gradle"
        if app_gradle_groovy.exists():
            text = app_gradle_groovy.read_text(encoding="utf-8")
            text = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", text)
            app_gradle_groovy.write_text(text, encoding="utf-8")

    manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if manifest.exists():
        text = manifest.read_text(encoding="utf-8")
        text = re.sub(r'android:label="[^"]+"', 'android:label="VideoForge"', text, count=1)
        manifest.write_text(text, encoding="utf-8")


def set_macos_target() -> None:
    project = ROOT / "macos" / "Runner.xcodeproj" / "project.pbxproj"
    if project.exists():
        text = project.read_text(encoding="utf-8")
        text = re.sub(r"MACOSX_DEPLOYMENT_TARGET = [0-9.]+;", "MACOSX_DEPLOYMENT_TARGET = 10.15;", text)
        text = text.replace("PRODUCT_NAME = Runner;", "PRODUCT_NAME = VideoForge;")
        project.write_text(text, encoding="utf-8")

    info = ROOT / "macos" / "Runner" / "Info.plist"
    if info.exists():
        text = info.read_text(encoding="utf-8")
        text = re.sub(r"(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)", r"\1VideoForge\2", text)
        info.write_text(text, encoding="utf-8")

    # The macOS app writes to ~/Movies/Processed. Keep the sandbox enabled but
    # grant the specific Movies-folder entitlement that this feature requires.
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        entitlements = ROOT / "macos" / "Runner" / name
        add_plist_bool(entitlements, "com.apple.security.assets.movies.read-write")


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
        print("ОШИБКА: Flutter не найден. Установите Flutter 3.38.1+ и добавьте flutter/bin в PATH.", file=sys.stderr)
        return 2

    missing = [platform for platform in PLATFORMS if not (ROOT / platform).is_dir()]
    if missing:
        with tempfile.TemporaryDirectory(prefix="videoforge_flutter_") as temporary:
            scaffold = Path(temporary) / "videoforge"
            run([
                "flutter", "create", "--no-pub",
                "--platforms=" + ",".join(PLATFORMS),
                "--org", "com.videoforge",
                "--project-name", "videoforge",
                str(scaffold),
            ])
            for platform in missing:
                source = scaffold / platform
                if not source.is_dir():
                    raise RuntimeError(f"Flutter не создал платформу: {platform}")
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

    print("Платформенные проекты готовы. Теперь выполните: flutter pub get")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        print(f"Команда завершилась с кодом {error.returncode}.", file=sys.stderr)
        raise SystemExit(error.returncode)
