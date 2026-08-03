Write-Host "KRISTAL LABORATORIAL - Build Windows Release" -ForegroundColor Cyan

flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter analyze encontrou erros. Corrija antes do build." -ForegroundColor Red
  exit $LASTEXITCODE
}

flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$release = "build\windows\x64\runner\Release"

if (!(Test-Path "$release\drivers")) {
  New-Item -Path "$release\drivers" -ItemType Directory -Force | Out-Null
}
if (!(Test-Path "$release\scripts")) {
  New-Item -Path "$release\scripts" -ItemType Directory -Force | Out-Null
}

Copy-Item -Path "drivers\*" -Destination "$release\drivers" -Recurse -Force
Copy-Item -Path "scripts\install_drivers.ps1" -Destination "$release\scripts" -Force
Copy-Item -Path "scripts\install_drivers_admin.bat" -Destination "$release\scripts" -Force

Write-Host "Build concluido em: $release" -ForegroundColor Green
Write-Host "EXE do app: $release\kristal_laboratorial.exe" -ForegroundColor Green
