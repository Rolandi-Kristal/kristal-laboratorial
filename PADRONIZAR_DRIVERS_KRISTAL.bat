@echo off
title KRISTAL LABORATORIAL - PADRONIZAR DRIVERS
color 0A

echo Padronizando pastas de drivers da KRISTAL...
echo.

set OLD1=C:\kristal_laboratorial\drivers\KRISTAL
set OLD2=C:\kristal_laboratorial\drivers\KRISTAL_LABORATORIAL\EQUIPAMENTOS\KRISTAL_ADVANCED_DLL
set NEW=C:\kristal_laboratorial\drivers\KRISTAL_LABORATORIAL\EQUIPAMENTOS\KRISTAL_ADVANCE_DLL

if exist "%OLD1%" (
  echo Removendo pasta antiga: %OLD1%
  rmdir /s /q "%OLD1%"
)

if exist "%OLD2%" (
  echo Removendo pasta antiga: %OLD2%
  rmdir /s /q "%OLD2%"
)

echo.
echo Padrao final:
echo %NEW%
echo.
pause
