@echo off
chcp 65001 >nul
title Kiem Tra He Thong - Cardano & Midnight AI Sentinel

echo ==============================================================================
echo       KIEM TRA KET NOI VA CHU TRINH THI TRUONG THUC TE (DEMO)
echo ==============================================================================
echo.

cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo [LOI] Khong tim thay moi truong ao venv!
    pause
    exit /b 1
)

echo [1/2] Dang chay kiem tra ket noi API va 2 chu ky quet thi truong...
echo.
.\venv\Scripts\python.exe run_demo.py
echo.

echo ==============================================================================
echo [2/3] Chay bo kiem thu Supply & Demand Engine (7 test cases)...
echo ==============================================================================
echo.
.\venv\Scripts\python.exe -m unittest tests/test_supply_demand.py -v
echo.

echo ==============================================================================
echo [3/4] Chay bo kiem thu he thong tu dong (18 test cases)...
echo ==============================================================================
echo.
.\venv\Scripts\python.exe -m unittest tests/test_system.py -v
echo.

echo ==============================================================================
echo [4/4] Chay bo kiem thu Bao cao Tai san & PnL (4 test cases)...
echo ==============================================================================
echo.
.\venv\Scripts\python.exe -m unittest tests/test_portfolio_reporting.py -v
echo.

pause
