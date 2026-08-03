@echo off
setlocal EnableExtensions
title KRISTAL LABORATORIAL - SERVIDOR LOCAL HMR
color 0A
cd /d "%~dp0"

python gerar_segredos_portal.py
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | ForEach-Object { Write-Host ('IP para acesso na rede: http://' + $_.IPAddress + ':8787') }"

echo.
echo Servidor KRISTAL LABORATORIAL sera iniciado no mesmo IP da KRISTAL OPERACIONAL, porta 8787
echo Estacoes da rede HMR devem acessar usando o IP de apontamento da KRISTAL OPERACIONAL e a porta 8787.
echo.

if not exist .venv\Scripts\python.exe (
  python -m venv .venv
  if errorlevel 1 exit /b 1
)

call .venv\Scripts\activate.bat
python -m pip install -r requirements.txt
if errorlevel 1 exit /b 1

set KRISTAL_PORTAL_HOST=0.0.0.0
set KRISTAL_PORTAL_PORT=8787
python main.py
endlocal
