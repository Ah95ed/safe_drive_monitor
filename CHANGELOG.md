# Changelog

All notable behavioral and structural changes to this project will be documented in this file.

## [Unreleased]

### Phase 5 — Packaging, ProGuard Rules, Assets & CI Validation (build(ci))
- **Explicit Asset Pinning (`pubspec.yaml`)**: Pinned model (`assets/models/eye_detector_5n_320_float16.tflite`) and audio assets explicitly, removing broad wildcard directory inclusions to minimize APK footprint.
- **Synthesized Technical Warning Sound**: Added `assets/sounds/warning.mp3` (2.8 kHz dual-beep audio tone, 44.1 kHz, 128 kbps) for non-drowsiness technical alerts.
- **Audio Asset Pre-Flight Validation**: Implemented `_verifyAudioAssets()` during provider initialization to test loadability via `rootBundle.load()`. Added `AudioAssetLoadException` and disabled start monitoring button if audio alert assets fail to load.
- **ProGuard / R8 Release Rules**: Updated `android/app/proguard-rules.pro` with explicit keep rules for TensorFlow Lite native interfaces and bundled Google ML Kit face detector (`com.google.android.gms.internal.mlkit_vision_face.**`).
- **iOS Capabilities & Permissions**: Added `NSCameraUsageDescription` and `UIBackgroundModes: [audio]` to `ios/Runner/Info.plist`.
- **Streamlined GitHub Actions Workflow (`.github/workflows/Android.yaml`)**: Configured Java 17, static analysis with fatal warnings, unit tests, offline bundled ML Kit assertion, split-per-abi release builds, and tag release artifact publishing.

### Phase 4 — Real-World Driving Robustness & Degraded States (feat(driving))
- **Precomputed Gamma LUT Shadow Lifting**: Integrated precomputed 256-entry gamma lookup table (gamma = 0.75) within `ImagePreprocessor.gammaLut`. Activates seamlessly in `yuvRoiToNormalizedFloat32` when `isLowLight` is detected without runtime `math.pow()` overhead.
- **Critical Ambient Darkness Safety Rule**: Updated `LightingManager` to require 3 consecutive seconds below critical darkness threshold (luminance < 15) before declaring `DriverAlertState.insufficientLight`, preventing transient shadow flickers from triggering degraded state alarms.
- **Level 1 AMOLED Driving Mode**: Set power saver mode active by default at session start (`#000000` screen, CameraPreview unmounted to eliminate GPU rendering and cool the device). Added `wakeTemporaryHud()` 5-second touch-wake HUD timer, automatically overridden to alert HUD instantly on drowsiness alarm.
- **High-Contrast Degraded Safety Cards**: Configured dedicated high-contrast warning messages across `DrivingHudScreen` and `AlertBannerOverlay` for all degraded states (`noFaceDetected`, `insufficientLight`, `monitoringStalled`, `thermalThrottled`) with distinct technical audio warning sounds.

### Phase 3 — Pipeline Performance & Dedicated Isolate (perf(pipeline))
- **Zero-Copy Single-Pass ROI Extraction (`yuvRoiToNormalizedFloat32`)**: Implemented direct single-pass pixel reading and fixed-point YUV->RGB conversion sampling exclusively within the target ROI. Eliminates full-frame allocations and reduces preprocessing latency to < 8ms. Fully supports triplanar YUV420_888, biplanar NV12/NV21, single-plane NV21, and iOS BGRA8888 with specific `ImageConversionException` error handling.
- **Dedicated Long-Lived Inference Isolate (`IsolateEyeStateClassifier`)**: Spawns a dedicated background isolate worker at session initialization. Transfers preprocessed tensor data across isolate boundary via zero-copy `TransferableTypedData`. Initializes TFLite interpreter with `threads = 2`, `useNnApiForAndroid = false`, and `XNNPackDelegate` fallback to guarantee 0 UI jank.

### Phase 2 — Accuracy & Face ROI Enhancement (feat(ml))
- **Bundled Offline ML Kit**: Configured Gradle resolution strategy substituting `com.google.android.gms:play-services-mlkit-face-detection` with `com.google.mlkit:face-detection:16.1.7` (bundled offline model). Removed dynamic Play Services face download dependency from `AndroidManifest.xml` guaranteeing 100% offline flight-mode functionality.
- **Square Eye ROI Geometry (`FaceRoiDetector`)**: Implemented `FaceRoiDetector` and `MlKitFaceRoiDetector` expanding eye bounds 60% horizontally and 120% vertically, squaring dimensions, clamping safely within frame borders, and smoothing coordinates via Exponential Moving Average (alpha = 0.6).
- **Asymmetric Confidence Thresholds**: Configured asymmetric thresholds in `DrowsinessConfig` (closed eyes threshold `0.50`, open eyes threshold `0.55`) to prioritize detecting sleeping drivers (low Type II error) while demanding higher certainty before cancelling alerts.
- **3-Prediction Temporal Voting Buffer**: Added temporal voting buffer in `DrowsinessAnalyzer` requiring majority agreement across recent predictions before escalating alert states, eliminating single-frame noise.
- **Secondary Signal Rule**: Preserved TFLite as the primary eye-state decision maker. If ML Kit's native `eyeOpenProbability` strongly contradicts TFLite (> 0.6 difference), the system accelerates inference rate to resolve contradiction without overriding TFLite's decision.
- **Dequantization & Softmax Verification**: Added support for quantized `uint8`/`int8` outputs with `(q - zeroPoint) * scale` dequantization and exposed `outputIsSoftmaxed` validation on `EyeStateClassifier`.

### Phase 1 — Emergency Core Stability (fix(core))
- **Audio Context & Channel**: Wired `AudioContextAndroid` with `usageType: AndroidUsageType.alarm`, `contentType: AndroidContentType.sonification`, `isSpeakerphoneOn: true`, `audioFocus: AndroidAudioFocus.gainTransientExclusive`, and `duckOthers` on iOS. Implemented native Android `getAlarmVolume` channel and pre-session volume readiness validation.
- **Wakelock Plus**: Integrated `wakelock_plus` to maintain screen and CPU activation during driving sessions.
- **Lifecycle & Disposal Safety**: Guarded `hardStopAll()` and provider notifications with `!_disposed` to eliminate async unmounted exceptions.
- **Watchdog Stalled State**: Added `monitoringStalled`, `noFaceDetected`, `insufficientLight`, and `thermalThrottled` alert states to prevent silent monitoring failures.
