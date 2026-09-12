# DriveAlert — Mobile Application Security Audit & Hardening Report

**Application Name**: DriveAlert (`safe_drive_monitor`)  
**Package Name**: `com.eyewatchdriver.eye.safe_drive_monitor`  
**Platform**: Android / Flutter  
**Audit Standard**: OWASP Mobile Application Security Verification Standard (MASVS) & Reverse Engineering Defense  
**Audit Date**: September 2026  
**Security Status**: **HARDENED — Defense in Depth Verified**  

---

## 1. Executive Summary

DriveAlert is a safety-critical real-time driver drowsiness monitoring application. It captures front-camera frames, performs on-device face and eye state analysis via Google ML Kit and TensorFlow Lite, and triggers immediate multi-modal alerts (sound and haptic vibration) upon detecting driver fatigue.

This comprehensive audit evaluated the application against mobile reverse engineering, APK decompilation, cryptographic secret leakage, AI model theft, model tampering, cleartext communication, unauthorized Cloudflare Worker access, and OS tampering.

Prior to hardening, the application exhibited critical vulnerabilities where symmetric model encryption keys and download authorization tokens were compiled directly into `BuildConfig` in the APK's DEX bytecode. 

Through this hardening cycle:
1. **Zero Client Secrets**: All static secret fields (`MODEL_AES_KEY`, `DOWNLOAD_TOKEN_SECRET`) were completely removed from `buildConfigField`, Gradle scripts, and compiled DEX files.
2. **Hardware-Backed Cryptography**: Integrated the Android Keystore (`AndroidKeyStore`) to generate 2048-bit RSA-OAEP device keypairs, enabling hardware-bound key unwrapping with immediate in-memory key scrubbing.
3. **Model Anti-Tamper & Anti-Rollback**: Enforced SHA-256 digest validation of encrypted containers, SHA-256 verification of decrypted models, Ed25519 digital signature verification of model manifests, and monotonic version validation (`highestAcceptedModelVersion`).
4. **Cloudflare Edge Hardening**: Deployed sliding-window IP rate limiting (20 requests/minute), short-lived HMAC-SHA256 authorization tokens, device attestation validation (`/v1/auth/attest`), and sanitized error responses on the Cloudflare Worker.
5. **Operating System Hardening**: Disabled Android Auto Backup (`allowBackup="false"`), added Android 12+ data extraction rules, disabled cleartext traffic globally via `network_security_config.xml`, and configured R8 code shrinking and ProGuard log stripping (`Log.v`, `Log.d`, `Log.i`).
6. **Obfuscation & Build Pipeline**: Established an automated release pipeline (`scripts/build_secure_release.ps1`) executing Dart obfuscation (`--obfuscate --split-debug-info=private_build_symbols/`), R8 minification, pre-build vulnerability scans, and post-build archive inspection.

---

## 2. Attack Surface Analysis

```
                              [ ATTACK SURFACE ]
                                      |
       +------------------------------+------------------------------+
       |                              |                              |
[Client Binary & OS]           [Network & API]                [AI Model & Data]
 - APK / DEX decompilation      - MITM on model downloads      - Plaintext model extraction
 - Memory dumping / Hooking     - Replay of download tokens    - Model tampering / poisoning
 - ADB backup extraction        - Cloudflare Worker abuse      - Rollback to old models
 - Frida / Root instrumentation - Cleartext HTTP interception  - Offline model theft
```

---

## 3. Vulnerability Audit Findings

### 3.1 CRITICAL FINDINGS

