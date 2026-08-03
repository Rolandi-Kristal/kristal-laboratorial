@echo off
title KRISTAL LABORATORIAL - LIMPEZA DEFINITIVA
color 0A
set ROOT=C:\kristal_laboratorial
echo Limpando padroes antigos...
if exist "%ROOT%\drivers" rmdir /s /q "%ROOT%\drivers"
if exist "%ROOT%\KRISTAL_LABORATORIAL\EQUIPAMENTOS" rmdir /s /q "%ROOT%\KRISTAL_LABORATORIAL\EQUIPAMENTOS"
echo.
echo Padrao correto:
echo %ROOT%\KRISTAL_LABORATORIAL\INTEGRACOES
pause
