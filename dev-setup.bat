@echo off
REM ---------------------------------------------------------------
REM  dev-setup.bat - one click, nothing else to download.
REM  Fetches the setup script from the web and runs it.
REM ---------------------------------------------------------------

setlocal
set "URL=https://win-dev-setup.onrender.com/setup.ps1"
set "TARGET=%TEMP%\dev-setup-script.ps1"

echo.
echo   Fetching the setup script ...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri $env:URL -OutFile $env:TARGET -UseBasicParsing; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo   Could not download the setup script.
    echo   Check your internet connection and run this file again.
    echo.
    echo   Press any key to close.
    pause >nul
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
set "RC=%ERRORLEVEL%"

del /q "%TARGET%" 2>nul

echo   Press any key to close this window.
pause >nul
exit /b %RC%
