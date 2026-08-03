@echo off
title KRISTAL LABORATORIAL - PORTAL WEB
color 0A
if not exist .env copy .env.example .env
call .venv\Scripts\activate.bat
python main.py
pause
