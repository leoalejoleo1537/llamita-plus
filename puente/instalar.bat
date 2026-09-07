@echo off
cd /d "%~dp0"
echo Instalando lo que hace falta...
call npm install
if not exist config.json copy config.ejemplo.json config.json
echo.
echo Ahora completa la impresora y la sede, guarda y cierra.
notepad config.json
echo Listo. Ahora abri probar.bat
pause
