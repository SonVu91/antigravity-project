@echo off
chcp 65001 >nul
title Antigravity - Thiết lập máy tính mới

where git >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "PATH=%LOCALAPPDATA%\Programs\Git\cmd;%PATH%"
    if exist "C:\Program Files\Git\cmd\git.exe" set "PATH=C:\Program Files\Git\cmd;%PATH%"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_new_machine.ps1"

echo.
pause
