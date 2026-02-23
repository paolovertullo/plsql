@echo off
echo Roy Kent Proxy starting...
cd /d "%~dp0"

REM Carica .env se esiste
if exist .env (
  for /f "tokens=1,2 delims==" %%a in (.env) do set %%a=%%b
)

REM Installa dipendenze se mancano
if not exist node_modules (
  echo Installing dependencies...
  npm install
)

REM Avvia proxy
start "Roy Kent Proxy" cmd /k "node proxy.js"

REM Aspetta 2 secondi poi apri il dashboard
timeout /t 2 /nobreak >nul
start http://localhost:8080/roy_kent_dashboard.html

echo Proxy avviato su http://localhost:3333
pause
