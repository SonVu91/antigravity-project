@echo off
chcp 65001 >nul
title Cardano & Midnight AI Sentinel & Auto-Trader - 24/7 Bot Runner

echo ==============================================================================
echo       CARDANO & MIDNIGHT AI SENTINEL & AUTO-TRADER (PHASE 1)
echo ==============================================================================
echo.

cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo [LOI] Khong tim thay moi truong ao venv!
    echo Vui long cai dat moi truong bang lenh:
    echo python -m venv venv
    echo .\venv\Scripts\pip.exe install -r requirements.txt
    pause
    exit /b 1
)

echo [OK] Dang khoi chay AI Sentinel Bot 24/7...
echo Nhan Ctrl + C de dung he thong an toan.
echo.

.\venv\Scripts\python.exe -m src.main

pause
