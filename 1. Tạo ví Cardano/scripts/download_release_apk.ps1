$ErrorActionPreference = "Continue"

$repoOwner = "SonVu91"
$repoName = "antigravity-project"
$tag = "v2.0.5"
$apksToDownload = @(
    "cardano-hot-wallet-v2.0.5-universal.apk",
    "cardano-hot-wallet-v2.0.5-armv7.apk",
    "cardano-hot-wallet-v2.0.5-arm64.apk",
    "cardano-hot-wallet-web-v2.0.5.zip",
    "SHA256SUMS-v2.0.5.txt"
)

$outputDir = Join-Path $PSScriptRoot "..\output"
$versionDir = Join-Path $outputDir $tag
$versionApkDir = Join-Path $versionDir "apk"

foreach ($dir in @($outputDir, $versionDir, $versionApkDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/tags/$tag"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   KIEM TRA VA TAI VE APK VI NONG v2.0.5 TU GITHUB        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Dang kiem tra GitHub Release ($tag)..." -ForegroundColor Yellow

$releaseInfo = $null
try {
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "Antigravity-Downloader" } -ErrorAction SilentlyContinue
} catch {
    $releaseInfo = $null
}

if ($releaseInfo -and $releaseInfo.assets) {
    Write-Host "[v] Da tim thay ban phat hanh $tag tren GitHub!" -ForegroundColor Green
    foreach ($apkName in $apksToDownload) {
        $destPath = Join-Path $outputDir $apkName
        $asset = $releaseInfo.assets | Where-Object { $_.name -eq $apkName }
        if ($asset) {
            $downloadUrl = $asset.browser_download_url
            Write-Host "[*] Dang tai $apkName tu GitHub Release..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $downloadUrl -OutFile $destPath -UseBasicParsing
            
            $fileBytes = (Get-Item $destPath).Length
            $fileMb = [math]::Round($fileBytes / 1048576, 2)
            Write-Host "[v] TAI THANH CONG: $apkName ($fileMb MB)" -ForegroundColor Green

            Copy-Item -Path $destPath -Destination (Join-Path $versionDir $apkName) -Force
            if ($apkName.EndsWith(".apk")) {
                Copy-Item -Path $destPath -Destination (Join-Path $versionApkDir $apkName) -Force
            }
        } else {
            Write-Host "[!] Asset $apkName chua san sang." -ForegroundColor Yellow
        }
    }
    
    $universalCold = Join-Path $outputDir "cardano-cold-wallet-v2.0.5-universal.apk"
    $standardCold = Join-Path $outputDir "cardano-cold-wallet-v2.0.5.apk"
    if (Test-Path $universalCold) {
        Copy-Item -Path $universalCold -Destination $standardCold -Force
        Copy-Item -Path $universalCold -Destination (Join-Path $versionDir "cardano-cold-wallet-v2.0.5.apk") -Force
        Copy-Item -Path $universalCold -Destination (Join-Path $versionApkDir "cardano-cold-wallet-v2.0.5.apk") -Force
        Write-Host "[v] Da tao ban Universal mac dinh: cardano-cold-wallet-v2.0.5.apk" -ForegroundColor Green
    }

    $universalHot = Join-Path $outputDir "cardano-hot-wallet-v2.0.5-universal.apk"
    $standardHot = Join-Path $outputDir "cardano-hot-wallet-v2.0.5.apk"
    if (Test-Path $universalHot) {
        Copy-Item -Path $universalHot -Destination $standardHot -Force
        Copy-Item -Path $universalHot -Destination (Join-Path $versionDir "cardano-hot-wallet-v2.0.5.apk") -Force
        Copy-Item -Path $universalHot -Destination (Join-Path $versionApkDir "cardano-hot-wallet-v2.0.5.apk") -Force
        Write-Host "[v] Da tao ban Universal mac dinh: cardano-hot-wallet-v2.0.5.apk" -ForegroundColor Green
    }

    # Extract Web Bundle if present
    $hotWebZip = Join-Path $outputDir "cardano-hot-wallet-web-v2.0.5.zip"
    if (Test-Path $hotWebZip) {
        $hotWebDest = Join-Path $outputDir "web_hot_wallet"
        Expand-Archive -Path $hotWebZip -DestinationPath $hotWebDest -Force
        Write-Host "[v] Da giai nen Web Hot Wallet v2.0.5 vao output\web_hot_wallet" -ForegroundColor Green
    }
    
    Write-Host "Toan bo file da duoc luu tai thu muc: $outputDir va $versionDir" -ForegroundColor Cyan
} else {
    Write-Host "[!] Ban phat hanh $tag chua co tren GitHub Releases." -ForegroundColor Yellow
}
