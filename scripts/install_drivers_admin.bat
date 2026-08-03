@echo off
set APPDIR=%~dp0..
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install_drivers.ps1" -AppDir "%APPDIR%"
pause
