import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/services/alarm_controller.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/battery_optimization_service.dart';
import 'package:safe_drive_monitor/core/services/foreground_monitoring_service.dart';
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
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/camera_stream_watchdog.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/driver_face_tracker.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/low_light_detector.dart';

class DrowsinessDetectionProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _tag = 'DrowsinessProvider';

  final CameraService _cameraService;
  final EyeStateClassifier _classifier;
  final FaceDetectionService _faceDetectionService;
  final DriverFaceTracker _faceTracker;
  final MonitoringWatchdog _watchdog;
  final LightingManager _lightingManager;
  final DrowsinessAnalyzer _drowsinessAnalyzer;
  final AudioAlarmService _audioAlarmService;
  final HapticService _hapticService;
  final BatteryOptimizationService _batteryOptService;
  final ForegroundMonitoringService _foregroundService;
  late final AlarmController _alarmController;

  AppLifecycleState _currentLifecycleState = AppLifecycleState.resumed;

  bool _disposed = false;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  bool _isProcessingFrame = false;
  bool _isDetectingFace = false;
  bool _isPowerSaverMode = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _stopping = false;
  Object? _error;
  String _statusMessage = 'جاهز لبدء المراقبة';

  DrivingSessionState _sessionState = DrivingSessionState.idle();
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
  DateTime _lastUiNotificationTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  double _processedFps = 0.0;
  int _droppedFramesCount = 0;
  int _processedFramesCount = 0;

  /// Throttling intervals
  Duration _inferenceInterval = AppConstants.defaultInferenceInterval;
  static const Duration _faceDetectionInterval = Duration(milliseconds: 280); // ~3.5 Hz
  static const Duration _uiThrottleInterval = Duration(milliseconds: 500); // 2 Hz max for UI tree

  DrowsinessDetectionProvider({
    CameraService? cameraService,
    EyeStateClassifier? classifier,
    FaceDetectionService? faceDetectionService,
    DriverFaceTracker? faceTracker,
    MonitoringWatchdog? watchdog,
    LightingManager? lowLightDetector,
    DrowsinessAnalyzer? drowsinessAnalyzer,
    AudioAlarmService? audioAlarmService,
    HapticService? hapticService,
    AlarmController? alarmController,
    BatteryOptimizationService? batteryOptService,
    ForegroundMonitoringService? foregroundService,
  })  : _cameraService = cameraService ?? AppCameraService(),
        _classifier = classifier ?? TfliteEyeStateClassifier(),
        _faceDetectionService = faceDetectionService ?? MlKitFaceDetectionService(),
        _faceTracker = faceTracker ?? DriverFaceTracker(),
        _watchdog = watchdog ?? MonitoringWatchdog(),
        _lightingManager = lowLightDetector ?? LightingManager(),
        _drowsinessAnalyzer = drowsinessAnalyzer ?? DrowsinessAnalyzer(),
        _audioAlarmService = audioAlarmService ?? AppAudioAlarmService(),
        _hapticService = hapticService ?? AppHapticService(),
        _batteryOptService = batteryOptService ?? AppBatteryOptimizationService(),
        _foregroundService = foregroundService ?? AppForegroundMonitoringService() {
    _alarmController = alarmController ??
        AlarmController(_audioAlarmService, _hapticService);
    _syncConfigWithClassifier();
    _foregroundService.setNotificationStopHandler(() async {
      AppLogger.info(_tag, 'Notification Stop event received. Executing hardStopAll().');
      await hardStopAll();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  /// Delegates to native Android to move the app task to background without killing the session.
  Future<bool> moveTaskToBackground() async {
    return await _foregroundService.moveTaskToBackground();
  }

  void _syncConfigWithClassifier() {
    _classifier.minOpenConfidence = _drowsinessAnalyzer.config.minimumOpenConfidence;
    _classifier.minClosedConfidence = _drowsinessAnalyzer.config.minimumClosedConfidence;
  }

  void _applyDetectionModeConfig() {
    if (_detectionMode == DetectionMode.javaCompatible) {
      _roiStrategy = RoiStrategy.legacyCenterCrop;
      _classifier.channelLayout = TensorChannelLayout.planarRgb;
      _classifier.pipeline = DetectionPipeline.legacyCenterCrop;
    } else {
      _roiStrategy = RoiStrategy.fullFace;
      _classifier.channelLayout = TensorChannelLayout.interleavedRgb;
      _classifier.pipeline = DetectionPipeline.faceAware;
    }
    _classifier.roiStrategy = _roiStrategy;
  }

  // Getters
  bool get isDisposed => _disposed;
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  bool get isModelLoaded => _classifier.isLoaded;
  bool get isCameraReady => _cameraService.isInitialized;
  CameraController? get cameraController => _cameraService.controller;

  DrivingSessionState get sessionState => _sessionState;
  MonitoringHealth get monitoringHealth => _sessionState.health;
  MonitoringIssue get monitoringIssue => _sessionState.issue;
  bool get isMonitoringActiveAndHealthy =>
      _sessionState.isActuallyWorking(now: DateTime.now());

  EyePrediction? get lastPrediction => _lastPrediction;
  DriverFace? get currentDriverFace => _currentDriverFace;
  bool get hasValidDriverFace =>
      _faceTracker.isDriverFaceActive(DateTime.now());
  DriverAlertState get alertState => _alertState;
  String get statusMessage => _statusMessage;
  Object? get error => _error;

  AlarmController get alarmController => _alarmController;
  AppLifecycleState get currentLifecycleState => _currentLifecycleState;
  bool get isInBackground =>
      _currentLifecycleState == AppLifecycleState.paused ||
      _currentLifecycleState == AppLifecycleState.inactive ||
      _currentLifecycleState == AppLifecycleState.hidden;

  bool get isPowerSaverMode => _isPowerSaverMode;
  bool get isIgnoringBatteryOptimizations => _isIgnoringBatteryOptimizations;

  LightingState get lightingState => _lightingManager.lightingState;
  double get currentLuminance => _lightingManager.currentLuminance;
  bool get isLowLight => _lightingManager.isLowLight;
  bool get isCriticalDarkness => _lightingManager.isCriticalDarkness;
  double get screenIlluminationOpacity => _lightingManager.screenIlluminationOpacity;

  void togglePowerSaverMode() {
    _isPowerSaverMode = !_isPowerSaverMode;
    AppLogger.info(_tag, 'Power Saver Mode toggled: $_isPowerSaverMode');
    notifyListeners();
  }

  void setPowerSaverMode(bool value) {
    if (_isPowerSaverMode != value) {
      _isPowerSaverMode = value;
      notifyListeners();
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    final granted = await _batteryOptService.requestIgnoreBatteryOptimizations();
    _isIgnoringBatteryOptimizations = granted;
    _sessionState = _sessionState.copyWith(batteryOptimizationExempt: granted);
    notifyListeners();
    return granted;
  }

  Future<void> openBatterySettings() async {
    await _batteryOptService.openBatterySettings();
  }

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

  Duration get preprocessingTime => _preprocessingTime;
  Duration get inferenceTime => _inferenceTime;
  Duration get faceDetectionTime => _faceDetectionTime;
  Duration get totalFrameProcessingTime => _totalFrameProcessingTime;
  double get processedFps => _processedFps;
  int get droppedFramesCount => _droppedFramesCount;
  int get processedFramesCount => _processedFramesCount;
  Duration get inferenceInterval => _inferenceInterval;
  bool get isLegacyAlarmTriggered => _alertState.isAlarm;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Initialize Camera, Model, and Battery readiness.
  Future<void> initialize() async {
    if (_disposed || _isInitialized) return;
    _error = null;
    _statusMessage = 'جاري تهيئة الكاميرا ونموذج الذكاء الاصطناعي...';
    notifyListeners();

    try {
      final results = await Future.wait([
        _cameraService.initialize(lensDirection: CameraLensDirection.front),
        _classifier.load(),
        _batteryOptService.isIgnoringBatteryOptimizations(),
      ]);

      if (_disposed) return;
      _isIgnoringBatteryOptimizations = results[2] as bool;
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

  /// Start monitoring, Foreground Camera Service, image stream and watchdog.
  Future<void> startMonitoring() async {
    if (_isMonitoring || !_isInitialized) return;

    try {
      _error = null;
      _isMonitoring = true;
      _statusMessage = 'جاري بدء خدمة المراقبة...';
      notifyListeners();

      // 1. Start Android Foreground Camera Service
      bool fgsRunning = false;
      try {
        fgsRunning = await _foregroundService.startForegroundService();
      } catch (e) {
        AppLogger.warning(_tag, 'Foreground service warning: $e');
      }

      // 2. Reset session trackers
      _drowsinessAnalyzer.reset();
      _faceTracker.reset();
      _lightingManager.reset();
      _currentDriverFace = null;
      _droppedFramesCount = 0;
      _processedFramesCount = 0;
      _lastInferenceTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
      _lastFaceDetectionTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

      _sessionState = DrivingSessionState(
        active: true,
        startedAt: DateTime.now(),
        health: MonitoringHealth.healthy,
        issue: MonitoringIssue.none,
        foregroundServiceActive: fgsRunning,
        batteryOptimizationExempt: _isIgnoringBatteryOptimizations,
        wakeLockActive: true,
      );

      // 3. Start Camera Image Stream
      await _cameraService.startImageStream(_handleCameraFrame);

      // 4. Start Safety Watchdog
      _watchdog.start(
        onCameraStallDetected: _recoverCameraStream,
        onHealthChanged: _handleWatchdogHealthChanged,
      );

      _statusMessage = 'جاري مراقبة حالة السائق...';
      AppLogger.info(_tag, 'Monitoring session started.');
      notifyListeners();
    } catch (e, st) {
      if (_disposed) return;
      _isMonitoring = false;
      _watchdog.stop();
      _sessionState = DrivingSessionState.idle();
      _error = e;
      _statusMessage = 'فشل في بدء المراقبة';
      AppLogger.error(_tag, 'Start monitoring error', e, st);
      notifyListeners();
    }
  }

  /// Idempotent, safe, and unconditional complete halt of all monitoring subsystems.
  Future<void> hardStopAll() async {
    if (_stopping) return;
    _stopping = true;

    AppLogger.info(_tag, 'Executing hardStopAll...');
    try {
      _isMonitoring = false;

      // 1. Stop safety watchdog
      try {
        _watchdog.stop();
      } catch (e) {
        AppLogger.warning(_tag, 'Watchdog stop error: $e');
      }

      // 2. Stop camera stream
      try {
        await _cameraService.stopImageStream();
      } catch (e) {
        AppLogger.warning(_tag, 'Camera stop error: $e');
      }

      // 3. Force stop alarms and haptics unconditionally
      try {
        await _alarmController.forceStop();
      } catch (e) {
        AppLogger.warning(_tag, 'AlarmController forceStop error: $e');
      }
      try {
        await _audioAlarmService.stopAlarm();
      } catch (e) {
        AppLogger.warning(_tag, 'AudioAlarmService stop error: $e');
      }
      try {
        await _hapticService.stopAlarmHaptic();
      } catch (e) {
        AppLogger.warning(_tag, 'HapticService stop error: $e');
      }

      // 4. Stop foreground service and remove notification
      try {
        await _foregroundService.stopForegroundService();
      } catch (e) {
        AppLogger.warning(_tag, 'ForegroundService stop error: $e');
      }

      // 5. Reset analyzers, trackers, lighting
      _drowsinessAnalyzer.reset();
      _faceTracker.reset();
      _lightingManager.reset();
      _currentDriverFace = null;
      _alertState = DriverAlertState.normal;
      _sessionState = DrivingSessionState.idle();
      _statusMessage = 'تم إيقاف المراقبة بنجاح';

      AppLogger.info(_tag, 'hardStopAll completed cleanly.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Fatal error during hardStopAll', e, st);
    } finally {
      _stopping = false;
      notifyListeners();
    }
  }

  /// Stop monitoring alias delegating to hardStopAll().
  Future<void> stopMonitoring() async {
    await hardStopAll();
  }

  /// Handles health shifts from the watchdog.
  void _handleWatchdogHealthChanged(MonitoringHealth health, MonitoringIssue issue) {
    if (_disposed || !_isMonitoring) return;

    _sessionState = _sessionState.copyWith(
      health: health,
      issue: issue,
    );

    if (health == MonitoringHealth.failed) {
      _statusMessage = 'تنبيه عطل فني: ${issue.arabicDescription}';
      _audioAlarmService.playTechnicalWarning();
      _hapticService.playWarningHaptic();
      _foregroundService.updateNotificationStatus('⚠️ توقف نظام المراقبة: ${issue.arabicDescription}');
    } else if (health == MonitoringHealth.degraded) {
      _statusMessage = 'انخفاض كفاءة: ${issue.arabicDescription}';
      if (issue == MonitoringIssue.insufficientLight) {
        _hapticService.playWarningHaptic();
      }
      _foregroundService.updateNotificationStatus('انخفاض كفاءة: ${issue.arabicDescription}');
    } else {
      _statusMessage = _alertState == DriverAlertState.normal
          ? 'المراقبة نشطة ومستقرة'
          : _statusMessage;
      _foregroundService.updateNotificationStatus('مراقبة يقظة السائق نشطة ومستمرة لحمايتك');
    }

    notifyListeners();
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

    // 1. Record frame heartbeat in safety watchdog
    _watchdog.recordCameraFrameHeartbeat(now);
    _sessionState = _sessionState.copyWith(lastCameraFrameAt: now);

    // 2. Compute luminance on Y plane
    _lightingManager.processCameraImage(image);

    // 3. Adaptive Exposure steering
    final suggestedOffset = _lightingManager.computeAdaptiveExposureOffset(
      now: now,
      currentOffset: _cameraService.currentExposureOffset,
      minOffset: _cameraService.minExposureOffset,
      maxOffset: _cameraService.maxExposureOffset,
      stepSize: _cameraService.exposureStepSize,
    );
    if (suggestedOffset != null) {
      _cameraService.setExposureOffset(suggestedOffset);
    }

    _watchdog.recordLightingState(isCritical: _lightingManager.isCriticalDarkness);

    // Guard 1: Ignore frame if monitoring is off or inference is already running
    if (!_isMonitoring || _isProcessingFrame) {
      _droppedFramesCount++;
      return;
    }

    // 4. Asynchronous Face Detection: maintain consistent ~280ms interval for fresh tracking
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
      final isFaceActive = _faceTracker.isDriverFaceActive(now) && _currentDriverFace != null;

      // 1. Mandatory Face Presence Check:
      // If no face is detected, we do NOT run eye inference on background objects (empty room, desk, steering wheel).
      // Drowsiness counters are reset and any active alarm is halted immediately.
      if (!isFaceActive) {
        _lastPrediction = null;
        final previousAlert = _alertState;
        final analysisResult = _drowsinessAnalyzer.processPrediction(
          EyePrediction.unknown(timestamp: now),
          hasDriverFace: false,
          now: now,
        );
        _alertState = analysisResult.alertState;
        _statusMessage = analysisResult.statusMessage;

        // CRITICAL: Record inference heartbeat in watchdog!
        // The pipeline is active and healthy, successfully evaluating the frame (no face).
        _watchdog.recordInferenceHeartbeat(now);
        _sessionState = _sessionState.copyWith(lastInferenceAt: now);

        // Ensure alarm and any audio is completely stopped if no face is in frame
        await _alarmController.stop();
        await _audioAlarmService.stopAlarm();
        await _hapticService.stopAlarmHaptic();

        totalStopwatch.stop();
        _totalFrameProcessingTime = totalStopwatch.elapsed;
        _processedFramesCount++;
        _notifyThrottled(now, force: _alertState != previousAlert);
        return;
      }

      // 2. Face is active! Extract dynamicRoi from driver face
      final dynamicRoi = (_roiStrategy != RoiStrategy.legacyCenterCrop)
          ? (_currentDriverFace!.eyeRoi)
          : null;

      final rawPrediction = await _classifier.classify(
        image,
        sensorRotation:
            (_cameraService.sensorOrientation + _rotationOffset) % 360,
        dynamicRoi: dynamicRoi,
      );

      if (_disposed || !_isMonitoring) return;

      // 3. Multi-modal Sensor Fusion:
      // Combine TFLite eye crop prediction with ML Kit Face Detector's native eye open probability.
      EyePrediction prediction = rawPrediction;
      final bool isMlKitFresh = _currentDriverFace != null &&
          now.difference(_currentDriverFace!.detectedAt) <= const Duration(milliseconds: 700);
      final double? mlKitOpenProb = isMlKitFresh
          ? _currentDriverFace!.averageEyeOpenProbability
          : null;

      if (mlKitOpenProb != null) {
        if (mlKitOpenProb >= 0.60) {
          // ML Kit strongly indicates eyes are OPEN: guarantee OPEN state and high confidence
          if (rawPrediction.state != EyeState.open || rawPrediction.confidence < mlKitOpenProb) {
            prediction = EyePrediction(
              state: EyeState.open,
              openScore: mlKitOpenProb,
              closedScore: 1.0 - mlKitOpenProb,
              confidence: mlKitOpenProb,
              inferenceTime: rawPrediction.inferenceTime,
              timestamp: rawPrediction.timestamp,
            );
          }
        } else if (mlKitOpenProb <= 0.20 && rawPrediction.state == EyeState.closed) {
          // Both confirm CLOSED with high confidence
          final double closedConf = max(rawPrediction.confidence, 1.0 - mlKitOpenProb);
          prediction = EyePrediction(
            state: EyeState.closed,
            openScore: mlKitOpenProb,
            closedScore: 1.0 - mlKitOpenProb,
            confidence: closedConf,
            inferenceTime: rawPrediction.inferenceTime,
            timestamp: rawPrediction.timestamp,
          );
        }
      }

      _inferenceTime = prediction.inferenceTime;

      // Record successful inference heartbeat in watchdog
      _watchdog.recordInferenceHeartbeat(now);
      _sessionState = _sessionState.copyWith(lastInferenceAt: now);

      // 5. Time-based Drowsiness State Machine Analysis (with PERCLOS and Head Nod)
      final previousAlert = _alertState;
      final analysisResult = _drowsinessAnalyzer.processPrediction(
        prediction,
        driverFace: _currentDriverFace,
        hasDriverFace: true,
        now: now,
      );
      _alertState = analysisResult.alertState;

      // Log detailed background diagnostics per Requirement 1 & 11
      if (isInBackground) {
        _logBackgroundDebug(
          prediction: prediction,
          analysisResult: analysisResult,
          alarmPlaying: _alarmController.isPlaying,
        );
      }

      // 6. Adaptive Inference Interval Throttling (3-5 Hz when open, 12-15 Hz when drowsy)
      if (config.enableAdaptiveInference) {
        if (_alertState == DriverAlertState.normal) {
          _inferenceInterval = config.normalInferenceInterval; // 220ms (~4.5 Hz)
        } else if (_alertState == DriverAlertState.watching) {
          _inferenceInterval = const Duration(milliseconds: 125); // 8 Hz
        } else {
          _inferenceInterval = config.alertInferenceInterval; // 90ms (~11 Hz)
        }
      }

      _statusMessage = analysisResult.statusMessage;
      _lastPrediction = prediction;

      // If recovering, temporarily suspend vibration so camera has stable, non-blurred frames!
      if (_alertState == DriverAlertState.recovering || analysisResult.isRecovering) {
        await _hapticService.suspendHapticTemporarily();
      }

      // Guard against race condition if monitoring stopped while frame was in flight
      if (_disposed || !_isMonitoring) {
        await _alarmController.forceStop();
        await _audioAlarmService.stopAlarm();
        await _hapticService.stopAlarmHaptic();
        return;
      }
      await _alarmController.sync(_alertState);

      // Single source of truth update
      _sessionState = _sessionState.copyWith(
        alertState: _alertState,
        alarmPlaying: _alarmController.isPlaying,
      );

      totalStopwatch.stop();
      _totalFrameProcessingTime = totalStopwatch.elapsed;
      _preprocessingTime = _totalFrameProcessingTime > _inferenceTime
          ? _totalFrameProcessingTime - _inferenceTime
          : Duration.zero;

      _processedFramesCount++;
      final elapsedSinceLast =
          now.difference(_lastFrameProcessedTimestamp).inMilliseconds;
      if (elapsedSinceLast > 0) {
        final instantFps = 1000.0 / elapsedSinceLast;
        _processedFps =
            _processedFps == 0.0 ? instantFps : (_processedFps * 0.85 + instantFps * 0.15);
      }
      _lastFrameProcessedTimestamp = now;

      // Throttle UI rebuilds unless alert state changed
      final stateChanged = _alertState != previousAlert;
      _notifyThrottled(now, force: stateChanged);
    } catch (e, st) {
      AppLogger.error(_tag, 'Frame processing failed', e, st);
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Throttles notifyListeners() to 2 Hz max to avoid excessive UI rebuilding in production.
  void _notifyThrottled(DateTime now, {bool force = false}) {
    if (force || now.difference(_lastUiNotificationTimestamp) >= _uiThrottleInterval) {
      _lastUiNotificationTimestamp = now;
      notifyListeners();
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

      if (_currentDriverFace != null) {
        _watchdog.recordFaceDetected(timestamp);
        _sessionState = _sessionState.copyWith(lastFaceDetectedAt: timestamp);
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'Face tracking error', e, st);
    } finally {
      _isDetectingFace = false;
    }
  }

  void _logBackgroundDebug({
    required EyePrediction prediction,
    required DrowsinessAnalysisResult analysisResult,
    required bool alarmPlaying,
  }) {
    // 1. Structured log per Phase 6
    AppLogger.info(
      'BACKGROUND_DEBUG',
      'timestamp=${prediction.timestamp.toIso8601String()} '
      'EyeState=${prediction.state.name} '
      'openScore=${prediction.openScore.toStringAsFixed(3)} '
      'closedScore=${prediction.closedScore.toStringAsFixed(3)} '
      'confidence=${prediction.confidence.toStringAsFixed(3)} '
      'openRatio=${analysisResult.openRatio.toStringAsFixed(2)} '
      'closedRatio=${analysisResult.closedRatio.toStringAsFixed(2)} '
      'unknownRatio=${analysisResult.unknownRatio.toStringAsFixed(2)} '
      'emaOpen=${analysisResult.emaOpenConfidence.toStringAsFixed(2)} '
      'DriverAlertState=${analysisResult.alertState.name} '
      'isRecovering=${analysisResult.isRecovering} '
      'openDuration=${analysisResult.continuousOpenDuration.inMilliseconds}ms '
      'closedDuration=${analysisResult.continuousClosedDuration.inMilliseconds}ms '
      'alarmPlaying=$alarmPlaying '
      'AppLifecycleState=${_currentLifecycleState.name}',
    );

    // 2. High-visibility log per Phase 6
    if (prediction.state == EyeState.open) {
      final buffer = StringBuffer()
        ..writeln('BG prediction=OPEN')
        ..writeln('open=${prediction.openScore.toStringAsFixed(2)}')
        ..writeln('closed=${prediction.closedScore.toStringAsFixed(2)}')
        ..writeln('openRatio=${analysisResult.openRatio.toStringAsFixed(2)}')
        ..writeln('emaOpen=${analysisResult.emaOpenConfidence.toStringAsFixed(2)}')
        ..writeln('recoveryWindow=${analysisResult.continuousOpenDuration.inMilliseconds}ms');

      if (analysisResult.shouldStopAlarm) {
        buffer
          ..writeln('BG RECOVERY CONFIRMED')
          ..writeln('state=NORMAL')
          ..writeln('stopAlarm()')
          ..writeln('alarmPlaying=false');
      } else if (analysisResult.alertState == DriverAlertState.recovering) {
        buffer
          ..writeln('state=RECOVERING')
          ..writeln('alarmPlaying=$alarmPlaying');
      } else {
        buffer
          ..writeln('state=${analysisResult.alertState.name.toUpperCase()}')
          ..writeln('alarmPlaying=$alarmPlaying');
      }

      AppLogger.info('BACKGROUND_MONITOR', buffer.toString().trim());
    }
  }

  /// Test alarm flow for driver readiness validation before a trip.
  Future<void> testAlarm() async {
    try {
      AppLogger.info(_tag, 'Testing alarm sound and haptic feedback...');
      await _alarmController.sync(DriverAlertState.alarm);
      await Future.delayed(const Duration(seconds: 2));
      await _alarmController.stop();
    } catch (e, st) {
      AppLogger.error(_tag, 'Test alarm failed', e, st);
    }
  }

  void setDetectionMode(DetectionMode mode) {
    if (_detectionMode == mode) return;
    _detectionMode = mode;
    _applyDetectionModeConfig();
    AppLogger.info(_tag, 'Detection mode changed to: ${mode.name}');
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
    notifyListeners();
  }

  void setDetectionPipeline(DetectionPipeline pipeline) {
    _classifier.pipeline = pipeline;
    notifyListeners();
  }

  void setOutputMode(ModelOutputMode mode) {
    _classifier.outputMode = mode;
    notifyListeners();
  }

  void setInferenceInterval(Duration interval) {
    _inferenceInterval = interval;
    notifyListeners();
  }

  void setUseDirectFastPipeline(bool value) {
    _classifier.useDirectFastPipeline = value;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  /// App Lifecycle state handling:
  /// CRITICAL (A2): Backgrounding the app (Home / Other app / Screen off) DOES NOT STOP MONITORING!
  /// Monitoring continues via the Android Foreground Service and WakeLock.
  void handleAppLifecycleState(AppLifecycleState state) {
    _currentLifecycleState = state;
    AppLogger.info(_tag, 'AppLifecycleState changed to: ${state.name}');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_isMonitoring) {
          AppLogger.info(
            _tag,
            'UI entered background (${state.name}). Driving monitoring session continues via Foreground Service.',
          );
        }
        break;
      case AppLifecycleState.resumed:
        AppLogger.info(_tag, 'UI resumed. Syncing UI with active driving session.');
        notifyListeners();
        break;
      case AppLifecycleState.detached:
        // Decouple UI lifecycle from driving session lifecycle per Phase 2:
        // Do NOT automatically destroy monitoring runtime if driving session is active!
        if (!_isMonitoring) {
          disposeResources();
        } else {
          AppLogger.warning(
            _tag,
            'UI detached while driving session is ACTIVE. Monitoring runtime preserved in foreground.',
          );
        }
        break;
    }
  }

  /// Clean up all hardware, watchdog, and native resources safely.
  Future<void> disposeResources() async {
    try {
      _watchdog.stop();
    } catch (_) {}
    try {
      await stopMonitoring();
    } catch (_) {}
    try {
      await _alarmController.dispose();
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
      await _audioAlarmService.stopAlarm();
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
    WidgetsBinding.instance.removeObserver(this);
    disposeResources().catchError((e) {
      AppLogger.error(_tag, 'Async disposal error', e);
    });
    super.dispose();
  }
}
