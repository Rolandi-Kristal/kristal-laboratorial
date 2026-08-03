@echo off
chcp 65001 >nul
cls
echo =====================================================
echo    KRISTAL LABORATORIAL - BUILD WINDOWS
echo =====================================================
echo.
flutter config --enable-windows-desktop
flutter clean
flutter pub get
flutter analyze
flutter run -d windows
pause
