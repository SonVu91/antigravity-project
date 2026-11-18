@echo off
chcp 65001 > nul
title Cardano Air-Gap Dual-Wallet Workbench Launcher
echo ==============================================================================
echo [CARDANO AIR-GAP] KHỞI CHẠY MÔI TRƯỜNG GIẢ LẬP VÍ KÉP (WORKBENCH)
echo ==============================================================================
echo.

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo [1/3] Đang kiểm tra Python...
where python > nul 2>&1
if errorlevel 1 (
    echo [LỖI] Không tìm thấy Python trong hệ thống PATH!
    pause
    exit /b 1
)

echo [2/3] Đang khởi chạy Native Core Auxiliary Service (Cổng 5050)...
start "Cardano Auxiliary API" /min python "%SCRIPT_DIR%cardano_auxiliary_service.py"

echo [3/3] Đang khởi chạy Web Workbench & Dual-Wallet Simulator (Cổng 8080)...
python "%SCRIPT_DIR%serve_wallets.py"

pause
