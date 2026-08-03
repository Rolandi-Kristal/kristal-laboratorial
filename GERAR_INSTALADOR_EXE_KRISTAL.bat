@echo off
title KRISTAL LABORATORIAL - GERAR INSTALADOR EXE
color 0B

echo ============================================================
echo     KRISTAL LABORATORIAL - GERADOR DO INSTALADOR .EXE
echo ============================================================
echo.

cd /d C:\kristal_laboratorial

if not exist "scripts\build_installer_inno.ps1" (
    echo ERRO: scripts\build_installer_inno.ps1 nao encontrado.
    echo Copie os scripts da etapa do instalador para a pasta do projeto.
    pause
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\scripts\build_installer_inno.ps1"

if exist "C:\kristal_laboratorial\installer\KRISTAL_LABORATORIAL_Setup.exe" (
    echo.
    echo ============================================================
    echo INSTALADOR GERADO COM SUCESSO:
    echo C:\kristal_laboratorial\installer\KRISTAL_LABORATORIAL_Setup.exe
    echo ============================================================
    explorer "C:\kristal_laboratorial\installer"
) else (
    echo.
    echo O instalador nao foi encontrado.
    echo Verifique se o Inno Setup 6 esta instalado.
)

echo.
pause
