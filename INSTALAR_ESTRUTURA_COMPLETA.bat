@echo off
setlocal

set ROOT=C:\kristal_laboratorial
mkdir "%ROOT%\data" 2>nul
mkdir "%ROOT%\drivers" 2>nul
mkdir "%ROOT%\backups" 2>nul
mkdir "%ROOT%\relatorios" 2>nul
mkdir "%ROOT%\exports\sire" 2>nul
mkdir "%ROOT%\logs" 2>nul
mkdir "%ROOT%\externos\sire" 2>nul
mkdir "%ROOT%\externos\hyper_terminal" 2>nul

if exist "assets\external\sire\FaturamentoSIRE.exe" (
  copy /Y "assets\external\sire\FaturamentoSIRE.exe" "%ROOT%\externos\sire\FaturamentoSIRE.exe"
)

if exist "assets\external\sire\FaturamentoSIRE_Externos.exe" (
  copy /Y "assets\external\sire\FaturamentoSIRE_Externos.exe" "%ROOT%\externos\sire\FaturamentoSIRE_Externos.exe"
)

if exist "assets\external\hyper_terminal\HyperTerminal.rar" (
  copy /Y "assets\external\hyper_terminal\HyperTerminal.rar" "%ROOT%\externos\hyper_terminal\HyperTerminal.rar"
)

echo Estrutura completa criada e SIRE copiado.
pause
