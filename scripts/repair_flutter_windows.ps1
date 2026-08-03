Write-Host "KRISTAL LABORATORIAL - Reparar projeto Windows Flutter" -ForegroundColor Cyan

flutter config --enable-windows-desktop
flutter create --platforms=windows .
flutter clean
flutter pub get

Write-Host "Reparo concluido. Agora rode flutter analyze." -ForegroundColor Green