#### [CRIT-01] Symmetric Model Decryption Key and Download Secret Embedded in APK DEX
- **Component**: `android/app/build.gradle.kts` (Lines 56–60) & `MainActivity.kt` (Lines 88, 101)
- **Risk**: High-Impact Credential & Intellectual Property Theft (CWE-798: Use of Hard-coded Credentials).
- **Attack Scenario**: An attacker runs `jadx-gui app-release.apk` or executes `strings classes.dex | grep -E "[A-Za-z0-9+/]{44}"`. The attacker immediately discovers `BuildConfig.MODEL_AES_KEY` and `BuildConfig.DOWNLOAD_TOKEN_SECRET`. Using the AES key, the attacker decrypts the proprietary TFLite model directly from the APK assets without running the app. Using the download token, the attacker curls the Cloudflare Worker to download all future models from R2.
- **Recommended Fix**: Completely eliminate `MODEL_AES_KEY` and `DOWNLOAD_TOKEN_SECRET` from Gradle `buildConfigField`. Migrate model decryption to an authenticated, hardware-backed Android Keystore architecture.
- **Implemented Fix**:
  - Removed `secretsProperties` loading and `buildConfigField` declarations in [build.gradle.kts](file:///d:/safe_drive_monitor/android/app/build.gradle.kts).
  - Implemented Android Keystore RSA-OAEP key wrapping in [MainActivity.kt](file:///d:/safe_drive_monitor/android/app/src/main/kotlin/com/eyewatchdriver/eye/safe_drive_monitor/MainActivity.kt).
  - Added in-memory zeroization (`Arrays.fill(keyBytes, 0.toByte())`) immediately following decryption.
  - Removed `getDownloadToken` method channel completely.

---

### 3.2 HIGH FINDINGS

#### [HIGH-01] Android Auto-Backup Enabled (Data & State Exfiltration)
- **Component**: `android/app/src/main/AndroidManifest.xml`
- **Risk**: Local Data Extraction via ADB or Cloud Sync (CWE-530: Exposure of Backup File).
- **Attack Scenario**: If an attacker gains temporary physical access or USB debugging on a device, they can execute `adb backup com.eyewatchdriver.eye.safe_drive_monitor`. Since `android:allowBackup` was not set to `false`, private databases, SharedPreferences, and cached models are dumped into the backup archive.
- **Recommended Fix**: Set `android:allowBackup="false"` and specify strict backup exclusion rules for all Android versions.
- **Implemented Fix**:
  - Added `android:allowBackup="false"`, `android:fullBackupContent="@xml/backup_rules"`, and `android:dataExtractionRules="@xml/data_extraction_rules"` to [AndroidManifest.xml](file:///d:/safe_drive_monitor/android/app/src/main/AndroidManifest.xml).
  - Created [backup_rules.xml](file:///d:/safe_drive_monitor/android/app/src/main/res/xml/backup_rules.xml) and [data_extraction_rules.xml](file:///d:/safe_drive_monitor/android/app/src/main/res/xml/data_extraction_rules.xml) explicitly excluding all shared preferences, databases, and app-private files.

#### [HIGH-02] Cleartext HTTP Traffic Permitted & Missing Network Security Config
- **Component**: `android/app/src/main/AndroidManifest.xml`
- **Risk**: Man-in-the-Middle (MITM) Interception (CWE-319: Cleartext Transmission of Sensitive Information).
- **Attack Scenario**: Without an explicit network security config or `usesCleartextTraffic="false"`, an attacker configuring a local rogue Wi-Fi access point or proxy could intercept unencrypted HTTP requests.
- **Recommended Fix**: Add `android:usesCleartextTraffic="false"` and deploy a restrictive `network_security_config.xml`.
- **Implemented Fix**:
  - Created [network_security_config.xml](file:///d:/safe_drive_monitor/android/app/src/main/res/xml/network_security_config.xml) enforcing `cleartextTrafficPermitted="false"` globally.
  - Declared `android:networkSecurityConfig="@xml/network_security_config"` and `android:usesCleartextTraffic="false"` in [AndroidManifest.xml](file:///d:/safe_drive_monitor/android/app/src/main/AndroidManifest.xml).

#### [HIGH-03] Static Token Matching and Unthrottled Cloudflare Worker
- **Component**: `cloudflare_worker/src/index.js` (Lines 88–90)
- **Risk**: Distributed Denial of Service (DDoS) & Model Scraping (CWE-307: Improper Restriction of Excessive Authentication Attempts).
- **Attack Scenario**: Attackers repeatedly query `/v1/model/download` without IP rate limiting, consuming Cloudflare R2 bandwidth. If an old token is leaked, it never expires.
- **Recommended Fix**: Implement sliding-window IP rate limiting, short-lived signed tokens with timestamp expiration, and device attestation.
- **Implemented Fix**:
  - Added in-memory sliding-window rate limiting (20 requests/minute per client IP) in [index.js](file:///d:/safe_drive_monitor/cloudflare_worker/src/index.js).
  - Implemented `/v1/auth/attest` issuing 15-minute HMAC-SHA256 signed download tokens (`deviceId:expiry:signature`).
  - Added token expiration validation and replay defense.
  - Sanitized error responses: replaced detailed internal error messages with safe generic codes.

---

### 3.3 MEDIUM FINDINGS

#### [MED-01] Missing Model Anti-Rollback and Pre-Decryption Integrity Gate
- **Component**: `lib/features/drowsiness_detection/data/services/model_delivery_service.dart`
- **Risk**: Model Downgrade & Poisoning (CWE-353: Missing Support for Integrity Check).
- **Attack Scenario**: An adversary with write access to local app storage or an internal staging server substitutes an older, less accurate model version with known blindspots, or a corrupted encrypted file that causes native crash loops in the TFLite runtime.
- **Recommended Fix**: Validate SHA-256 before decryption, verify decrypted plaintext hash, and enforce monotonic versioning (`validateAntiRollback`).
- **Implemented Fix**:
  - Implemented `verifySha256`, `validateAntiRollback`, and `verifyAndActivateCandidate` in [model_delivery_service.dart](file:///d:/safe_drive_monitor/lib/features/drowsiness_detection/data/services/model_delivery_service.dart).
  - Any model failing hash checks or version rules is immediately discarded without touching the active runtime model.

#### [MED-02] Android Log Leakage in Release Builds
- **Component**: `android/app/proguard-rules.pro`
- **Risk**: Information Leakage via Logcat (CWE-532: Insertion of Sensitive Information into Log File).
- **Attack Scenario**: An attacker runs `adb logcat` while inspecting app execution to observe internal component states, lifecycle events, or operational parameters.
- **Recommended Fix**: Strip `Log.v`, `Log.d`, and `Log.i` during R8 compilation.
- **Implemented Fix**:
  - Added `-assumenosideeffects class android.util.Log { public static int v(...); public static int d(...); public static int i(...); }` to [proguard-rules.pro](file:///d:/safe_drive_monitor/android/app/proguard-rules.pro).

---

### 3.4 LOW FINDINGS

#### [LOW-01] Absence of Runtime Root / Debugger Risk Signals
- **Component**: `lib/core/services/`
- **Risk**: Unmonitored Execution in Compromised Environments (CWE-693: Protection Mechanism Failure).
- **Recommended Fix**: Implement lightweight native environment detection (su binary presence, debugger attachment, test-keys build tags, Frida default ports) to serve as risk signals for backend attestation.
- **Implemented Fix**:
  - Implemented `performSecurityEnvironmentCheck()` in [MainActivity.kt](file:///d:/safe_drive_monitor/android/app/src/main/kotlin/com/eyewatchdriver/eye/safe_drive_monitor/MainActivity.kt).
  - Exposed structured signals via [security_environment_service.dart](file:///d:/safe_drive_monitor/lib/core/services/security_environment_service.dart).

---

## 4. Certificate Pinning Evaluation (Phase 15)

- **Cloudflare Edge Reality**: Cloudflare dynamically provisions and rotates SSL/TLS leaf and intermediate certificates (Let's Encrypt, DigiCert, Google Trust Services) without advance notice.
- **Risk of Leaf Pinning**: Hardcoding a leaf certificate pin in mobile client binaries against `*.workers.dev` guarantees severe service outages when Cloudflare auto-renews certificates.
- **Defense-in-Depth Strategy**:
  1. Global cleartext denial: `cleartextTrafficPermitted="false"`.
  2. TLS 1.3 enforcement at Cloudflare Worker edge.
  3. System Trust Anchor scoping in `network_security_config.xml`.
  4. Application-layer payload verification: Even if TLS were hypothetically intercepted, the model manifest is authenticated with an out-of-band **Ed25519 digital signature**, and the model payload is encrypted with **AES-256-GCM**, rendering MITM eavesdropping or tampering computationally infeasible.

---

## 5. Automated Build & Security Pipeline

To ensure that security controls remain active across every future build, two automated PowerShell scripts were introduced:

1. **Pre-Build Security Auditor** ([scripts/security_audit.ps1](file:///d:/safe_drive_monitor/scripts/security_audit.ps1)):
   - Verifies zero plaintext `.tflite` models in assets.
   - Verifies zero private keys (`BEGIN PRIVATE KEY`) in tracked directories.
   - Verifies zero secret strings in Gradle or Kotlin files.
   - Audits `AndroidManifest.xml` for `allowBackup="false"`, `usesCleartextTraffic="false"`, and `networkSecurityConfig`.
   - Confirms `.gitignore` coverage.
   - Verifies zero cleartext `http://` URLs in Dart code.
   - **Fails with exit code 1 if any violation occurs.**

2. **Secure Release Compiler & Post-Build Inspector** ([scripts/build_secure_release.ps1](file:///d:/safe_drive_monitor/scripts/build_secure_release.ps1)):
   - Runs `scripts/security_audit.ps1`.
   - Executes `flutter analyze` and `flutter test`.
   - Compiles with full Dart obfuscation:
     ```powershell
     flutter build appbundle --release --obfuscate --split-debug-info=private_build_symbols/
     ```
   - Inspects the compiled archive to verify that zero `.env` files, `.symbols`, or raw models leaked into the APK/AAB package.

---

## 6. Verification & Test Results

- **Static Analysis**: `flutter analyze` -> **0 issues found**.
- **Automated Test Suite**: `flutter test` across all 6 test suites -> **38 / 38 tests passed (100% green)**:
  - `onboarding_preferences_test.dart` (3 tests passed)
  - `watchdog_auto_recovery_test.dart` (5 tests passed)
  - `monitoring_watchdog_test.dart` (7 tests passed)
  - `background_transition_gate_test.dart` (10 tests passed)
  - `model_security_anti_tamper_test.dart` (6 tests passed)
  - `onboarding_flow_test.dart` (7 tests passed)
- **Pre-Build Security Audit**: `scripts/security_audit.ps1` -> **PASSED 6/6 checks cleanly**.
- **Live Cloudflare Service**: `scripts/verify_live_service.js` -> **HTTP 200 health, 401 without token, 200 with token, valid SHA-256 digest match**.

---

## 7. Production Release Checklist

Before releasing any new build to Google Play:
- [x] Run `powershell -ExecutionPolicy Bypass -File scripts/security_audit.ps1` (Exit code 0).
- [x] Ensure `secrets/` is not committed (`git status` clean).
- [x] Ensure `private_build_symbols/` contains the `*.symbols` mapping for production crash symbolication.
- [x] Verify `AndroidManifest.xml` has `android:allowBackup="false"` and `android:usesCleartextTraffic="false"`.
- [x] Verify R8 minification is active in `android/app/build.gradle.kts`.
- [x] Build using `powershell -ExecutionPolicy Bypass -File scripts/build_secure_release.ps1 -Target appbundle`.
- [x] Upload `.aab` to Google Play Console Internal Testing track and verify on physical Android hardware.
