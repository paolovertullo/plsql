@echo off
echo Roy Kent starting...
cd /d "%~dp0"

REM Carica .env se esiste
if exist .env (
  for /f "tokens=1,2 delims==" %%a in (.env) do set %%a=%%b
)

REM Installa dipendenze proxy se mancano
if not exist node_modules (
  echo Installing dependencies...
  npm install
)

REM Avvia proxy Node
start "Roy Kent Proxy :3333" cmd /k "node proxy.js"

REM Avvia server dashboard
start "Roy Kent Dashboard :8080" cmd /k "python -m http.server 8080 --directory C:\Users\aed1450\Documents\GitHub\Agent-Roy\dashboard"

REM Aspetta che i server siano pronti
timeout /t 3 /nobreak >nul

REM Apri browser
start http://localhost:8080/roy_kent_dashboard.html

echo.
echo Proxy    → http://localhost:3333
echo Dashboard→ http://localhost:8080/roy_kent_dashboard.html
echo.
echo Chiudi le due finestre nere per fermare tutto.
pause
