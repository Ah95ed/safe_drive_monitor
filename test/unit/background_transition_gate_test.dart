import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/alarm_controller.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/camera_stream_watchdog.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/driver_face_tracker.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';

class FakeAudioAlarmService implements AudioAlarmService {
  int playAlarmCount = 0;
  int stopAlarmCount = 0;
  int playWarningCount = 0;
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
    _playing = false;
  }
}

class FakeHapticService implements HapticService {
  int startAlarmCount = 0;
  int stopAlarmCount = 0;
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
  Future<void> playWarningHaptic() async {}

  @override
  Future<void> suspendHapticTemporarily({Duration duration = const Duration(seconds: 5)}) async {}

  @override
  Future<void> dispose() async {
    _vibrating = false;
  }
}

void main() {
  group('DriverFaceTracker Lifecycle Epoch Invalidation', () {
    late DriverFaceTracker tracker;
    final now = DateTime(2026, 9, 12, 12, 0, 0);

    setUp(() {
      tracker = DriverFaceTracker();
    });

    DriverFace makeFace({int epoch = 0, DateTime? time}) {
      return DriverFace(
        trackingId: 1,
        boundingBox: const Rect.fromLTWH(100, 100, 200, 250),
        eyeRoi: const Rect.fromLTWH(120, 150, 160, 60),
        detectedAt: time ?? now,
        lifecycleEpoch: epoch,
      );
    }

    test('updates face with epoch and marks it active for same epoch', () {
      final face = tracker.update(
        [makeFace(epoch: 0)],
        timestamp: now,
        lifecycleEpoch: 0,
      );

      expect(face, isNotNull);
      expect(face!.lifecycleEpoch, equals(0));
      expect(tracker.isDriverFaceActive(now, epoch: 0), isTrue);
      expect(tracker.isRoiFresh(now, epoch: 0), isTrue);
    });

    test('rejects face and ROI when epoch mismatches (stale foreground ROI)', () {
      tracker.update(
        [makeFace(epoch: 0)],
        timestamp: now,
        lifecycleEpoch: 0,
      );

      // Transition to background: new epoch = 1
      expect(tracker.isDriverFaceActive(now, epoch: 1), isFalse);
      expect(tracker.isRoiFresh(now, epoch: 1), isFalse);
    });

    test('reset(newEpoch) immediately invalidates previous face and sets currentEpoch', () {
      tracker.update(
        [makeFace(epoch: 0)],
        timestamp: now,
        lifecycleEpoch: 0,
      );
      expect(tracker.lastValidFace, isNotNull);

      tracker.reset(1);

      expect(tracker.lastValidFace, isNull);
      expect(tracker.isDriverFaceActive(now, epoch: 1), isFalse);
      expect(tracker.consecutiveStableDetections, equals(0));
    });

    test('fresh detection in background under new epoch re-arms tracking', () {
      tracker.update([makeFace(epoch: 0)], timestamp: now, lifecycleEpoch: 0);
      tracker.reset(1);

      final bgNow = now.add(const Duration(milliseconds: 300));
      final bgFace1 = tracker.update([makeFace(epoch: 1, time: bgNow)], timestamp: bgNow, lifecycleEpoch: 1);
      expect(bgFace1, isNotNull);
      expect(tracker.consecutiveStableDetections, equals(1));
      expect(tracker.isDriverFaceActive(bgNow, epoch: 1), isTrue);

      final bgNow2 = bgNow.add(const Duration(milliseconds: 200));
      final bgFace2 = tracker.update([makeFace(epoch: 1, time: bgNow2)], timestamp: bgNow2, lifecycleEpoch: 1);
      expect(bgFace2, isNotNull);
      expect(tracker.consecutiveStableDetections, equals(2));
      expect(tracker.isTrackingStable, isTrue);
    });
  });

  group('DrowsinessAnalyzer Transient Evidence Clearing & Alarm Preservation', () {
    late DrowsinessAnalyzer analyzer;
    final baseTime = DateTime(2026, 9, 12, 12, 0, 0);

    setUp(() {
      analyzer = DrowsinessAnalyzer();
    });

    test('resetTransientEvidence clears closedStartedAt without triggering alarm', () {
      // Feed closed prediction for 600ms (below alarm threshold 1200ms)
      analyzer.processPrediction(
        EyePrediction.closed(confidence: 0.95, timestamp: baseTime),
        hasDriverFace: true,
        now: baseTime,
      );

      final midTime = baseTime.add(const Duration(milliseconds: 600));
      final res1 = analyzer.processPrediction(
        EyePrediction.closed(confidence: 0.95, timestamp: midTime),
        hasDriverFace: true,
        now: midTime,
      );
      expect(res1.alertState, isNot(equals(DriverAlertState.alarm)));

      // Transition to background happens: reset transient evidence
      analyzer.resetTransientEvidence();

      // Next prediction after transition should NOT accumulate from the 600ms
      final bgTime = midTime.add(const Duration(milliseconds: 700));
      final res2 = analyzer.processPrediction(
        EyePrediction.closed(confidence: 0.95, timestamp: bgTime),
        hasDriverFace: true,
        now: bgTime,
      );

      // Since closedStartedAt was reset, duration is 0ms, NOT 1300ms!
      expect(res2.alertState, equals(DriverAlertState.normal));
      expect(res2.shouldTriggerAlarm, isFalse);
    });

    test('resetTransientEvidence strictly preserves pre-existing confirmed alarm', () {
      // Drive alert into ALARM state (1300ms continuous closed)
      analyzer.processPrediction(
        EyePrediction.closed(confidence: 0.95, timestamp: baseTime),
        hasDriverFace: true,
        now: baseTime,
      );

      final alarmTime = baseTime.add(const Duration(milliseconds: 1300));
      final alarmRes = analyzer.processPrediction(
        EyePrediction.closed(confidence: 0.95, timestamp: alarmTime),
        hasDriverFace: true,
        now: alarmTime,
      );

      expect(alarmRes.alertState, equals(DriverAlertState.alarm));
      expect(alarmRes.shouldTriggerAlarm, isTrue);

      // Now app moves to background while alarm is active
      analyzer.resetTransientEvidence();

      // State MUST remain alarm!
      expect(analyzer.currentState, equals(DriverAlertState.alarm));
    });
  });

  group('CameraStreamWatchdog Lifecycle Transition Grace', () {
    test('transition grace suppresses false camera stall during OS jitter', () {
      final watchdog = MonitoringWatchdog(
        config: const WatchdogConfig(
          cameraStallTimeout: Duration(milliseconds: 800),
          transitionGrace: Duration(milliseconds: 1200),
        ),
      );

      final now = DateTime(2026, 9, 12, 12, 0, 0);
      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      // Simulate background transition
      final transitionTime = now.add(const Duration(milliseconds: 400));
      watchdog.recordLifecycleTransition(transitionTime);

      // Evaluate at 900ms after last frame (normally 800ms would trigger stall)
      final evalTime = now.add(const Duration(milliseconds: 900));
      final report = watchdog.evaluateHealth(evalTime);

      // Since evalTime is within transitionGrace (transitionTime + 1200ms = now + 1600ms),
      // no camera stall is triggered and health is healthy!
      expect(report.issue, isNot(equals(MonitoringIssue.cameraStalled)));
      expect(report.health, equals(MonitoringHealth.healthy));
    });
  });

  group('AlarmController Reason and Diagnostics Sync', () {
    late AlarmController controller;
    late FakeAudioAlarmService audio;
    late FakeHapticService haptic;

    setUp(() {
      audio = FakeAudioAlarmService();
      haptic = FakeHapticService();
      controller = AlarmController(audio, haptic);
    });

    test('sync with alarm records reason and starts audio/haptic', () async {
      await controller.sync(
        DriverAlertState.alarm,
        reason: AlarmTriggerReason.drowsiness,
        diagnostics: {'closedDurationMs': 1300, 'epoch': 1},
      );

      expect(controller.isPlaying, isTrue);
      expect(controller.activeReason, equals(AlarmTriggerReason.drowsiness));
      expect(audio.playAlarmCount, equals(1));
      expect(haptic.startAlarmCount, equals(1));
    });

    test('stop resets activeReason to none', () async {
      await controller.sync(
        DriverAlertState.alarm,
        reason: AlarmTriggerReason.drowsiness,
      );
      expect(controller.activeReason, equals(AlarmTriggerReason.drowsiness));

      await controller.stop();
      expect(controller.isPlaying, isFalse);
      expect(controller.activeReason, equals(AlarmTriggerReason.none));
      expect(audio.stopAlarmCount, equals(1));
      expect(haptic.stopAlarmCount, equals(1));
    });
  });
}
