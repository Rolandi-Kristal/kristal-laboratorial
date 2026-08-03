@echo off
setlocal EnableExtensions
title KRISTAL LABORATORIAL - AUTOSTART USUARIO
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_autostart_usuario.ps1"
pause
endlocal
