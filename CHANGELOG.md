# Changelog

All notable behavioral and structural changes to this project will be documented in this file.

## [Unreleased]

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
