import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/camera_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/eye_state_classifier.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/face_detection_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/camera_stream_watchdog.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/driver_face_tracker.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/legacy_decision_analyzer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/low_light_detector.dart';

class DrowsinessDetectionProvider extends ChangeNotifier {
  static const String _tag = 'DrowsinessProvider';

  final CameraService _cameraService;
  final EyeStateClassifier _classifier;
  final FaceDetectionService _faceDetectionService;
  final DriverFaceTracker _faceTracker;
  final CameraStreamWatchdog _watchdog;
  final LowLightDetector _lowLightDetector;
  final DrowsinessAnalyzer _drowsinessAnalyzer;
  final LegacyDecisionAnalyzer _legacyAnalyzer;
  final AudioAlarmService _audioAlarmService;
  final HapticService _hapticService;

  bool _disposed = false;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  bool _isProcessingFrame = false;
  bool _isDetectingFace = false;
  bool _wasMonitoringBeforePause = false;
  Object? _error;
  String _statusMessage = 'جاهز لبدء المراقبة';

  EyePrediction? _lastPrediction;
  DriverFace? _currentDriverFace;
  DriverAlertState _alertState = DriverAlertState.normal;

  /// Diagnostics knobs (PHASE 2/4 bring-up), overridable without a rebuild:
  ///   --dart-define=DETECTION_MODE=java   -> start in java-compatible path
  ///   --dart-define=ROT_OFFSET=90         -> add degrees to the sensor rotation
  static const String _detectionModeOverride =
      String.fromEnvironment('DETECTION_MODE');
  static const int _rotationOffset = int.fromEnvironment('ROT_OFFSET');

  DetectionMode _detectionMode = _detectionModeOverride == 'java'
      ? DetectionMode.javaCompatible
      : DetectionMode.improved;
  RoiStrategy _roiStrategy = RoiStrategy.eyeBand;

  // Performance & Profiling Metrics
  Duration _preprocessingTime = Duration.zero;
  Duration _inferenceTime = Duration.zero;
  Duration _faceDetectionTime = Duration.zero;
  Duration _totalFrameProcessingTime = Duration.zero;
  DateTime _lastFrameProcessedTimestamp = DateTime.now();
  DateTime _lastInferenceTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFaceDetectionTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  double _processedFps = 0.0;
  int _droppedFramesCount = 0;
  int _processedFramesCount = 0;

  /// Throttling intervals
  Duration _inferenceInterval = AppConstants.defaultInferenceInterval;
  static const Duration _faceDetectionInterval = Duration(milliseconds: 280); // ~3.5 Hz

  DrowsinessDetectionProvider({
    CameraService? cameraService,
    EyeStateClassifier? classifier,
    FaceDetectionService? faceDetectionService,
    DriverFaceTracker? faceTracker,
    CameraStreamWatchdog? watchdog,
    LowLightDetector? lowLightDetector,
    DrowsinessAnalyzer? drowsinessAnalyzer,
    LegacyDecisionAnalyzer? legacyAnalyzer,
    AudioAlarmService? audioAlarmService,
    HapticService? hapticService,
  })  : _cameraService = cameraService ?? AppCameraService(),
        _classifier = classifier ?? TfliteEyeStateClassifier(),
        _faceDetectionService = faceDetectionService ?? MlKitFaceDetectionService(),
        _faceTracker = faceTracker ?? DriverFaceTracker(),
        _watchdog = watchdog ?? CameraStreamWatchdog(),
        _lowLightDetector = lowLightDetector ?? LowLightDetector(),
        _drowsinessAnalyzer = drowsinessAnalyzer ?? DrowsinessAnalyzer(),
        _legacyAnalyzer = legacyAnalyzer ?? LegacyDecisionAnalyzer(),
        _audioAlarmService = audioAlarmService ?? AppAudioAlarmService(),
        _hapticService = hapticService ?? AppHapticService() {
    _syncConfigWithClassifier();
  }

  void _syncConfigWithClassifier() {
    _classifier.minOpenConfidence = _drowsinessAnalyzer.config.minimumOpenConfidence;
    _classifier.minClosedConfidence = _drowsinessAnalyzer.config.minimumClosedConfidence;
  }

