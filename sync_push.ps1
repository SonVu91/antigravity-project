<#
.SYNOPSIS
    Kịch bản tự động gom tất cả thay đổi của mọi dự án, tạo commit và đẩy lên GitHub.
#>

param(
    [string]$CommitMessage = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Antigravity - Đẩy dữ liệu lên GitHub (PUSH)"

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
Write-Host "   ANTIGRAVITY MULTI-DEVICE SYNC - ĐẨY DỮ LIỆU LÊN GITHUB  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Thư mục gốc: $repoRoot" -ForegroundColor Gray

# Kiểm tra remote
$remotes = & $git -C $repoRoot remote -v 2>$null
if (-not $remotes) {
    Write-Host "[!] Chưa cấu hình remote GitHub cho thư mục này." -ForegroundColor Red
    Write-Host "Vui lòng chạy lệnh: git remote add origin https://github.com/SonVu91/antigravity-project.git" -ForegroundColor Yellow
    exit 1
}

# Kiểm tra thay đổi cục bộ
$status = & $git -C $repoRoot status --porcelain
if (-not $status) {
    Write-Host "`n[i] Không phát hiện thay đổi nào chưa commit. Đang kiểm tra xem có commit nào chưa đẩy không..." -ForegroundColor Yellow
    $hasRemoteBranch = & $git -C $repoRoot rev-parse --verify origin/main 2>$null
    if ($hasRemoteBranch) {
        $unpushed = & $git -C $repoRoot log origin/main..HEAD --oneline 2>$null
    } else {
        $unpushed = & $git -C $repoRoot log --oneline 2>$null
    }

    if (-not $unpushed) {
        Write-Host "[v] Toàn bộ dữ liệu của bạn ĐÃ ĐƯỢC ĐỒNG BỘ ĐẦY ĐỦ lên GitHub!" -ForegroundColor Green
        Write-Host ""
        exit 0
    } else {
        Write-Host "[*] Phát hiện các commit cục bộ chưa được đẩy lên GitHub." -ForegroundColor Cyan
    }
}

# Nếu có thay đổi, gom và commit
if ($status) {
    Write-Host "`n[*] Đang gom tất cả các tệp mới và thay đổi..." -ForegroundColor Yellow
    & $git -C $repoRoot add -A

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $CommitMessage = "sync: update projects data at $now"
        
        Write-Host "Nhập mô tả nội dung commit (hoặc nhấn ENTER để dùng mặc định '$CommitMessage'): " -ForegroundColor Cyan -NoNewline
        $inputMsg = Read-Host
        if (-not [string]::IsNullOrWhiteSpace($inputMsg)) {
            $CommitMessage = $inputMsg
        }
    }

    Write-Host "[*] Đang tạo commit: '$CommitMessage'..." -ForegroundColor Yellow
    & $git -C $repoRoot commit -m "$CommitMessage"
}

Write-Host "`n[*] Đang đẩy (push) lên GitHub: origin main..." -ForegroundColor Yellow
Write-Host "[i] Nếu đây là lần đầu tiên, trình duyệt sẽ mở ra để bạn xác nhận đăng nhập GitHub." -ForegroundColor Gray

& $git -C $repoRoot push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[v] CHÚC MỪNG! Toàn bộ dự án đã được đồng bộ lên GitHub thành công!" -ForegroundColor Green
    Write-Host "[i] Bạn có thể sang bất kỳ máy tính nào khác và chạy 'sync_pull.bat' để tiếp tục làm việc." -ForegroundColor Cyan
} else {
    Write-Host "`n[!] Quá trình đẩy gặp sự cố. Vui lòng kiểm tra kết nối mạng hoặc thông tin đăng nhập GitHub." -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
