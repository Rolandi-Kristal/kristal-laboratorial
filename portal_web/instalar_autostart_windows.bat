@echo off
setlocal EnableExtensions
title KRISTAL LABORATORIAL - INSTALAR AUTOSTART
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_autostart_windows.ps1"
pause
endlocal