  /// Pushes a coherent preprocessing configuration onto the classifier for the
  /// current [_detectionMode]. Must run at startup because [setDetectionMode]
  /// early-returns when the mode is already the default (`improved`).
  void _applyDetectionModeConfig() {
    if (_detectionMode == DetectionMode.javaCompatible) {
      _roiStrategy = RoiStrategy.legacyCenterCrop;
      _classifier.channelLayout = TensorChannelLayout.planarRgb;
      _classifier.pipeline = DetectionPipeline.legacyCenterCrop;
    } else {
      // fullFace: crop the reliable ML Kit face bounding box (not the tight
      // landmark eye-band, which needs eye landmarks the plugin isn't
      // returning and starves a whole-frame-trained classifier of context).
      _roiStrategy = RoiStrategy.fullFace;
      _classifier.channelLayout = TensorChannelLayout.interleavedRgb;
      _classifier.pipeline = DetectionPipeline.faceAware;
    }
    _classifier.roiStrategy = _roiStrategy;
    _classifier.debugRawOutput = kDebugMode;
  }

  // Getters
  bool get isDisposed => _disposed;
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  bool get isModelLoaded => _classifier.isLoaded;
  bool get isCameraReady => _cameraService.isInitialized;
  CameraController? get cameraController => _cameraService.controller;

  EyePrediction? get lastPrediction => _lastPrediction;
  DriverFace? get currentDriverFace => _currentDriverFace;
  bool get hasValidDriverFace =>
      _faceTracker.isDriverFaceActive(DateTime.now());
  DriverAlertState get alertState => _alertState;
  String get statusMessage => _statusMessage;
  Object? get error => _error;

  DetectionMode get detectionMode => _detectionMode;
  DetectionPipeline get detectionPipeline => _classifier.pipeline;
  RoiStrategy get roiStrategy => _roiStrategy;
  TensorChannelLayout get tensorLayout => _classifier.channelLayout;
  ModelOutputMode get outputMode => _classifier.outputMode;
  bool get useDirectFastPipeline => _classifier.useDirectFastPipeline;
  DrowsinessConfig get config => _drowsinessAnalyzer.config;
  double get perclosScore => _drowsinessAnalyzer.currentPerclos;
  double get perclosPercentage => _drowsinessAnalyzer.currentPerclosPercentage;
  bool get isHeadNodDetected =>
      _currentDriverFace?.headEulerAngleX != null &&
      _currentDriverFace!.headEulerAngleX! < config.headNodPitchThreshold;
  int get watchdogRecoveryCount => _watchdog.stallRecoveryCount;
  double get currentLuminance => _lowLightDetector.currentLuminance;
  bool get isLowLight => _lowLightDetector.isLowLight;

  Duration get preprocessingTime => _preprocessingTime;
  Duration get inferenceTime => _inferenceTime;
  Duration get faceDetectionTime => _faceDetectionTime;
  Duration get totalFrameProcessingTime => _totalFrameProcessingTime;
  double get processedFps => _processedFps;
  int get droppedFramesCount => _droppedFramesCount;
  int get processedFramesCount => _processedFramesCount;
  Duration get inferenceInterval => _inferenceInterval;
  bool get isLegacyAlarmTriggered => _legacyAnalyzer.isAlarmTriggered;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Initialize Camera and TensorFlow Lite Model.
  Future<void> initialize() async {
    if (_disposed || _isInitialized) return;
    _error = null;
    _statusMessage = 'جاري تهيئة الكاميرا ونموذج الذكاء الاصطناعي...';
    notifyListeners();

    try {
      await Future.wait([
        _cameraService.initialize(lensDirection: CameraLensDirection.front),
        _classifier.load(),
      ]);

      if (_disposed) return;
      // Re-apply the central DrowsinessConfig thresholds + a coherent
      // preprocessing config (layout / pipeline / ROI) to the classifier.
      _syncConfigWithClassifier();
      _applyDetectionModeConfig();
      _isInitialized = true;
      _statusMessage = 'تمت التهيئة بنجاح. اضغط على زر البدء لبدء المراقبة.';
      AppLogger.info(_tag, 'Drowsiness detection provider initialized.');
      notifyListeners();
    } catch (e, st) {
      if (_disposed) return;
      _error = e;
      _statusMessage = e is AppException ? e.message : 'فشل في تهيئة النظام';
      AppLogger.error(_tag, 'Initialization error', e, st);
      notifyListeners();
    }
  }

