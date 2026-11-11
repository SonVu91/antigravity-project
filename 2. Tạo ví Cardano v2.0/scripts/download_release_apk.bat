@echo off
chcp 65001 >nul
title Antigravity - Tai APK Cold Wallet v2.0.5 32-bit tu GitHub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_release_apk.ps1"
echo.
pause
