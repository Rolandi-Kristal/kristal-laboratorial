Write-Host "KRISTAL LABORATORIAL - Aplicando logo e icone" -ForegroundColor Cyan

if (!(Test-Path "assets\images\logo.png")) {
  Write-Host "Logo nao encontrado em assets\images\logo.png" -ForegroundColor Red
  exit 1
}

if (!(Test-Path "windows\runner\resources\app_icon.ico")) {
  Write-Host "Icone nao encontrado em windows\runner\resources\app_icon.ico" -ForegroundColor Red
  exit 1
}

flutter clean
flutter pub get
flutter analyze

Write-Host "Logo e icone aplicados. Gere o build Windows para atualizar o executavel." -ForegroundColor Green
