<#
.SYNOPSIS
    Kịch bản tự động kéo cập nhật mới nhất từ GitHub về máy tính hiện tại.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Antigravity - Đồng bộ dữ liệu từ GitHub (PULL)"

# Tìm Git executable
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

$repoRoot = $PSScriptRoot
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ANTIGRAVITY MULTI-DEVICE SYNC - KÉO DỮ LIỆU TỪ GITHUB   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Thư mục làm việc: $repoRoot" -ForegroundColor Gray

# Kiểm tra remote
$remotes = & $git -C $repoRoot remote -v 2>$null
if (-not $remotes) {
    Write-Host "[!] Chưa cấu hình remote GitHub cho thư mục này." -ForegroundColor Red
    Write-Host "Vui lòng chạy lệnh: git remote add origin https://github.com/SonVu91/antigravity-project.git" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[*] Đang kiểm tra cập nhật mới nhất từ GitHub..." -ForegroundColor Yellow
& $git -C $repoRoot fetch origin main 2>&1 | Out-Null

$status = & $git -C $repoRoot status -uno 2>&1
$behind = $status | Select-String "Your branch is behind"
$upToDate = $status | Select-String "Your branch is up to date"

if ($upToDate) {
    Write-Host "[v] Mã nguồn trên máy tính này ĐÃ LÀ MỚI NHẤT, không có cập nhật mới nào!" -ForegroundColor Green
} else {
    Write-Host "[*] Phát hiện cập nhật mới từ máy tính khác. Đang tiến hành kéo về..." -ForegroundColor Yellow
    
    # Kiểm tra dirty working tree
    $dirty = & $git -C $repoRoot status --porcelain
    $stashed = $false
    if ($dirty) {
        Write-Host "[i] Đang tạm lưu các thay đổi chưa commit vào stash..." -ForegroundColor Cyan
        & $git -C $repoRoot stash push -u -m "Auto-stashed by sync_pull $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
        $stashed = $true
    }

    $pullResult = & $git -C $repoRoot pull --rebase origin main 2>&1
    Write-Host $pullResult

    if ($stashed) {
        Write-Host "[i] Đang khôi phục lại các thay đổi cục bộ từ stash..." -ForegroundColor Cyan
        & $git -C $repoRoot stash pop | Out-Null
    }

    Write-Host "`n[v] Đồng bộ thành công! Dự án của bạn đã được cập nhật phiên bản mới nhất." -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Bạn đã sẵn sàng tiếp tục làm việc cùng Antigravity!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
