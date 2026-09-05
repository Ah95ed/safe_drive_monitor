import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/services/alarm_controller.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/battery_optimization_service.dart';
import 'package:safe_drive_monitor/core/services/foreground_monitoring_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/camera_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/eye_state_classifier.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/face_detection_service.dart';
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
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/low_light_detector.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';

// ==================== FAKE SERVICES ====================

class FakeAudioAlarmService implements AudioAlarmService {
  int playAlarmCount = 0;
  int stopAlarmCount = 0;
  int playWarningCount = 0;
  int disposeCount = 0;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> playAlarm() async {
    playAlarmCount++;
    _playing = true;
  }

  @override
  Future<void> stopAlarm() async {
    stopAlarmCount++;
    _playing = false;
  }

  @override
  Future<void> playTechnicalWarning() async {
    playWarningCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _playing = false;
  }
}

class FakeHapticService implements HapticService {
  int startAlarmCount = 0;
  int stopAlarmCount = 0;
  int warningCount = 0;
  int suspendCount = 0;
  int disposeCount = 0;
  bool _vibrating = false;

  @override
  bool get isVibrating => _vibrating;

  @override
  Future<void> startAlarmHaptic() async {
    startAlarmCount++;
    _vibrating = true;
  }

  @override
  Future<void> stopAlarmHaptic() async {
    stopAlarmCount++;
    _vibrating = false;
  }

  @override
  Future<void> suspendHapticTemporarily({
    Duration duration = const Duration(milliseconds: 350),
  }) async {
    suspendCount++;
    _vibrating = false;
  }

  @override
  Future<void> playWarningHaptic() async {
    warningCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _vibrating = false;
  }
}

class FakeCameraService implements CameraService {
  bool _isInitialized = false;
  bool _isStreaming = false;
  int stopStreamCalls = 0;
  int startStreamCalls = 0;

  @override
  CameraController? get controller => null;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isStreaming => _isStreaming;

  @override
  int get sensorOrientation => 0;

  @override
  double get minExposureOffset => -2.0;

  @override
  double get maxExposureOffset => 2.0;

  @override
  double get exposureStepSize => 0.5;

  @override
  double get currentExposureOffset => 0.0;

  @override
  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    _isInitialized = true;
  }

  @override
  Future<void> startImageStream(void Function(CameraImage image) onImage) async {
    startStreamCalls++;
    _isStreaming = true;
  }

  @override
  Future<void> stopImageStream() async {
    stopStreamCalls++;
    _isStreaming = false;
  }

  @override
  Future<double> setExposureOffset(double offset) async => offset;

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _isStreaming = false;
  }
}

class FakeForegroundMonitoringService implements ForegroundMonitoringService {
  bool isRunning = false;
  int startServiceCalls = 0;
  int stopServiceCalls = 0;
  int moveTaskToBackgroundCalls = 0;
  List<String> notificationStatusUpdates = [];
  Future<void> Function()? notificationStopHandler;

  @override
  Future<bool> startForegroundService() async {
    startServiceCalls++;
    isRunning = true;
    return true;
  }

  @override
  Future<bool> stopForegroundService() async {
    stopServiceCalls++;
    isRunning = false;
    return true;
  }

  @override
  Future<bool> isForegroundServiceRunning() async => isRunning;

  @override
  Future<bool> isLowLightBoostSupported() async => false;

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<bool> moveTaskToBackground() async {
    moveTaskToBackgroundCalls++;
    return true;
  }

  @override
  Future<bool> updateNotificationStatus(String statusText) async {
    notificationStatusUpdates.add(statusText);
    return true;
  }

  @override
  void setNotificationStopHandler(Future<void> Function()? handler) {
    notificationStopHandler = handler;
  }
}

class FakeEyeStateClassifier implements EyeStateClassifier {
  @override
  bool isLoaded = false;

  @override
  ModelArchitecture architecture = ModelArchitecture.yoloDetector;

  @override
  bool invertYoloClasses = false;

  @override
  TensorChannelLayout channelLayout = TensorChannelLayout.interleavedRgb;

  @override
  DetectionPipeline pipeline = DetectionPipeline.faceAware;

  @override
  ModelOutputMode outputMode = ModelOutputMode.auto;

  @override
  double minOpenConfidence = 0.50;

  @override
  double minClosedConfidence = 0.55;

  @override
  bool useDirectFastPipeline = true;

