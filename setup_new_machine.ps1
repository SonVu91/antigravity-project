<#
.SYNOPSIS
    Kịch bản 1-click thiết lập môi trường Antigravity khi mở trên máy tính mới.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Antigravity - Thiết lập máy tính mới (Setup)"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   ANTIGRAVITY - THIẾT LẬP MÔI TRƯỜNG TRÊN MÁY TÍNH MỚI   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Tìm và cấu hình Git
Write-Host "[1/4] Kiểm tra Git..." -ForegroundColor Yellow
$git = "git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $fallbackPaths = @(
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe"
    )
    foreach ($path in $fallbackPaths) {
        if (Test-Path $path) {
            $git = $path
            $env:Path = (Split-Path $path) + ";" + $env:Path
            break
        }
    }
}

if (-not (Get-Command $git -ErrorAction SilentlyContinue)) {
    Write-Host "[X] Chưa tìm thấy Git trên máy tính này!" -ForegroundColor Red
    Write-Host "Vui lòng tải và cài đặt Git tại: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
} else {
    $gitVer = & $git --version
    Write-Host " [v] Đã tìm thấy: $gitVer" -ForegroundColor Green
}

# 2. Cấu hình danh tính Git cho tài khoản SonVu91
Write-Host "`n[2/4] Cấu hình thông tin Git cho tài khoản SonVu91..." -ForegroundColor Yellow
& $git config --global user.name "SonVu91"
& $git config --global user.email "SonVu91@users.noreply.github.com"
& $git config --global credential.helper manager
Write-Host " [v] Đã đặt user.name: SonVu91" -ForegroundColor Green
Write-Host " [v] Đã đặt user.email: SonVu91@users.noreply.github.com" -ForegroundColor Green
Write-Host " [v] Đã bật Git Credential Manager để lưu phiên đăng nhập an toàn" -ForegroundColor Green

# 3. Kiểm tra các bộ công cụ lập trình cần thiết
Write-Host "`n[3/4] Kiểm tra các công cụ lập trình trên máy:" -ForegroundColor Yellow

# Flutter
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    $flutterVer = (flutter --version | Select-Object -First 1)
    Write-Host " [v] Flutter: Đã cài đặt ($flutterVer)" -ForegroundColor Green
} else {
    Write-Host " [!] Flutter: Chưa có trong PATH (cần thiết nếu bạn muốn build lại app Mobile Cold/Hot)" -ForegroundColor DarkYellow
}

# Rust
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    $cargoVer = (cargo --version)
    Write-Host " [v] Rust / Cargo: Đã cài đặt ($cargoVer)" -ForegroundColor Green
} else {
    Write-Host " [!] Rust / Cargo: Chưa có trong PATH (cần thiết nếu muốn build lại thư viện mã hóa cardano core)" -ForegroundColor DarkYellow
}

# Python
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pyVer = (python --version)
    Write-Host " [v] Python: Đã cài đặt ($pyVer)" -ForegroundColor Green
} else {
    Write-Host " [!] Python: Chưa có trong PATH (cần thiết cho các script phụ trợ workbench)" -ForegroundColor DarkYellow
}

# 4. Kiểm tra cấu hình dự án
Write-Host "`n[4/4] Kiểm tra các tệp cấu hình mẫu..." -ForegroundColor Yellow
$repoRoot = $PSScriptRoot
$exampleEnv = Join-Path $repoRoot "1. Tạo ví Cold Hot Cardano\online\config.env.example"
$targetEnv = Join-Path $repoRoot "1. Tạo ví Cold Hot Cardano\online\config.env"

if ((Test-Path $exampleEnv) -and (-not (Test-Path $targetEnv))) {
    Write-Host " [i] Đã phát hiện config.env.example. Tạo sẵn config.env từ bản mẫu..." -ForegroundColor Cyan
    Copy-Item $exampleEnv $targetEnv
    Write-Host " [v] Đã tạo config.env (vui lòng điền PROJECT_ID Blockfrost nếu bạn muốn truy vấn on-chain trực tiếp)" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " THIẾT LẬP HOÀN TẤT! Máy tính này đã sẵn sàng làm việc.   " -ForegroundColor Green
Write-Host " Bạn hãy mở thư mục này bằng Antigravity IDE để bắt đầu!   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
