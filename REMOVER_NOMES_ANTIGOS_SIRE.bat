@echo off
setlocal

set OLD1=C:\kristal_laboratorial\externos\sire\FaturamentoSIRE.exe
set OLD2=C:\kristal_laboratorial\externos\sire\FaturamentoSIRE_Externos.exe
set OLDDIR=C:\kristal_laboratorial\externos\sire

if exist "%OLD1%" del /F /Q "%OLD1%"
if exist "%OLD2%" del /F /Q "%OLD2%"

echo Nomes antigos removidos da pasta externa visivel.
echo Mantenha somente C:\kristal_laboratorial\integracoes\kristal_sire
pause
