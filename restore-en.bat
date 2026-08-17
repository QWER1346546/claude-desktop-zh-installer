@echo off
:: Claude Desktop Chinese Language Pack - uninstall entry

chcp 65001 >nul
setlocal

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges, click [Yes] in the popup...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply.ps1" -Uninstall

echo.
echo Press any key to close...
pause >nul
