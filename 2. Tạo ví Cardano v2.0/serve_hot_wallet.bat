@echo off
chcp 65001 >nul
title Cardano Web Hot Wallet Server
echo ========================================================
echo   Khởi chạy Cardano Web Hot Wallet (PWA) Local Server
echo ========================================================
python output\serve_hot_wallet.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Không tìm thấy Python trong hệ thống. Đang thử bằng python3...
    python3 output\serve_hot_wallet.py
)
pause
