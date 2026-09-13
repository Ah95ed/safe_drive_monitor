# DriveAlert Automated Pre-Build Security Audit Script
# Scans source code and assets for secrets, private keys, raw models, and insecure configurations.

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       DriveAlert Pre-Build Security Audit        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$hasCriticalFailure = $false
$violations = @()

# 1. Verify Model Asset in Assets
Write-Host "`n[Audit 1/6] Verifying presence of official TFLite model asset..."
$modelFile = "assets/models/eye_detector_5n_320_float16.tflite"
if (Test-Path $modelFile) {
    $size = (Get-Item $modelFile).Length
    Write-Host "  PASSED: Official TFLite model asset present ($size bytes)." -ForegroundColor Green
} else {
    $hasCriticalFailure = $true
    $violations += "[CRITICAL] Required TFLite model asset not found at: $modelFile"
}

# 2. Check for Private Keys in Versioned Directories
Write-Host "`n[Audit 2/6] Checking for private cryptographic keys in codebase..."
$privateKeyMatches = Select-String -Path @("lib\*", "android\app\src\*", "assets\*") -Pattern "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" -ErrorAction SilentlyContinue
if ($privateKeyMatches) {
    $hasCriticalFailure = $true
    foreach ($m in $privateKeyMatches) {
        $violations += "[CRITICAL] Private key detected in: $($m.Path):$($m.LineNumber)"
    }
} else {
    Write-Host "  PASSED: Zero private keys found in codebase." -ForegroundColor Green
}

# 3. Check for Hardcoded Secrets in Android BuildConfig / Kotlin
Write-Host "`n[Audit 3/6] Checking for hardcoded secrets in Android Gradle and Kotlin..."
$secretMatches = Select-String -Path @("android\app\build.gradle.kts", "android\app\src\main\kotlin\*.kt") -Pattern "MODEL_AES_KEY|CLOUDFLARE_API_TOKEN|R2_SECRET_KEY|DOWNLOAD_TOKEN_SECRET" -ErrorAction SilentlyContinue
$leakedSecrets = $secretMatches | Where-Object { $_.Line -match "buildConfigField.*(MODEL_AES_KEY|DOWNLOAD_TOKEN_SECRET)" -or $_.Line -match "const val.*(CLOUDFLARE|SECRET)" }
if ($leakedSecrets) {
    $hasCriticalFailure = $true
    foreach ($m in $leakedSecrets) {
        $violations += "[CRITICAL] Hardcoded secret field detected in Android source: $($m.Path):$($m.LineNumber)"
    }
} else {
    Write-Host "  PASSED: Zero secrets embedded in Android build configuration." -ForegroundColor Green
}

# 4. Check Android Manifest Security Directives
Write-Host "`n[Audit 4/6] Auditing AndroidManifest.xml security configuration..."
$manifestContent = Get-Content "android\app\src\main\AndroidManifest.xml" -Raw
if ($manifestContent -match 'android:allowBackup="true"' -or $manifestContent -notmatch 'android:allowBackup="false"') {
    $hasCriticalFailure = $true
    $violations += "[HIGH] AndroidManifest.xml must set android:allowBackup=`"false`""
} else {
    Write-Host "  PASSED: android:allowBackup=`"false`" is enforced." -ForegroundColor Green
}

if ($manifestContent -match 'android:usesCleartextTraffic="true"' -or $manifestContent -notmatch 'android:usesCleartextTraffic="false"') {
    $hasCriticalFailure = $true
    $violations += "[HIGH] AndroidManifest.xml must set android:usesCleartextTraffic=`"false`""
} else {
    Write-Host "  PASSED: android:usesCleartextTraffic=`"false`" is enforced." -ForegroundColor Green
}

if ($manifestContent -notmatch 'android:networkSecurityConfig="@xml/network_security_config"') {
    $hasCriticalFailure = $true
    $violations += "[HIGH] AndroidManifest.xml is missing networkSecurityConfig declaration."
} else {
    Write-Host "  PASSED: Network Security Configuration is declared." -ForegroundColor Green
}

# 5. Check Gitignore for Secrets and Symbols
Write-Host "`n[Audit 5/6] Verifying .gitignore protection..."
$gitignoreContent = Get-Content ".gitignore" -Raw
$requiredIgnores = @("secrets/", "*.local.env", "private_build_symbols/")
foreach ($item in $requiredIgnores) {
    if ($gitignoreContent -notmatch [regex]::Escape($item)) {
        $hasCriticalFailure = $true
        $violations += "[HIGH] .gitignore is missing critical entry: $item"
    }
}
if (-not $hasCriticalFailure) {
    Write-Host "  PASSED: Secrets and private obfuscation symbols are properly ignored." -ForegroundColor Green
}

# 6. Check Insecure HTTP URLs in Dart Code
Write-Host "`n[Audit 6/6] Checking for insecure cleartext (http://) URLs in Dart code..."
$httpMatches = Select-String -Path "lib\*.dart" -Pattern "http://(?!localhost|127\.0\.0\.1)" -ErrorAction SilentlyContinue
if ($httpMatches) {
    foreach ($m in $httpMatches) {
        $violations += "[MEDIUM] Insecure cleartext HTTP URL in: $($m.Path):$($m.LineNumber)"
    }
    $hasCriticalFailure = $true
} else {
    Write-Host "  PASSED: All Dart network endpoints use strict HTTPS." -ForegroundColor Green
}

# Output Results
Write-Host "`n==================================================" -ForegroundColor Cyan
if ($hasCriticalFailure) {
    Write-Host "  SECURITY AUDIT FAILED! Violations detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    Write-Host "==================================================" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "  ALL PRE-BUILD SECURITY AUDITS PASSED CLEANLY!  " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Cyan
    exit 0
}
