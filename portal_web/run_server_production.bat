@echo off
setlocal EnableExtensions
title KRISTAL LABORATORIAL - SERVIDOR PRODUCAO
color 0A
cd /d "%~dp0"

python gerar_segredos_portal.py
if errorlevel 1 exit /b 1

set "KRISTAL_API_KEY_VALUE="
set "KRISTAL_SECRET_KEY_VALUE="
set "KRISTAL_ADMIN_PASSWORD_VALUE="

for /f "tokens=1,* delims==" %%A in ('findstr /B /C:"KRISTAL_API_KEY=" .env') do set "KRISTAL_API_KEY_VALUE=%%B"
for /f "tokens=1,* delims==" %%A in ('findstr /B /C:"KRISTAL_SECRET_KEY=" .env') do set "KRISTAL_SECRET_KEY_VALUE=%%B"
for /f "tokens=1,* delims==" %%A in ('findstr /B /C:"KRISTAL_ADMIN_PASSWORD=" .env') do set "KRISTAL_ADMIN_PASSWORD_VALUE=%%B"

if "%KRISTAL_API_KEY_VALUE%"=="" (
  echo ERRO: KRISTAL_API_KEY nao configurada no .env.
  pause
  exit /b 1
)

if "%KRISTAL_SECRET_KEY_VALUE%"=="" (
  echo ERRO: KRISTAL_SECRET_KEY nao configurada no .env.
  pause
  exit /b 1
)

if "%KRISTAL_ADMIN_PASSWORD_VALUE%"=="" (
  echo ERRO: KRISTAL_ADMIN_PASSWORD nao configurada no .env.
  pause
  exit /b 1
)

if "%KRISTAL_SECRET_KEY_VALUE%"=="troque_por_uma_chave_forte_com_64_caracteres" (
  echo ERRO: altere KRISTAL_SECRET_KEY antes de executar em producao.
  pause
  exit /b 1
)

if "%KRISTAL_ADMIN_PASSWORD_VALUE%"=="troque_esta_senha" (
  echo ERRO: altere KRISTAL_ADMIN_PASSWORD antes de executar em producao.
  pause
  exit /b 1
)

if not exist .venv\Scripts\python.exe (
  python -m venv .venv
  if errorlevel 1 exit /b 1
)

call .venv\Scripts\activate.bat
python -m pip install -r requirements.txt
if errorlevel 1 exit /b 1

python main.py
endlocal
