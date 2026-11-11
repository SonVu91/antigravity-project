# Cardano Air-Gap Dual-Wallet Workbench Launcher (PowerShell)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[CARDANO AIR-GAP] KHỞI CHẠY MÔI TRƯỜNG GIẢ LẬP VÍ KÉP (WORKBENCH)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) {
    $pythonExe = "python"
}

Write-Host "[1/2] Đang khởi động Cardano Native Core Auxiliary Service (:5050)..." -ForegroundColor Yellow
$auxProcess = Start-Process -FilePath $pythonExe -ArgumentList "$ScriptDir\cardano_auxiliary_service.py" -PassThru -WindowStyle Minimized

Start-Sleep -Seconds 1

Write-Host "[2/2] Đang khởi động Web Workbench Servers (:8080, :8081, :8082)..." -ForegroundColor Green
try {
    & $pythonExe "$ScriptDir\serve_wallets.py"
} finally {
    if ($auxProcess -and -not $auxProcess.HasExited) {
        Stop-Process -Id $auxProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
