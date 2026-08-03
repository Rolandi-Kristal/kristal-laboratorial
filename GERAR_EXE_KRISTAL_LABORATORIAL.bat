@echo off
title KRISTAL LABORATORIAL - GERAR EXE
color 0A

echo ============================================================
echo        KRISTAL LABORATORIAL - GERADOR DO EXECUTAVEL
echo ============================================================
echo.

cd /d C:\kristal_laboratorial

if not exist "pubspec.yaml" (
    echo ERRO: pubspec.yaml nao encontrado em C:\kristal_laboratorial
    echo Verifique se o projeto esta realmente nesta pasta.
    pause
    exit /b 1
)

echo [1/5] Limpando projeto...
flutter clean
if errorlevel 1 (
    echo ERRO no flutter clean.
    pause
    exit /b 1
)

echo.
echo [2/5] Baixando dependencias...
flutter pub get
if errorlevel 1 (
    echo ERRO no flutter pub get.
    pause
    exit /b 1
)

echo.
echo [3/5] Analisando codigo...
flutter analyze
if errorlevel 1 (
    echo ERRO no flutter analyze. Corrija os erros antes de compilar.
    pause
    exit /b 1
)

echo.
echo [4/5] Gerando EXE Windows Release...
flutter build windows --release
if errorlevel 1 (
    echo ERRO no flutter build windows --release.
    pause
    exit /b 1
)

echo.
echo [5/5] Verificando executavel...
set EXE_PATH=C:\kristal_laboratorial\build\windows\x64\runner\Release\kristal_laboratorial.exe

if exist "%EXE_PATH%" (
    echo.
    echo ============================================================
    echo EXE GERADO COM SUCESSO:
    echo %EXE_PATH%
    echo ============================================================
    echo.
    explorer "C:\kristal_laboratorial\build\windows\x64\runner\Release"
) else (
    echo.
    echo ERRO: O executavel nao foi encontrado no caminho esperado.
    echo Verifique a pasta:
    echo C:\kristal_laboratorial\build\windows\x64\runner\Release
)

echo.
pause
