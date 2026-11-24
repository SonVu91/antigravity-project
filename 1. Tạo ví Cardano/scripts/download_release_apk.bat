@echo off
chcp 65001 >nul
title Antigravity - Tai APK Release v2.0.17 tu GitHub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_release_apk.ps1"
echo.
pause
