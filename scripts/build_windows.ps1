$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter не найден. Установите Flutter 3.38.1+ и добавьте flutter/bin в PATH.'
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  throw 'Python 3 нужен для подготовки платформенных файлов.'
}

python .\scripts\prepare_platforms.py
flutter pub get
flutter build windows --release

$Release = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $Release 'videoforge.exe'))) {
  throw "Не найдено приложение в $Release"
}
$Dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$Zip = Join-Path $Dist 'VideoForge-Windows-Portable.zip'
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path (Join-Path $Release '*') -DestinationPath $Zip -CompressionLevel Optimal
Write-Host "Готово: $Zip"

$Iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($Iscc) {
  & $Iscc.Source (Join-Path $Root 'installer\VideoForge.iss')
  Write-Host 'Также создан установщик VideoForge-Windows-Setup.exe.'
} else {
  Write-Host 'Для создания обычного Setup.exe установите Inno Setup и повторно запустите этот скрипт.'
}
