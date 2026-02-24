@echo off
echo Roy Kent restarting...
cd /d "%~dp0"

REM ── Chiudi istanze precedenti ─────────────────────────────
echo Chiudo processi esistenti...

REM Chiudi finestre cmd con titolo Roy Kent
taskkill /fi "WindowTitle eq Roy Kent Proxy :3333" /f >nul 2>&1
taskkill /fi "WindowTitle eq Roy Kent Dashboard :8080" /f >nul 2>&1

REM Libera le porte (node su 3333, python su 8080)
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":3333 " ^| findstr LISTENING') do (
  taskkill /pid %%p /f >nul 2>&1
)
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8080 " ^| findstr LISTENING') do (
  taskkill /pid %%p /f >nul 2>&1
)

REM Breve pausa per assicurarsi che le porte siano libere
timeout /t 2 /nobreak >nul
echo Porte liberate.

REM ── Carica .env se esiste ─────────────────────────────────
if exist .env (
  for /f "tokens=1,2 delims==" %%a in (.env) do set %%a=%%b
)

REM ── Installa dipendenze proxy se mancano ──────────────────
if not exist node_modules (
  echo Installing dependencies...
  npm install
)

REM ── Avvia proxy Node ──────────────────────────────────────
start "Roy Kent Proxy :3333" cmd /k "node proxy.js"

REM ── Avvia server dashboard ────────────────────────────────
start "Roy Kent Dashboard :8080" cmd /k "python -m http.server 8080 --directory C:\Users\aed1450\Documents\GitHub\Agent-Roy\dashboard"

REM ── Aspetta che i server siano pronti ─────────────────────
timeout /t 3 /nobreak >nul

REM ── Apri browser ──────────────────────────────────────────
start http://localhost:8080/roy_kent_dashboard.html

echo.
echo Proxy    → http://localhost:3333
echo Dashboard→ http://localhost:8080/roy_kent_dashboard.html
echo.
echo Chiudi le due finestre nere per fermare tutto.
pause
