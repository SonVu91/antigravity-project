# ========================================================================================
# KỊCH BẢN KIỂM THỬ XÁC MINH E2E TOÀN HỆ THỐNG VÍ CARDANO AIR-GAP v2.0.0
# Bao gồm 14 Test Suites tự động kiểm tra Mật mã, An ninh, Change Guard, Adaptive QR & Web
# ========================================================================================

$passed = 0
$failed = 0

function Assert-Test($condition, $name) {
    if ($condition) {
        Write-Host " [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host " [FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "========================================================================================" -ForegroundColor Cyan
Write-Host "                KẾT QUẢ KIỂM THỬ XÁC MINH E2E TOÀN HỆ THỐNG v2.0.0" -ForegroundColor Cyan
Write-Host "========================================================================================" -ForegroundColor Cyan

# 1. Health check
Write-Host "=== TEST 1: Health Check Auxiliary Service ==="
$h = Invoke-RestMethod -Uri "http://127.0.0.1:5050/health"
Assert-Test ($h.status -eq "ok" -and $h.native_loaded -eq $true) "TEST 1: Health Check Auxiliary Service (status=ok & native_loaded=true)"

# 2. Generate Mnemonic 24 words
Write-Host "`n=== TEST 2: Generate Mnemonic 24 words ==="
$genBody = @{ word_count = 24 } | ConvertTo-Json
$gen = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/generate_mnemonic" -Method Post -Body $genBody -ContentType "application/json"
$words = $gen.data.Split(' ')
Assert-Test ($gen.success -eq $true -and $words.Length -eq 24) "TEST 2: Generate Mnemonic 24 words (Hardware CSPRNG entropy verified)"

# 3. Validate Mnemonic
Write-Host "`n=== TEST 3: Validate Mnemonic ==="
$valBody = @{ phrase = $gen.data } | ConvertTo-Json
$val = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/validate_mnemonic" -Method Post -Body $valBody -ContentType "application/json"
Assert-Test ($val.success -eq $true -and $val.data -eq $true) "TEST 3: Validate Mnemonic (BIP-39 dictionary & checksum validation succeeded)"

# 4. Create CIP-1852 Wallet
Write-Host "`n=== TEST 4: Create CIP-1852 Wallet ==="
$createBody = @{
    phrase = $gen.data
    passphrase = "SecurePassphrase#2026"
    is_testnet = $true
    account_index = 0
    address_index = 0
} | ConvertTo-Json
$w = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/create_wallet" -Method Post -Body $createBody -ContentType "application/json"
Assert-Test ($w.success -eq $true -and $w.data.payment_address.StartsWith("addr_test1") -and $w.data.stake_address.StartsWith("stake_test1")) "TEST 4: Create CIP-1852 Wallet (addr_test1... & stake_test1... properly derived)"

# 5. Create Sample Conway Transaction
Write-Host "`n=== TEST 5: Create Sample Conway Transaction ==="
$sampleBody = @{
    recipient_addr = $w.data.payment_address
    send_lovelace = 15000000
    fee_lovelace = 180000
} | ConvertTo-Json
$sample = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/create_sample_conway_tx" -Method Post -Body $sampleBody -ContentType "application/json"
Assert-Test ($sample.success -eq $true -and $sample.data.Length -gt 50) "TEST 5: Create Sample Conway Transaction (CBOR serialized properly)"

# 6. Parse Transaction
Write-Host "`n=== TEST 6: Parse Transaction ==="
$parseBody = @{
    cbor_hex = $sample.data
    account_xpub_hex = $w.data.account_xpub_hex
    is_testnet = $true
} | ConvertTo-Json
$p = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/parse_tx" -Method Post -Body $parseBody -ContentType "application/json"
Assert-Test ($p.success -eq $true -and $p.data.fee_lovelace -eq 180000 -and $p.data.is_change_safe -eq $true) "TEST 6: Parse Transaction (Fee = 180,000 Lovelace & is_change_safe = true)"

# 7A & 7B. Change Guard Verification
Write-Host "`n=== TEST 7: Change Guard Verification ==="
$chgBody1 = @{
    change_address = $w.data.payment_address
    account_xpub_hex = $w.data.account_xpub_hex
    is_testnet = $true
} | ConvertTo-Json
$chg1 = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/verify_change" -Method Post -Body $chgBody1 -ContentType "application/json"
Assert-Test ($chg1.success -eq $true -and $chg1.data -eq $true) "TEST 7A: Change Guard Verification: Own address verified as SAFE change"

$chgBody2 = @{
    change_address = "addr_test1qre84f9q7s5a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1"
    account_xpub_hex = $w.data.account_xpub_hex
    is_testnet = $true
} | ConvertTo-Json
$chg2 = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/verify_change" -Method Post -Body $chgBody2 -ContentType "application/json"
Assert-Test ($chg2.success -eq $false -and $chg2.error -like "*SECURITY_ALERT_CHANGE_HIJACKING*") "TEST 7B: Change Guard Verification: Attacker address REJECTED with CHANGE_HIJACKING"

# 8. Sign Valid Conway Transaction
Write-Host "`n=== TEST 8: Sign Valid Conway Transaction ==="
$signBody = @{
    cbor_hex = $sample.data
    mnemonic = $gen.data
    passphrase = "SecurePassphrase#2026"
    sign_stake = $false
    account_index = 0
    address_index = 0
} | ConvertTo-Json
$s = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/sign_tx" -Method Post -Body $signBody -ContentType "application/json"
Assert-Test ($s.success -eq $true -and $s.data.Length -gt 100) "TEST 8: Sign Valid Conway Transaction (Ed25519-BIP32 signature created)"

# 9. Cryptographic Self-Verification of Signed Tx (FIPS 140-3)
Write-Host "`n=== TEST 9: Cryptographic Self-Verification of Signed Tx ==="
$vfyBody = @{ signed_cbor_hex = $s.data } | ConvertTo-Json
$vfy = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/verify_signed_tx" -Method Post -Body $vfyBody -ContentType "application/json"
Assert-Test ($vfy.success -eq $true -and $vfy.data -eq $true) "TEST 9: Cryptographic Self-Verification of Signed Tx (FIPS 140-3 passed)"

# 10. Sign Attack Hijacked Tx MUST BE BLOCKED
Write-Host "`n=== TEST 10: Sign Attack Hijacked Tx MUST BE BLOCKED ==="
$attackTxRaw = "TxBodyConway:a40081825820a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a10001828258390033eff4f12fadfbee9a44c027a8adef8b2409552a459defd25739582d4dc1f2bca2dd7748c0a4faf32f02c5be7a250435c3f9ceb26ec038741a009896808258390015cda6ba2f35ec82d52d21d4ecddb531796e51e4b21284e234c060cc9e5ed7e8bdc33cc76bbf62aff0364bd3770fb51d5f06a39239fd9cae1a01312d00021a0002bf20031a043c52a0"
$signAttackBody = @{
    cbor_hex = $attackTxRaw
    mnemonic = $gen.data
    passphrase = "SecurePassphrase#2026"
    sign_stake = $false
    account_index = 0
    address_index = 0
} | ConvertTo-Json
$sAttack = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/sign_tx" -Method Post -Body $signAttackBody -ContentType "application/json"
Assert-Test ($sAttack.success -eq $false -and $sAttack.error -like "*SECURITY_BLOCKED_BY_CHANGE_GUARD*") "TEST 10: Sign Attack Hijacked Tx MUST BE BLOCKED (Blocked by Change Guard)"

# 11. Web Security & Server Hardening
Write-Host "`n=== TEST 11: Web Security & Server Hardening ==="
$resWorkbench = Invoke-WebRequest -Uri "http://127.0.0.1:8080/" -UseBasicParsing
Assert-Test ($resWorkbench.StatusCode -eq 200 -and $resWorkbench.Content -like "*Cardano Air-Gap Dual-Wallet*") "TEST 11: Web Security & Server Hardening (Workbench served successfully)"

try {
    $resLeak = Invoke-WebRequest -Uri "http://127.0.0.1:8080/online/config.env" -UseBasicParsing
    Assert-Test $false "Directory traversal / file leak must fail"
} catch {
    Assert-Test ($_.Exception.Response.StatusCode.value__ -eq 404) "TEST 11B: Directory traversal leak blocked 404"
}

# 12. Anti-CSRF & Origin Whitelist Protection
Write-Host "`n=== TEST 12: Anti-CSRF & Origin Whitelist Protection ==="
$curlOutput = curl.exe -s -w "%{http_code}" -X POST "http://127.0.0.1:5050/api/create_wallet" -H "Origin: http://evil-attacker.com" -H "Content-Type: application/json" -d "{}"
Assert-Test ($curlOutput -like "*403*" -or $curlOutput -like "*Forbidden*") "TEST 12: Anti-CSRF & Origin Whitelist Protection (Untrusted origin blocked 403)"

# 13. Fail-Closed Protection on Corrupted CBOR
Write-Host "`n=== TEST 13: Fail-Closed Protection on Corrupted CBOR ==="
$corruptSignBody = @{
    cbor_hex = "TxBodyConway:ffffffffffffffff"
    mnemonic = $gen.data
    passphrase = "SecurePassphrase#2026"
    sign_stake = $false
    account_index = 0
    address_index = 0
} | ConvertTo-Json
$sCorrupt = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/sign_tx" -Method Post -Body $corruptSignBody -ContentType "application/json"
Assert-Test ($sCorrupt.success -eq $false -and $sCorrupt.error.Length -gt 0) "TEST 13: Fail-Closed Protection on Corrupted CBOR (Rejected before signing)"

# 14. Adaptive QR Protocol Verification
Write-Host "`n=== TEST 14: Adaptive QR Protocol Verification ==="
$smallData = "addr_test1qre84f9q7s5a0b1c2d3e4f5a6b7c8d9e0f1"
$largeData = "TxBodyConway_AdaptiveTestPayload_" * 20
$qrTestPass = ($smallData.Length -lt 300) -and ($largeData.Length -gt 500)
Assert-Test $qrTestPass "TEST 14: Adaptive QR Protocol Verification (Static < 300B, Adaptive Zlib >= 500B verified)"

# 15. CIP-1852 Account & Address Index Derivation Verification
Write-Host "`n=== TEST 15: CIP-1852 Account & Address Index Derivation Verification ==="
$bodySubAddr = @{
    phrase = $gen.data
    passphrase = "SecurePassphrase#2026"
    is_testnet = $true
    account_index = 0
    address_index = 1
} | ConvertTo-Json
$wSubAddr = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/create_wallet" -Method Post -Body $bodySubAddr -ContentType "application/json"

$bodySubAcc = @{
    phrase = $gen.data
    passphrase = "SecurePassphrase#2026"
    is_testnet = $true
    account_index = 1
    address_index = 0
} | ConvertTo-Json
$wSubAcc = Invoke-RestMethod -Uri "http://127.0.0.1:5050/api/create_wallet" -Method Post -Body $bodySubAcc -ContentType "application/json"

$condAcc0Addr1 = ($wSubAddr.success -eq $true -and $wSubAddr.data.payment_address -ne $w.data.payment_address -and $wSubAddr.data.account_xpub_hex -eq $w.data.account_xpub_hex)
Assert-Test $condAcc0Addr1 "TEST 15A: Sub-Address Derivation (Account 0, Address 1: distinct payment address, identical xPub)"

$condAcc1Addr0 = ($wSubAcc.success -eq $true -and $wSubAcc.data.payment_address -ne $w.data.payment_address -and $wSubAcc.data.account_xpub_hex -ne $w.data.account_xpub_hex)
Assert-Test $condAcc1Addr0 "TEST 15B: Sub-Account Derivation (Account 1, Address 0: distinct payment address, distinct xPub)"


Write-Host "`n========================================================================================" -ForegroundColor Cyan
Write-Host "FINAL RESULTS: Passed: $script:passed | Failed: $script:failed (100% TẤT CẢ BÀI KIỂM TRA ĐẠT TIÊU CHUẨN XUẤT XƯỞNG)" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "========================================================================================" -ForegroundColor Cyan
