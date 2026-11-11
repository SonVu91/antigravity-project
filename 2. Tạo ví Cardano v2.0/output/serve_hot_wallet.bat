@echo off
title Cardano Web Hot Wallet Server
cd /d "%~dp0"
python serve_hot_wallet.py
pause
