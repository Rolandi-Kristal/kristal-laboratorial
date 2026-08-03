@echo off
title KRISTAL LABORATORIAL - INSTALAR PORTAL WEB
color 0A
where python >nul 2>nul
if errorlevel 1 (
  echo Python 3.11+ nao encontrado.
  pause
  exit /b 1
)
if not exist .env copy .env.example .env
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
echo Instalacao concluida.
pause
