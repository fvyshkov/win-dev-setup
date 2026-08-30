@echo off
REM setup-dev-environment.bat
REM Double-click this file. It runs the PowerShell script next to it.
REM No need to open PowerShell yourself.

setlocal
set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%setup-dev-environment.ps1"

if not exist "%PS1_FILE%" (
    echo ERROR: setup-dev-environment.ps1 not found.
    echo It must sit in the same folder as this .bat file.
    pause
    exit /b 1
)

echo Running the setup script via PowerShell...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%" %*
set "RC=%ERRORLEVEL%"

echo.
echo Exit code: %RC%
echo Press any key to close this window.
pause >nul
exit /b %RC%