  /// Start real-time image analysis stream with Watchdog monitor.
  Future<void> startMonitoring() async {
    if (_disposed) return;
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized || _disposed) return;
    }
    if (_isMonitoring) return;

    try {
      _error = null;
      _isMonitoring = true;
      _statusMessage = 'جاري مراقبة حالة السائق...';
      _drowsinessAnalyzer.reset();
      _legacyAnalyzer.reset();
      _faceTracker.reset();
      _currentDriverFace = null;
      _droppedFramesCount = 0;
      _processedFramesCount = 0;
      _lastInferenceTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
      _lastFaceDetectionTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

      await _cameraService.startImageStream(_handleCameraFrame);

      // Start stream watchdog monitor
      _watchdog.start(onStallDetected: _recoverCameraStream);

      AppLogger.info(_tag, 'Monitoring session started.');
      notifyListeners();
    } catch (e, st) {
      if (_disposed) return;
      _isMonitoring = false;
      _watchdog.stop();
      _error = e;
      _statusMessage = 'فشل في بدء المراقبة';
      AppLogger.error(_tag, 'Start monitoring error', e, st);
      notifyListeners();
    }
  }

  /// Stop monitoring, camera stream, watchdog, and audio alarm.
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;
      _watchdog.stop();
      await _cameraService.stopImageStream();
      await _stopAlarmFeedback();
      _drowsinessAnalyzer.reset();
      _legacyAnalyzer.reset();
      _faceTracker.reset();
      _currentDriverFace = null;
      _alertState = DriverAlertState.normal;
      _statusMessage = 'تم إيقاف المراقبة';
      AppLogger.info(_tag, 'Monitoring session stopped.');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(_tag, 'Stop monitoring error', e, st);
    }
  }

  /// Automatic watchdog recovery when camera frame stream stalls.
  Future<void> _recoverCameraStream() async {
    if (!_isMonitoring || _disposed) return;

    AppLogger.warning(_tag, 'Executing watchdog camera stream recovery...');
    try {
      await _cameraService.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 100));
      await _cameraService.startImageStream(_handleCameraFrame);
      AppLogger.info(_tag, 'Watchdog stream recovery successful.');
    } catch (e) {
      AppLogger.error(_tag, 'Soft recovery failed, re-initializing camera...', e);
      try {
        await _cameraService.dispose();
        await Future.delayed(const Duration(milliseconds: 150));
        await _cameraService.initialize(lensDirection: CameraLensDirection.front);
        await _cameraService.startImageStream(_handleCameraFrame);
        AppLogger.info(_tag, 'Full camera re-init recovery successful.');
      } catch (err, st) {
        AppLogger.error(_tag, 'Fatal watchdog recovery error', err, st);
      }
    }
  }

  /// Process camera frame callback with non-blocking guard.
  void _handleCameraFrame(CameraImage image) async {
    if (_disposed) return;
    final now = DateTime.now();

    // Record frame heartbeat in watchdog
    _watchdog.recordHeartbeat(now);

    // Compute luminance for low-light / night driving detection
    _lowLightDetector.processCameraImage(image);

    // Guard 1: Ignore frame if monitoring is off or inference is already running
    if (!_isMonitoring || _isProcessingFrame) {
      _droppedFramesCount++;
      return;
    }

    // 1. Asynchronous throttled Face Detection (~3.5 Hz)
    if (!_isDetectingFace &&
        now.difference(_lastFaceDetectionTimestamp) >= _faceDetectionInterval) {
      _runFaceDetection(image, now);
    }

    // Guard 2: Throttling interval for eye state inference
    if (now.difference(_lastInferenceTimestamp) < _inferenceInterval) {
      _droppedFramesCount++;
      return;
    }

    _isProcessingFrame = true;
    _lastInferenceTimestamp = now;

    try {
      final totalStopwatch = Stopwatch()..start();
      final isFaceActive = _faceTracker.isDriverFaceActive(now);

      // Safety (PHASE 4): outside legacyCenterCrop mode, never classify a
      // frame with no fresh driver face. Cropping the background and reporting
      // "eyes open" would mask a drowsy driver whose face was briefly lost.
      if (_roiStrategy != RoiStrategy.legacyCenterCrop && !isFaceActive) {
        final noFace = EyePrediction(
          state: EyeState.unknown,
          openScore: 0.0,
          closedScore: 0.0,
          confidence: 0.0,
          inferenceTime: Duration.zero,
          timestamp: now,
        );
        final res = _drowsinessAnalyzer.processPrediction(noFace, driverFace: null);
        _alertState = res.alertState;
        _lastPrediction = noFace;
        _statusMessage = 'لا يوجد وجه سائق واضح — جاري البحث...';
        notifyListeners();
        return;
      }

      // legacyCenterCrop => feed a true centre crop (no ROI). Otherwise use the
      // tracked, smoothed face/eye ROI while it is still fresh.
      final dynamicRoi = (_roiStrategy != RoiStrategy.legacyCenterCrop && isFaceActive)
          ? _faceTracker.currentEyeRoi
          : null;

      final prediction = await _classifier.classify(
        image,
        sensorRotation:
            (_cameraService.sensorOrientation + _rotationOffset) % 360,
        dynamicRoi: dynamicRoi,
      );

      if (_disposed || !_isMonitoring) return;

      _inferenceTime = prediction.inferenceTime;

      // 2. Legacy comparison analysis (debug)
      _legacyAnalyzer.processPrediction(prediction);

      // 3. Time-based Drowsiness State Machine Analysis (with PERCLOS and Head Nod)
      final analysisResult = _drowsinessAnalyzer.processPrediction(
        prediction,
        driverFace: _currentDriverFace,
      );
      _alertState = analysisResult.alertState;

      // 4. Adaptive Inference Interval Throttling
      if (config.enableAdaptiveInference) {
        _inferenceInterval = _alertState == DriverAlertState.normal
            ? config.normalInferenceInterval
            : config.alertInferenceInterval;
      }

      if (!isFaceActive && _roiStrategy == RoiStrategy.eyeBand) {
        _statusMessage = '${analysisResult.statusMessage} (جاري البحث عن قفل الوجه...)';
      } else {
        _statusMessage = analysisResult.statusMessage;
      }
      _lastPrediction = prediction;

      if (kDebugMode) {
        if (prediction.isClosed) {
          debugPrint(
            '🙈 [EYE_STATUS] تم غلق العين (Eyes CLOSED) | '
            'Closed: ${(prediction.closedScore * 100).toStringAsFixed(1)}% | '
            'Open: ${(prediction.openScore * 100).toStringAsFixed(1)}% | '
            'PERCLOS: ${perclosPercentage.toStringAsFixed(1)}% | '
            'Alert: ${_alertState.name.toUpperCase()}',
          );
        } else if (prediction.isOpen) {
          debugPrint(
            '👁️ [EYE_STATUS] تم فتح العين (Eyes OPEN) | '
            'Open: ${(prediction.openScore * 100).toStringAsFixed(1)}% | '
            'Closed: ${(prediction.closedScore * 100).toStringAsFixed(1)}% | '
            'PERCLOS: ${perclosPercentage.toStringAsFixed(1)}%',
          );
        }
      }

      // 5. Handle audio and vibration alarms
      if (analysisResult.shouldTriggerAlarm) {
        if (kDebugMode) {
          debugPrint('🚨🚨🚨 [ALARM] إنذار! تم اكتشاف نوم السائق! تشغيل صوت التنبيه والاهتزاز! 🚨🚨🚨');
        }
        await _triggerAlarmFeedback();
      } else if (analysisResult.shouldStopAlarm) {
        if (kDebugMode) {
          debugPrint('✅ [ALARM] تم استعادة يقظة السائق وإيقاف صوت الإنذار.');
        }
        await _stopAlarmFeedback();
      }

      totalStopwatch.stop();
      _totalFrameProcessingTime = totalStopwatch.elapsed;
      _preprocessingTime = _totalFrameProcessingTime > _inferenceTime
          ? _totalFrameProcessingTime - _inferenceTime
          : Duration.zero;

      // 6. Update rolling average FPS metric
      _processedFramesCount++;
      final elapsedSinceLast =
          now.difference(_lastFrameProcessedTimestamp).inMilliseconds;
      if (elapsedSinceLast > 0) {
        final instantFps = 1000.0 / elapsedSinceLast;
        _processedFps =
            _processedFps == 0.0 ? instantFps : (_processedFps * 0.85 + instantFps * 0.15);
      }
      _lastFrameProcessedTimestamp = now;

      notifyListeners();
    } catch (e, st) {
      AppLogger.error(_tag, 'Frame processing failed', e, st);
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Runs offline face detection without blocking the main image stream.
  void _runFaceDetection(CameraImage image, DateTime timestamp) async {
    _isDetectingFace = true;
    _lastFaceDetectionTimestamp = timestamp;

    try {
      final sw = Stopwatch()..start();
      final faces = await _faceDetectionService.detectFaces(
        image,
        sensorRotation:
            (_cameraService.sensorOrientation + _rotationOffset) % 360,
      );
      sw.stop();
      _faceDetectionTime = sw.elapsed;

      if (_disposed || !_isMonitoring) return;

      _currentDriverFace = _faceTracker.update(
        faces,
        timestamp: timestamp,
        roiStrategy: _roiStrategy,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Face tracking error', e, st);
    } finally {
      _isDetectingFace = false;
    }
  }

  Future<void> _triggerAlarmFeedback() async {
    await Future.wait([
      _audioAlarmService.playAlarm(),
      _hapticService.startAlarmHaptic(),
    ]);
  }

  Future<void> _stopAlarmFeedback() async {
    await Future.wait([
      _audioAlarmService.stopAlarm(),
      _hapticService.stopAlarmHaptic(),
    ]);
  }

  void setDetectionMode(DetectionMode mode) {
    if (_detectionMode == mode) return;
    _detectionMode = mode;
    _applyDetectionModeConfig();
    AppLogger.info(_tag, 'Detection mode changed to: ${mode.name}');
    AppLogger.info(_tag, 'Tensor channel layout: ${_classifier.channelLayout.name}');
    AppLogger.info(_tag, 'Detection pipeline: ${_classifier.pipeline.name}');
    notifyListeners();
  }

  void setRoiStrategy(RoiStrategy strategy) {
    if (_roiStrategy == strategy) return;
    _roiStrategy = strategy;
    _classifier.roiStrategy = strategy;
    AppLogger.info(_tag, 'ROI Strategy changed to: ${strategy.name}');
    notifyListeners();
  }

  void setTensorLayout(TensorChannelLayout layout) {
    _classifier.channelLayout = layout;
    AppLogger.info(_tag, 'Tensor channel layout changed to: ${layout.name}');
    notifyListeners();
  }

  void setDetectionPipeline(DetectionPipeline pipeline) {
    _classifier.pipeline = pipeline;
    AppLogger.info(_tag, 'Detection pipeline changed to: ${pipeline.name}');
    notifyListeners();
  }

  void setOutputMode(ModelOutputMode mode) {
    _classifier.outputMode = mode;
    AppLogger.info(_tag, 'Model output mode changed to: ${mode.name}');
    notifyListeners();
  }

  void setInferenceInterval(Duration interval) {
    _inferenceInterval = interval;
    notifyListeners();
  }

  void setUseDirectFastPipeline(bool value) {
    _classifier.useDirectFastPipeline = value;
    AppLogger.info(_tag, 'Fast direct pipeline changed to: $value');
    notifyListeners();
  }

  /// App Lifecycle state handling with automatic monitoring resumption
  void handleAppLifecycleState(AppLifecycleState state) {
    AppLogger.info(_tag, 'AppLifecycleState changed to: ${state.name}');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_isMonitoring) {
          _wasMonitoringBeforePause = true;
          stopMonitoring();
        }
        break;
      case AppLifecycleState.resumed:
        if (_wasMonitoringBeforePause && !_isMonitoring) {
          _wasMonitoringBeforePause = false;
          startMonitoring();
        }
        break;
      case AppLifecycleState.detached:
        disposeResources();
        break;
    }
  }

  /// Clean up all hardware, watchdog, and native resources safely
  Future<void> disposeResources() async {
    try {
      _watchdog.stop();
    } catch (_) {}
    try {
      await stopMonitoring();
    } catch (_) {}
    try {
      await _cameraService.dispose();
    } catch (_) {}
    try {
      await _classifier.dispose();
    } catch (_) {}
    try {
      await _faceDetectionService.dispose();
    } catch (_) {}
    try {
      await _audioAlarmService.dispose();
    } catch (_) {}
    try {
      await _hapticService.dispose();
    } catch (_) {}
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposed = true;
    disposeResources().catchError((e) {
      AppLogger.error(_tag, 'Async disposal error', e);
    });
    super.dispose();
  }
}
