import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/camera_stream_watchdog.dart';

void main() {
  group('Watchdog Auto-Recovery State Machine (Phases 5, 6, 7, 13, 14)', () {
    late MonitoringWatchdog watchdog;

    setUp(() {
      watchdog = MonitoringWatchdog(
        config: const WatchdogConfig(
          cameraStallTimeout: Duration(milliseconds: 1000),
          inferenceStallTimeout: Duration(milliseconds: 1500),
          faceLostTimeout: Duration(milliseconds: 2000),
          transitionGrace: Duration(milliseconds: 800),
          checkInterval: Duration(milliseconds: 100),
        ),
      );
    });

    tearDown(() {
      watchdog.stop();
    });

    test('Initial stall transitions to recovering, not failed', () {
      watchdog.start();
      final now = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      final stallTime = now.add(const Duration(milliseconds: 1200));
      final eval = watchdog.evaluateHealth(stallTime);

      expect(eval.health, equals(MonitoringHealth.recovering));
      expect(eval.issue, equals(MonitoringIssue.cameraStalled));
    });

    test('Camera recovery callback is triggered upon stall detection and restores healthy on success', () async {
      int recoveryAttemptCalled = 0;

      watchdog.start(
        onCameraRecoveryRequested: ({required int attempt}) async {
          recoveryAttemptCalled = attempt;
          return true;
        },
      );

      final now = DateTime.now();
      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      final stallTime = now.add(const Duration(milliseconds: 1200));
      await watchdog.checkHealthTick(now: stallTime);

      expect(recoveryAttemptCalled, equals(1));
      // Auto-recovery succeeded seamlessly -> restored to healthy!
      expect(watchdog.currentHealth, equals(MonitoringHealth.healthy));
      expect(watchdog.currentIssue, equals(MonitoringIssue.none));
    });

    test('Receiving fresh frame during recovering seamlessly restores healthy state', () async {
      watchdog.start();
      final now = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      final stallTime = now.add(const Duration(milliseconds: 1200));
      await watchdog.checkHealthTick(now: stallTime);
      expect(watchdog.currentHealth, equals(MonitoringHealth.recovering));

      // New frame arrives
      final freshFrameTime = stallTime.add(const Duration(milliseconds: 200));
      watchdog.recordCameraFrameHeartbeat(freshFrameTime);
      watchdog.recordInferenceHeartbeat(freshFrameTime);

      await watchdog.checkHealthTick(now: freshFrameTime);
      expect(watchdog.currentHealth, equals(MonitoringHealth.healthy));
      expect(watchdog.currentIssue, equals(MonitoringIssue.none));
    });

    test('Exhausting recovery attempts (>=2) transitions to failed', () async {
      int attempts = 0;

      watchdog.start(
        onCameraRecoveryRequested: ({required int attempt}) async {
          attempts = attempt;
          return false; // recovery failed
        },
      );

      final now = DateTime.now();
      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      // Tick 1: triggers attempt #1 -> recovering
      final stallTime1 = now.add(const Duration(milliseconds: 1200));
      await watchdog.checkHealthTick(now: stallTime1);
      expect(attempts, equals(1));
      expect(watchdog.currentHealth, equals(MonitoringHealth.recovering));

      // Tick 2: triggers attempt #2 -> recovering
      final stallTime2 = stallTime1.add(const Duration(milliseconds: 200));
      await watchdog.checkHealthTick(now: stallTime2);
      expect(attempts, equals(2));

      // Tick 3: attempts exhausted (attempts == 2) -> failed
      final stallTime3 = stallTime2.add(const Duration(milliseconds: 200));
      await watchdog.checkHealthTick(now: stallTime3);
      expect(watchdog.currentHealth, equals(MonitoringHealth.failed));
      expect(watchdog.currentIssue, equals(MonitoringIssue.cameraStalled));
    });

    test('Inference stall triggers inference recovery callback and restores healthy on success', () async {
      int inferenceAttemptCalled = 0;

      watchdog.start(
        onInferenceRecoveryRequested: ({required int attempt}) async {
          inferenceAttemptCalled = attempt;
          return true;
        },
      );

      final now = DateTime.now();
      watchdog.recordInferenceHeartbeat(now);

      // Camera frames keep arriving, but inference does not run
      final stallTime = now.add(const Duration(milliseconds: 1700));
      watchdog.recordCameraFrameHeartbeat(stallTime);

      await watchdog.checkHealthTick(now: stallTime);

      expect(inferenceAttemptCalled, equals(1));
      // Inference auto-recovery succeeded seamlessly -> restored to healthy!
      expect(watchdog.currentHealth, equals(MonitoringHealth.healthy));
      expect(watchdog.currentIssue, equals(MonitoringIssue.none));
    });

    test('Transition grace period extends timeouts during lifecycle shifts', () {
      watchdog.start();
      final now = DateTime.now();

      watchdog.recordCameraFrameHeartbeat(now);
      watchdog.recordInferenceHeartbeat(now);

      // Mark transition to background at 900ms
      final transitionTime = now.add(const Duration(milliseconds: 900));
      watchdog.recordLifecycleTransition(transitionTime);

      // At 1200ms (1200ms from last frame):
      // Normal camera timeout is 1000ms, but within grace it is 1000 + 800 = 1800ms
      final checkTime = now.add(const Duration(milliseconds: 1200));
      final eval = watchdog.evaluateHealth(checkTime);

      expect(eval.health, equals(MonitoringHealth.healthy));
      expect(eval.issue, equals(MonitoringIssue.none));
    });
  });
}
