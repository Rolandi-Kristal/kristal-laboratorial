@echo off
setlocal
set BASE=C:\kristal_laboratorial
mkdir "%BASE%\externos\sire" 2>nul
mkdir "%BASE%\externos\hyper_terminal" 2>nul
copy /Y "externos\sire\FaturamentoSIRE.exe" "%BASE%\externos\sire\FaturamentoSIRE.exe"
copy /Y "externos\sire\FaturamentoSIRE_Externos.exe" "%BASE%\externos\sire\FaturamentoSIRE_Externos.exe"
copy /Y "externos\hyper_terminal\HyperTerminal.rar" "%BASE%\externos\hyper_terminal\HyperTerminal.rar"
echo Integrações externas copiadas com sucesso.
pause
