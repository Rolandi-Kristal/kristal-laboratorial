Write-Host "KRISTAL LABORATORIAL - Run Debug Windows" -ForegroundColor Cyan
flutter clean
flutter pub get
flutter analyze
flutter run -d windows
