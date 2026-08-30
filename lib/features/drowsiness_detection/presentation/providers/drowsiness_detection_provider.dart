import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/camera_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/eye_state_classifier.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/legacy_decision_analyzer.dart';

class DrowsinessDetectionProvider extends ChangeNotifier {
  static const String _tag = 'DrowsinessProvider';

  final CameraService _cameraService;
  final EyeStateClassifier _classifier;
  final DrowsinessAnalyzer _drowsinessAnalyzer;
  final LegacyDecisionAnalyzer _legacyAnalyzer;
  final AudioAlarmService _audioAlarmService;
  final HapticService _hapticService;

  bool _isInitialized = false;
  bool _isMonitoring = false;
  bool _isProcessingFrame = false;
  Object? _error;
  String _statusMessage = 'جاهز لبدء المراقبة';

  EyePrediction? _lastPrediction;
  DriverAlertState _alertState = DriverAlertState.normal;
  DetectionMode _detectionMode = DetectionMode.javaCompatible;

  // Performance & Profiling Metrics
  Duration _preprocessingTime = Duration.zero;
  Duration _inferenceTime = Duration.zero;
  Duration _totalFrameProcessingTime = Duration.zero;
  DateTime _lastFrameProcessedTimestamp = DateTime.now();
  DateTime _lastInferenceTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  double _processedFps = 0.0;
  int _droppedFramesCount = 0;
  int _processedFramesCount = 0;

  /// Configurable throttling interval (~6-7 inference cycles per second)
  Duration _inferenceInterval = AppConstants.defaultInferenceInterval;

  DrowsinessDetectionProvider({
    CameraService? cameraService,
    EyeStateClassifier? classifier,
    DrowsinessAnalyzer? drowsinessAnalyzer,
    LegacyDecisionAnalyzer? legacyAnalyzer,
    AudioAlarmService? audioAlarmService,
    HapticService? hapticService,
  })  : _cameraService = cameraService ?? AppCameraService(),
        _classifier = classifier ?? TfliteEyeStateClassifier(),
        _drowsinessAnalyzer = drowsinessAnalyzer ?? DrowsinessAnalyzer(),
        _legacyAnalyzer = legacyAnalyzer ?? LegacyDecisionAnalyzer(),
        _audioAlarmService = audioAlarmService ?? AppAudioAlarmService(),
        _hapticService = hapticService ?? AppHapticService();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  bool get isModelLoaded => _classifier.isLoaded;
  bool get isCameraReady => _cameraService.isInitialized;
  CameraController? get cameraController => _cameraService.controller;

  EyePrediction? get lastPrediction => _lastPrediction;
  DriverAlertState get alertState => _alertState;
  String get statusMessage => _statusMessage;
  Object? get error => _error;

  DetectionMode get detectionMode => _detectionMode;
  DetectionPipeline get detectionPipeline => _classifier.pipeline;
  TensorChannelLayout get tensorLayout => _classifier.channelLayout;
  DrowsinessConfig get config => _drowsinessAnalyzer.config;

  Duration get preprocessingTime => _preprocessingTime;
  Duration get inferenceTime => _inferenceTime;
  Duration get totalFrameProcessingTime => _totalFrameProcessingTime;
  double get processedFps => _processedFps;
  int get droppedFramesCount => _droppedFramesCount;
  int get processedFramesCount => _processedFramesCount;
  Duration get inferenceInterval => _inferenceInterval;
  bool get isLegacyAlarmTriggered => _legacyAnalyzer.isAlarmTriggered;

  /// Initialize Camera and TensorFlow Lite Model.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _error = null;
    _statusMessage = 'جاري تهيئة الكاميرا ونموذج الذكاء الاصطناعي...';
    notifyListeners();

