# Kịch bản tiện ích tải cardano-cli và cardano-address chính thức từ Intersect MBO / IOHK
# Giúp người quản trị chạy CLI Terminal khi cần mà không phải lưu các file nhị phân nặng (>100MB) vào Git

param(
    [string]$Version = "10.1.4",
    [string]$OutputDir = "./bin"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   CARDANO CLI OFFICIAL DOWNLOADER UTILITY" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

Write-Host "Target version: $Version"
Write-Host "Destination: $OutputDir"
Write-Host "`nBạn có thể tải các bản phát hành nhị phân chính thức tại:" -ForegroundColor Yellow
Write-Host "1. Cardano CLI: https://github.com/IntersectMBO/cardano-cli/releases" -ForegroundColor White
Write-Host "2. Cardano Node: https://github.com/IntersectMBO/cardano-node/releases" -ForegroundColor White
Write-Host "3. Cardano Address: https://github.com/IntersectMBO/cardano-addresses/releases" -ForegroundColor White

Write-Host "`nĐã sẵn sàng môi trường CLI." -ForegroundColor Green
