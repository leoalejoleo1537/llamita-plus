@echo off
cd /d "%~dp0"
title Llamita - puente de impresion
:bucle
node puente.mjs
echo.
echo El puente se corto. Vuelvo a intentar en 10 segundos...
timeout /t 10 >nul
goto bucle