  @override
  set roiStrategy(RoiStrategy value) {}

  @override
  Future<void> load() async {
    isLoaded = true;
  }

  @override
  Future<EyePrediction> classify(
    CameraImage image, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
  }) async {
    return EyePrediction.unknown(timestamp: DateTime.now());
  }

  @override
  Future<EyePrediction> classifyFloat32(Float32List inputBuffer) async {
    return EyePrediction.unknown(timestamp: DateTime.now());
  }

  @override
  Future<void> dispose() async {
    isLoaded = false;
  }
}

class FakeFaceDetectionService implements FaceDetectionService {
  @override
  Future<List<DriverFace>> detectFaces(
    CameraImage image, {
    int sensorRotation = 0,
  }) async => [];

  @override
  Future<void> dispose() async {}
}

class FakeBatteryOptimizationService implements BatteryOptimizationService {
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => true;

  @override
  Future<void> openBatterySettings() async {}
}

// ==================== UNIT TESTS ====================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime baseTime = DateTime(2026, 1, 1, 12, 0, 0);

  EyePrediction createPrediction({
    required EyeState state,
    required Duration timeOffset,
    double confidence = 0.90,
    double openScore = 0.90,
    double closedScore = 0.10,
  }) {
    return EyePrediction(
      state: state,
      openScore: state == EyeState.open ? openScore : (1.0 - confidence),
      closedScore: state == EyeState.closed ? confidence : (1.0 - openScore),
      confidence: confidence,
      inferenceTime: const Duration(milliseconds: 25),
      timestamp: baseTime.add(timeOffset),
    );
  }

  group('Requirement 1 & 2: Rolling Window Alarm Recovery State Machine', () {
    late DrowsinessAnalyzer analyzer;
    late FakeAudioAlarmService audioService;
    late FakeHapticService hapticService;
    late AlarmController alarmController;

    setUp(() {
      analyzer = DrowsinessAnalyzer(
        config: const DrowsinessConfig(
          watchingThreshold: Duration(milliseconds: 400),
          drowsyThreshold: Duration(milliseconds: 1000),
          alarmThreshold: Duration(milliseconds: 1500),
          recoveryThreshold: Duration(milliseconds: 1000),
          recoveryWindowDuration: Duration(milliseconds: 1000),
          recoveryMinOpenRatio: 0.70,
          recoveryMinEmaConfidence: 0.60,
        ),
      );
      audioService = FakeAudioAlarmService();
      hapticService = FakeHapticService();
      alarmController = AlarmController(audioService, hapticService);
    });

    test('Test 1: Foreground alarm triggers on closed eyes and recovers after rolling open window', () async {
      // 1. Prolonged closed eyes -> triggers alarm
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final alarmRes = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(alarmRes.alertState, equals(DriverAlertState.alarm));
      expect(alarmRes.shouldTriggerAlarm, isTrue);

      await alarmController.sync(alarmRes.alertState);
      expect(alarmController.isPlaying, isTrue);
      expect(audioService.playAlarmCount, equals(1));

      // 2. Eyes reopen: send open frames starting from 1700ms
      analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1700),
      ));
      final midRecovery = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2100),
      ));
      // In first 400ms, still in recovering (alarm must NOT stop prematurely)
      expect(midRecovery.alertState.isAlarm, isTrue);
      expect(midRecovery.alertState, equals(DriverAlertState.recovering));
      expect(midRecovery.shouldStopAlarm, isFalse);

      await alarmController.sync(midRecovery.alertState);
      expect(alarmController.isPlaying, isTrue, reason: 'Alarm should keep sounding during recovery period');

      // 3. Eyes stay open through full 1000ms recovery window -> recovers to NORMAL
      DrowsinessAnalysisResult? lastRecoveryResult;
      for (int t = 2200; t <= 2800; t += 100) {
        final res = analyzer.processPrediction(createPrediction(
          state: EyeState.open,
          timeOffset: Duration(milliseconds: t),
        ));
        if (res.alertState == DriverAlertState.normal) {
          lastRecoveryResult = res;
          break;
        }
      }
      expect(lastRecoveryResult, isNotNull);
      expect(lastRecoveryResult!.alertState, equals(DriverAlertState.normal));
      expect(lastRecoveryResult.shouldStopAlarm, isTrue);

      await alarmController.sync(lastRecoveryResult.alertState);
      expect(alarmController.isPlaying, isFalse);
      expect(audioService.stopAlarmCount, equals(1));
    });

    test('Test 2: Background alarm recovery works identically with rolling window', () async {
      // Simulate background session
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      await alarmController.sync(rAlarm.alertState);
      expect(alarmController.isPlaying, isTrue);

      // Reopen eyes in background across rolling window
      for (int t = 1700; t < 2650; t += 100) {
        analyzer.processPrediction(createPrediction(
          state: EyeState.open,
          timeOffset: Duration(milliseconds: t),
        ));
      }
      final rRecover = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2700),
      ));
      expect(rRecover.alertState, equals(DriverAlertState.normal));
      await alarmController.sync(rRecover.alertState);
      expect(alarmController.isPlaying, isFalse);
    });

    test('Test 5: Tolerance to isolated noisy CLOSED frame during recovery window (Requirement Phase 8)', () async {
      // Trigger alarm
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(analyzer.isAlarmActive, isTrue);

      // Driver opens eyes at 1700ms. Send open frames:
      // 1700, 1800, 1900, 2000 (4 open frames)
      for (int t = 1700; t <= 2000; t += 100) {
        analyzer.processPrediction(createPrediction(
          state: EyeState.open,
          timeOffset: Duration(milliseconds: t),
        ));
      }

      // 2100ms: One isolated low-confidence noisy CLOSED frame (e.g. shadow / eye twitch)
      final noisyFrame = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 2100),
        confidence: 0.58,
        closedScore: 0.58,
      ));
      // Should remain in recovering, not abort or crash
      expect(noisyFrame.alertState.isAlarm, isTrue);

      // 2200, 2300, 2400, 2500, 2600, 2700, 2800: OPEN frames continue
      for (int t = 2200; t <= 2800; t += 100) {
        analyzer.processPrediction(createPrediction(
          state: EyeState.open,
          timeOffset: Duration(milliseconds: t),
        ));
      }

      // With open frames and 1 isolated noisy closed frame (open ratio > 85% >= 70%),
      // recovery should succeed and NOT be blocked by the single noisy frame!
      expect(analyzer.currentState, equals(DriverAlertState.normal));
      expect(analyzer.isAlarmActive, isFalse);
    });

    test('Test 6: False recovery protection - strong closed relapse during recovery aborts to ALARM', () async {
      // Trigger alarm
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(analyzer.isAlarmActive, isTrue);

      // Driver opens eyes briefly at 1700ms and 1800ms
      analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1700),
      ));
      final recoveringRes = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1800),
      ));
      expect(recoveringRes.alertState, equals(DriverAlertState.recovering));

      // Driver immediately falls back asleep! Strong CLOSED frame at 1950ms (conf: 0.85)
      final relapseRes = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1950),
        confidence: 0.85,
        closedScore: 0.85,
      ));

      // Recovery must be aborted and alert state must be ALARM (not recovering, not normal)
      expect(relapseRes.alertState, equals(DriverAlertState.alarm));
      expect(relapseRes.shouldStopAlarm, isFalse);
      expect(analyzer.isAlarmActive, isTrue);
    });

    test('Test 7: UNKNOWN frames during ALARM do not stop the alarm or trigger false recovery', () async {
      // Trigger alarm
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(analyzer.isAlarmActive, isTrue);

      // Series of UNKNOWN frames with face present (e.g. motion blur, extreme angle)
      for (int t = 1700; t <= 3000; t += 200) {
        final res = analyzer.processPrediction(
          EyePrediction.unknown(timestamp: baseTime.add(Duration(milliseconds: t))),
          hasDriverFace: true,
        );
        expect(res.alertState, equals(DriverAlertState.alarm));
        expect(res.shouldStopAlarm, isFalse);
        expect(analyzer.isAlarmActive, isTrue);
      }
    });
  });

  group('Requirement 3, 4, 8 & 9: Provider, Watchdog & Lifecycle Integration', () {
    late FakeCameraService cameraService;
    late FakeEyeStateClassifier classifier;
    late FakeFaceDetectionService faceDetectionService;
    late DriverFaceTracker faceTracker;
    late MonitoringWatchdog watchdog;
    late LightingManager lightingManager;
    late DrowsinessAnalyzer drowsinessAnalyzer;
    late FakeAudioAlarmService audioService;
    late FakeHapticService hapticService;
    late FakeBatteryOptimizationService batteryOptService;
    late FakeForegroundMonitoringService foregroundService;
    late DrowsinessDetectionProvider provider;

    setUp(() {
      cameraService = FakeCameraService();
      classifier = FakeEyeStateClassifier();
      faceDetectionService = FakeFaceDetectionService();
      faceTracker = DriverFaceTracker();
      watchdog = MonitoringWatchdog(
        config: const WatchdogConfig(
          cameraStallTimeout: Duration(milliseconds: 500),
          inferenceStallTimeout: Duration(milliseconds: 1000),
          checkInterval: Duration(milliseconds: 50),
        ),
      );
      lightingManager = LightingManager();
      drowsinessAnalyzer = DrowsinessAnalyzer();
      audioService = FakeAudioAlarmService();
      hapticService = FakeHapticService();
      batteryOptService = FakeBatteryOptimizationService();
      foregroundService = FakeForegroundMonitoringService();

      provider = DrowsinessDetectionProvider(
        cameraService: cameraService,
        classifier: classifier,
        faceDetectionService: faceDetectionService,
        faceTracker: faceTracker,
        watchdog: watchdog,
        lowLightDetector: lightingManager,
        drowsinessAnalyzer: drowsinessAnalyzer,
        audioAlarmService: audioService,
        hapticService: hapticService,
        batteryOptService: batteryOptService,
        foregroundService: foregroundService,
      );
    });

    tearDown(() async {
      await provider.hardStopAll();
      provider.dispose();
    });

    test('Test 3: Back Button delegate to moveTaskToBackground() without killing monitoring', () async {
      await provider.initialize();
      await provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);

      // User presses Back button: driver_monitor_screen calls moveTaskToBackground()
      final moved = await provider.moveTaskToBackground();
      expect(moved, isTrue);
      expect(foregroundService.moveTaskToBackgroundCalls, equals(1));

      // Session remains active and monitoring
      expect(provider.isMonitoring, isTrue);
      expect(provider.sessionState.active, isTrue);
    });

    test('Test 4: Native notification STOP button triggers hardStopAll() cleanly', () async {
      await provider.initialize();
      await provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);
      expect(cameraService.isStreaming, isTrue);
      expect(foregroundService.isRunning, isTrue);

      // Verify notification stop handler is registered
      expect(foregroundService.notificationStopHandler, isNotNull);

      // Simulate native notification STOP action
      await foregroundService.notificationStopHandler!();

      // Everything must be cleanly stopped
      expect(provider.isMonitoring, isFalse);
      expect(cameraService.isStreaming, isFalse);
      expect(cameraService.stopStreamCalls, greaterThanOrEqualTo(1));
      expect(foregroundService.stopServiceCalls, greaterThanOrEqualTo(1));
      expect(audioService.stopAlarmCount, greaterThanOrEqualTo(1));
      expect(hapticService.stopAlarmCount, greaterThanOrEqualTo(1));
      expect(provider.sessionState.active, isFalse);
    });

    test('Test 8: Watchdog detects camera stream stall and updates notification to prevent ghost status', () async {
      await provider.initialize();
      await provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);

      // Simulate watchdog detecting camera stall
      final startTime = DateTime.now();
      watchdog.recordCameraFrameHeartbeat(startTime);
      watchdog.recordInferenceHeartbeat(startTime);

      final lateTime = startTime.add(const Duration(milliseconds: 1500));
      // Trigger immediate watchdog health check tick at lateTime
      await watchdog.checkHealthTick(now: lateTime);

      // Verify watchdog health handler triggers failure notification update
      expect(foregroundService.notificationStatusUpdates.any((s) => s.contains('⚠️ توقف نظام المراقبة')), isTrue);
    });

    test('Test 9: hardStopAll() is idempotent and safe against concurrent/repeated calls', () async {
      await provider.initialize();
      await provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);

      // Call hardStopAll concurrently 3 times
      await Future.wait([
        provider.hardStopAll(),
        provider.hardStopAll(),
        provider.hardStopAll(),
      ]);

      expect(provider.isMonitoring, isFalse);
      expect(provider.sessionState.active, isFalse);
      expect(cameraService.isStreaming, isFalse);

      // Sequential call after already stopped
      await provider.hardStopAll();
      expect(provider.isMonitoring, isFalse);
    });
  });
}
