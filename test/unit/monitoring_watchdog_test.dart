import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/camera_stream_watchdog.dart';

void main() {
  group('MonitoringWatchdog & Health Evaluation', () {
    late MonitoringWatchdog watchdog;

    setUp(() {
      watchdog = MonitoringWatchdog(
        config: const WatchdogConfig(
          cameraStallTimeout: Duration(milliseconds: 1000),
          inferenceStallTimeout: Duration(milliseconds: 1500),
          faceLostTimeout: Duration(milliseconds: 2000),
          checkInterval: Duration(milliseconds: 100),
        ),
      );
    });

    tearDown(() {
      watchdog.stop();
    });

    test('Initial state before starting evaluates to healthy', () {
      final eval = watchdog.evaluateHealth(DateTime.now());
      expect(eval.health, MonitoringHealth.healthy);
      expect(eval.issue, MonitoringIssue.none);
    });

    test('Fresh heartbeats maintain healthy state', () {
      watchdog.start(onCameraStallDetected: () async {});
      final now = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);
      watchdog.recordFaceDetected(now);

      final eval = watchdog.evaluateHealth(now);
      expect(eval.health, MonitoringHealth.healthy);
      expect(eval.issue, MonitoringIssue.none);
    });

    test('Detects camera stall when frames stop arriving', () {
      watchdog.start(onCameraStallDetected: () async {});
      final startTime = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(startTime);
      watchdog.recordInferenceHeartbeat(startTime);

      final lateTime = startTime.add(const Duration(milliseconds: 1200));
      final eval = watchdog.evaluateHealth(lateTime);

      expect(eval.health, MonitoringHealth.failed);
      expect(eval.issue, MonitoringIssue.cameraStalled);
    });

    test('Detects inference stall when frames arrive but AI does not process', () {
      watchdog.start(onCameraStallDetected: () async {});
      final startTime = DateTime.now();

      watchdog.recordInferenceHeartbeat(startTime);

      // Camera frames keep arriving fresh at lateTime, but inference stayed at startTime
      final lateTime = startTime.add(const Duration(milliseconds: 1800));
      watchdog.recordCameraFrameHeartbeat(lateTime);

      final eval = watchdog.evaluateHealth(lateTime);

      expect(eval.health, MonitoringHealth.failed);
      expect(eval.issue, MonitoringIssue.inferenceStalled);
    });

    test('Detects insufficient light degradation', () {
      watchdog.start(onCameraStallDetected: () async {});
      final now = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);
      watchdog.recordLightingState(isCritical: true);

      final eval = watchdog.evaluateHealth(now);
      expect(eval.health, MonitoringHealth.degraded);
      expect(eval.issue, MonitoringIssue.insufficientLight);
    });

    test('Detects driver face lost degradation', () {
      watchdog.start(onCameraStallDetected: () async {});
      final startTime = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(startTime);
      watchdog.recordInferenceHeartbeat(startTime);
      watchdog.recordFaceDetected(startTime);

      final lateTime = startTime.add(const Duration(milliseconds: 2500));
      watchdog.recordCameraFrameHeartbeat(lateTime);
      watchdog.recordInferenceHeartbeat(lateTime);

      final eval = watchdog.evaluateHealth(lateTime);
      expect(eval.health, MonitoringHealth.degraded);
      expect(eval.issue, MonitoringIssue.noDriverFace);
    });
  });

  group('DrivingSessionState', () {
    test('isActuallyWorking requires active session + fresh frames + fresh inference', () {
      final now = DateTime.now();

      // Inactive session
      final idle = DrivingSessionState.idle();
      expect(idle.isActuallyWorking(now: now), isFalse);

      // Active but no frames yet
      final justStarted = DrivingSessionState(
        active: true,
        startedAt: now,
      );
      expect(justStarted.isActuallyWorking(now: now), isFalse);

      // Active with fresh frames and inference
      final running = DrivingSessionState(
        active: true,
        startedAt: now,
        lastCameraFrameAt: now.subtract(const Duration(milliseconds: 200)),
        lastInferenceAt: now.subtract(const Duration(milliseconds: 300)),
        health: MonitoringHealth.healthy,
      );
      expect(running.isActuallyWorking(now: now), isTrue);

      // Active but stale frame
      final stale = running.copyWith(
        lastCameraFrameAt: now.subtract(const Duration(milliseconds: 4000)),
      );
      expect(stale.isActuallyWorking(now: now), isFalse);
    });
  });
}