    try {
      await Future.wait([
        _cameraService.initialize(lensDirection: CameraLensDirection.front),
        _classifier.load(),
      ]);

      _isInitialized = true;
      _statusMessage = 'تمت التهيئة بنجاح. اضغط على زر البدء لبدء المراقبة.';
      AppLogger.info(_tag, 'Drowsiness detection provider initialized.');
      notifyListeners();
    } catch (e, st) {
      _error = e;
      _statusMessage = e is AppException ? e.message : 'فشل في تهيئة النظام';
      AppLogger.error(_tag, 'Initialization error', e, st);
      notifyListeners();
    }
  }

  /// Start real-time image analysis stream.
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }
    if (_isMonitoring) return;

    try {
      _error = null;
      _isMonitoring = true;
      _statusMessage = 'جاري مراقبة حالة السائق...';
      _drowsinessAnalyzer.reset();
      _legacyAnalyzer.reset();
      _droppedFramesCount = 0;
      _processedFramesCount = 0;
      _lastInferenceTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

      await _cameraService.startImageStream(_handleCameraFrame);
      AppLogger.info(_tag, 'Monitoring session started.');
      notifyListeners();
    } catch (e, st) {
      _isMonitoring = false;
      _error = e;
      _statusMessage = 'فشل في بدء المراقبة';
      AppLogger.error(_tag, 'Start monitoring error', e, st);
      notifyListeners();
    }
  }

  /// Stop monitoring, camera stream, and audio alarm.
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;
      await _cameraService.stopImageStream();
      await _stopAlarmFeedback();
      _drowsinessAnalyzer.reset();
      _legacyAnalyzer.reset();
      _alertState = DriverAlertState.normal;
      _statusMessage = 'تم إيقاف المراقبة';
      AppLogger.info(_tag, 'Monitoring session stopped.');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(_tag, 'Stop monitoring error', e, st);
    }
  }

  /// Process camera frame callback with non-blocking guard.
  void _handleCameraFrame(CameraImage image) async {
    final now = DateTime.now();

    // Guard 1: Ignore frame if monitoring is off or inference is already running
    if (!_isMonitoring || _isProcessingFrame) {
      _droppedFramesCount++;
      return;
    }

    // Guard 2: Throttling interval to avoid overheating and unnecessary CPU consumption
    if (now.difference(_lastInferenceTimestamp) < _inferenceInterval) {
      _droppedFramesCount++;
      return;
    }

    _isProcessingFrame = true;
    _lastInferenceTimestamp = now;

    try {
      final totalStopwatch = Stopwatch()..start();

      // 1. Preprocessing + Inference via Classifier
      final prediction = await _classifier.classify(
        image,
        sensorRotation: _cameraService.sensorOrientation,
      );

      _inferenceTime = prediction.inferenceTime;

      // 2. Legacy comparison analysis
      _legacyAnalyzer.processPrediction(prediction);

      // 3. Time-based Drowsiness State Machine Analysis
      final analysisResult = _drowsinessAnalyzer.processPrediction(prediction);
      _alertState = analysisResult.alertState;
      _statusMessage = analysisResult.statusMessage;
      _lastPrediction = prediction;

      // 4. Handle audio and vibration alarms
      if (analysisResult.shouldTriggerAlarm) {
        await _triggerAlarmFeedback();
      } else if (analysisResult.shouldStopAlarm) {
        await _stopAlarmFeedback();
      }

      totalStopwatch.stop();
      _totalFrameProcessingTime = totalStopwatch.elapsed;
      _preprocessingTime = _totalFrameProcessingTime > _inferenceTime
          ? _totalFrameProcessingTime - _inferenceTime
          : Duration.zero;

      // 5. Update FPS metric
      _processedFramesCount++;
      final elapsedSinceLast =
          now.difference(_lastFrameProcessedTimestamp).inMilliseconds;
      if (elapsedSinceLast > 0) {
        _processedFps = 1000.0 / elapsedSinceLast;
      }
      _lastFrameProcessedTimestamp = now;

      notifyListeners();
    } catch (e, st) {
      AppLogger.error(_tag, 'Frame processing failed', e, st);
    } finally {
      _isProcessingFrame = false;
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
    AppLogger.info(_tag, 'Detection mode changed to: ${mode.name}');
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

  void setInferenceInterval(Duration interval) {
    _inferenceInterval = interval;
    notifyListeners();
  }

  /// App Lifecycle state handling
  void handleAppLifecycleState(AppLifecycleState state) {
    AppLogger.info(_tag, 'AppLifecycleState changed to: ${state.name}');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_isMonitoring) {
          stopMonitoring();
        }
        break;
      case AppLifecycleState.resumed:
        // Ready for user to resume
        break;
      case AppLifecycleState.detached:
        disposeResources();
        break;
    }
  }

  /// Clean up all hardware and native resources
  Future<void> disposeResources() async {
    await stopMonitoring();
    await _cameraService.dispose();
    await _classifier.dispose();
    await _audioAlarmService.dispose();
    await _hapticService.dispose();
    _isInitialized = false;
  }

  @override
  void dispose() {
    disposeResources();
    super.dispose();
  }
}
