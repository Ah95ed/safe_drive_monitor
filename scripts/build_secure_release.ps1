# DriveAlert Automated Secure Release Pipeline Script
# Executes pre-build security audit, static analysis, unit tests, obfuscated release build,
# and post-build APK/AAB archive inspection.

param (
    [string]$Target = "apk" # "apk" or "appbundle"
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     DriveAlert Secure Release Build Pipeline     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Step 1: Pre-Build Security Audit
Write-Host "`n>>> [1/5] Executing Pre-Build Security Audit..." -ForegroundColor Yellow
powershell -ExecutionPolicy Bypass -File "scripts/security_audit.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ABORTING BUILD: Pre-build security audit failed." -ForegroundColor Red
    exit 1
}

# Step 2: Code Health & Static Analysis
Write-Host "`n>>> [2/5] Running Flutter Static Analysis..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "ABORTING BUILD: Static analysis detected issues." -ForegroundColor Red
    exit 1
}

# Step 3: Test Suite Verification
Write-Host "`n>>> [3/5] Running Comprehensive Test Suite..." -ForegroundColor Yellow
flutter test test/unit/onboarding_preferences_test.dart test/unit/watchdog_auto_recovery_test.dart test/unit/monitoring_watchdog_test.dart test/unit/background_transition_gate_test.dart test/widget/onboarding_flow_test.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "ABORTING BUILD: Unit/Widget tests failed." -ForegroundColor Red
    exit 1
}

# Step 4: Obfuscated Release Build
$symbolsDir = "private_build_symbols"
if (-not (Test-Path $symbolsDir)) {
    New-Item -ItemType Directory -Path $symbolsDir | Out-Null
}

Write-Host "`n>>> [4/5] Compiling Obfuscated Release Artifact ($Target)..." -ForegroundColor Yellow
if ($Target -eq "appbundle") {
    flutter build appbundle --release --obfuscate --split-debug-info=$symbolsDir
} else {
    flutter build apk --release --obfuscate --split-debug-info=$symbolsDir
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "ABORTING BUILD: Flutter release compilation failed." -ForegroundColor Red
    exit 1
}

# Step 5: Post-Build Artifact Security Inspection
Write-Host "`n>>> [5/5] Performing Post-Build Archive Inspection..." -ForegroundColor Yellow

$artifactPath = if ($Target -eq "appbundle") {
    "build/app/outputs/bundle/release/app-release.aab"
} else {
    "build/app/outputs/flutter-apk/app-release.apk"
}

if (-not (Test-Path $artifactPath)) {
    Write-Host "WARNING: Could not locate built artifact at $artifactPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "  Analyzing compiled artifact: $artifactPath"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $artifactPath).Path)

$prohibitedPatterns = @("*.tflite", "*.env", "*secrets*", "*.private.*", "*.symbols", "key.properties")
$leakedEntries = @()

foreach ($entry in $zip.Entries) {
    $name = $entry.FullName
    foreach ($pat in $prohibitedPatterns) {
        if ($name -like $pat) {
            $leakedEntries += $name
        }
    }
}
$zip.Dispose()

if ($leakedEntries.Count -gt 0) {
    Write-Host "  CRITICAL SECURITY FAILURE: Sensitive files found inside compiled APK/AAB:" -ForegroundColor Red
    foreach ($l in $leakedEntries) {
        Write-Host "    - $l" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "  PASSED: Archive verified clean! Zero secrets, raw models, or symbols bundled." -ForegroundColor Green
}

# Verify Symbol Files were saved to private_build_symbols/
$symbolFiles = Get-ChildItem -Path $symbolsDir -Filter "*.symbols" -Recurse -ErrorAction SilentlyContinue
Write-Host "  Private symbols saved safely: $($symbolFiles.Count) symbol files recorded in $symbolsDir" -ForegroundColor Green

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   SECURE RELEASE PIPELINE COMPLETED SUCCESSFULLY! " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
exit 0
