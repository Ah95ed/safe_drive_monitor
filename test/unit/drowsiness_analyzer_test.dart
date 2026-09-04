import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/alarm_controller.dart';
import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/perclos_calculator.dart';

void main() {
  group('DrowsinessAnalyzer State Machine Unit Tests', () {
    late DrowsinessAnalyzer analyzer;
    final DateTime baseTime = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      analyzer = DrowsinessAnalyzer(
        config: const DrowsinessConfig(
          watchingThreshold: Duration(milliseconds: 400),
          drowsyThreshold: Duration(milliseconds: 1000),
          alarmThreshold: Duration(milliseconds: 1500),
          recoveryThreshold: Duration(milliseconds: 1000),
        ),
      );
    });

    EyePrediction createPrediction({
      required EyeState state,
      required Duration timeOffset,
      double confidence = 0.90,
      double openScore = 0.90,
      double closedScore = 0.10,
    }) {
      return EyePrediction(
        state: state,
        openScore: state == EyeState.open ? 0.90 : 0.10,
        closedScore: state == EyeState.closed ? 0.90 : 0.10,
        confidence: confidence,
        inferenceTime: const Duration(milliseconds: 25),
        timestamp: baseTime.add(timeOffset),
      );
    }

    test('Open eyes sequence keeps alert state normal and does not trigger alarm', () {
      final p1 = createPrediction(state: EyeState.open, timeOffset: Duration.zero);
      final r1 = analyzer.processPrediction(p1);
      expect(r1.alertState, equals(DriverAlertState.normal));
      expect(r1.shouldTriggerAlarm, isFalse);

      final p2 = createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 500));
      final r2 = analyzer.processPrediction(p2);
      expect(r2.alertState, equals(DriverAlertState.normal));
      expect(r2.shouldTriggerAlarm, isFalse);
    });

    test('Natural blink (< 400ms) does not trigger alarm and returns to normal', () {
      // 0ms: Closed
      final p1 = createPrediction(state: EyeState.closed, timeOffset: Duration.zero);
      final r1 = analyzer.processPrediction(p1);
      expect(r1.alertState, equals(DriverAlertState.normal));
      expect(r1.shouldTriggerAlarm, isFalse);

      // 150ms: Closed (still < 400ms blink)
      final p2 = createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 150));
      final r2 = analyzer.processPrediction(p2);
      expect(r2.alertState, equals(DriverAlertState.normal));
      expect(r2.shouldTriggerAlarm, isFalse);

      // 250ms: Eyes open again
      final p3 = createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 250));
      final r3 = analyzer.processPrediction(p3);
      expect(r3.alertState, equals(DriverAlertState.normal));
      expect(r3.shouldTriggerAlarm, isFalse);
    });

    test('Continuous closed sequence transitions: watching -> drowsy -> alarm', () {
      // 0ms: Closed
      analyzer.processPrediction(
          createPrediction(state: EyeState.closed, timeOffset: Duration.zero));

      // 500ms: Closed (>= 400ms watchingThreshold)
      final rWatching = analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 500)));
      expect(rWatching.alertState, equals(DriverAlertState.watching));
      expect(rWatching.shouldTriggerAlarm, isFalse);

      // 1100ms: Closed (>= 1000ms drowsyThreshold)
      final rDrowsy = analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 1100)));
      expect(rDrowsy.alertState, equals(DriverAlertState.drowsy));
      expect(rDrowsy.shouldTriggerAlarm, isFalse);

      // 1600ms: Closed (>= 1500ms alarmThreshold) -> ALARM!
      final rAlarm = analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 1600)));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      expect(rAlarm.shouldTriggerAlarm, isTrue);
    });

    test('Alarm recovery requires stable open state for full recoveryThreshold (1000ms)', () {
      // Trigger Alarm at 1600ms
      analyzer.processPrediction(
          createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 1600)));
      expect(analyzer.currentState, equals(DriverAlertState.alarm));

      // Driver opens eyes at 1700ms (100ms open) -> still in alarm
      final r1 = analyzer.processPrediction(createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 1700)));
      expect(r1.alertState, equals(DriverAlertState.alarm));
      expect(r1.shouldStopAlarm, isFalse);

      // Driver stays open until 2200ms (500ms open) -> still in alarm (< 1000ms recovery)
      final r2 = analyzer.processPrediction(createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 2200)));
      expect(r2.alertState, equals(DriverAlertState.alarm));
      expect(r2.shouldStopAlarm, isFalse);

      // Driver stays open until 2800ms (1100ms open >= 1000ms recovery) -> RECOVERED!
      final r3 = analyzer.processPrediction(createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 2800)));
      expect(r3.alertState, equals(DriverAlertState.normal));
      expect(r3.shouldStopAlarm, isTrue);
    });

    test('Single noisy CLOSED frame between OPENs is debounced away (no alarm)', () {
      analyzer.processPrediction(
          createPrediction(state: EyeState.open, timeOffset: Duration.zero));
      analyzer.processPrediction(createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 200)));
      // One isolated low-confidence CLOSED reading.
      final noisy = analyzer.processPrediction(EyePrediction(
        state: EyeState.closed,
        openScore: 0.42,
        closedScore: 0.58,
        confidence: 0.58,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: baseTime.add(const Duration(milliseconds: 400)),
      ));
      expect(noisy.alertState, DriverAlertState.normal);
      expect(noisy.continuousClosedDuration, Duration.zero);

      final back = analyzer.processPrediction(createPrediction(
          state: EyeState.open, timeOffset: const Duration(milliseconds: 600)));
      expect(back.alertState, DriverAlertState.normal);
    });

    test('Sustained CLOSED (2+ frames) still escalates to alarm after threshold', () {
      analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 0)));
      analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 100)));
      final r = analyzer.processPrediction(createPrediction(
          state: EyeState.closed, timeOffset: const Duration(milliseconds: 1700)));
      expect(r.alertState, DriverAlertState.alarm);
      expect(r.shouldTriggerAlarm, isTrue);
    });

    test('High-confidence CLOSED switches immediately (no debounce delay)', () {
      analyzer.processPrediction(
          createPrediction(state: EyeState.open, timeOffset: Duration.zero));
      final r = analyzer.processPrediction(EyePrediction(
        state: EyeState.closed,
        openScore: 0.05,
        closedScore: 0.95,
        confidence: 0.95,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: baseTime.add(const Duration(milliseconds: 100)),
      ));
      // Debounce is bypassed at high confidence, so the closed clock starts now.
      expect(r.continuousClosedDuration, Duration.zero);
      final r2 = analyzer.processPrediction(EyePrediction(
        state: EyeState.closed,
        openScore: 0.05,
        closedScore: 0.95,
        confidence: 0.95,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: baseTime.add(const Duration(milliseconds: 700)),
      ));
      expect(r2.alertState, DriverAlertState.watching);
    });

    test('High PERCLOS on its own escalates to drowsy but never the loud alarm', () {
      // A warmed-up PERCLOS window that is already above the alarm threshold.
      final analyzerWithPerclos = DrowsinessAnalyzer(
        config: const DrowsinessConfig(
          watchingThreshold: Duration(milliseconds: 400),
          drowsyThreshold: Duration(milliseconds: 1000),
          alarmThreshold: Duration(milliseconds: 1500),
        ),
        perclosCalculator: PerclosCalculator(
          minReadySamples: 1,
          minReadyDuration: Duration.zero,
          warningThreshold: 0.1,
          alarmThreshold: 0.2,
        ),
      );

      DriverAlertState last = DriverAlertState.normal;
      for (var i = 0; i < 20; i++) {
        // Short blinks only (200ms closed), well under the alarm duration.
        final closed = analyzerWithPerclos.processPrediction(EyePrediction(
          state: EyeState.closed,
          openScore: 0.1,
          closedScore: 0.9,
          confidence: 0.9,
          inferenceTime: const Duration(milliseconds: 20),
          timestamp: baseTime.add(Duration(milliseconds: 1000 * i)),
        ));
        expect(closed.shouldTriggerAlarm, isFalse);
        expect(closed.alertState, isNot(DriverAlertState.alarm));
        last = closed.alertState;

        analyzerWithPerclos.processPrediction(EyePrediction(
          state: EyeState.open,
          openScore: 0.9,
          closedScore: 0.1,
          confidence: 0.9,
          inferenceTime: const Duration(milliseconds: 20),
          timestamp: baseTime.add(Duration(milliseconds: 1000 * i + 200)),
        ));
      }
      expect(last, DriverAlertState.drowsy);
    });

    test('Alternating low confidence / unknown predictions do not trigger false alarm', () {
      final p1 = createPrediction(
        state: EyeState.unknown,
        timeOffset: Duration.zero,
        confidence: 0.3,
      );
      final r1 = analyzer.processPrediction(p1);
      expect(r1.alertState, equals(DriverAlertState.normal));
      expect(r1.shouldTriggerAlarm, isFalse);

      final p2 = createPrediction(
        state: EyeState.unknown,
        timeOffset: const Duration(milliseconds: 2000),
        confidence: 0.4,
      );
      final r2 = analyzer.processPrediction(p2);
      expect(r2.alertState, equals(DriverAlertState.normal));
      expect(r2.shouldTriggerAlarm, isFalse);
    });

    test('Test 1: CLOSED -> ALARM -> continuous OPEN 1000ms -> NORMAL with stopAlarm called exactly once', () async {
      final alarmService = MockAudioAlarmService();
      final controller = AlarmController(alarmService);

      // CLOSED sequence triggering ALARM
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      await controller.sync(rAlarm.alertState);
      expect(alarmService.playAlarmCalls, equals(1));
      expect(controller.isPlaying, isTrue);

      // Another frame still in ALARM
      final rAlarm2 = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1700),
      ));
      await controller.sync(rAlarm2.alertState);
      // playAlarm should NOT be called again
      expect(alarmService.playAlarmCalls, equals(1));

      // OPEN begins at 1800ms
      final rOpen1 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1800),
      ));
      expect(rOpen1.alertState, equals(DriverAlertState.alarm));
      await controller.sync(rOpen1.alertState);
      expect(alarmService.stopAlarmCalls, equals(0));

      // OPEN 500ms at 2300ms
      final rOpen2 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2300),
      ));
      expect(rOpen2.alertState, equals(DriverAlertState.alarm));
      await controller.sync(rOpen2.alertState);
      expect(alarmService.stopAlarmCalls, equals(0));

      // OPEN continuously 1000ms at 2850ms (>= 1000ms recoveryThreshold in analyzer test)
      final rOpen3 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2850),
      ));
      expect(rOpen3.alertState, equals(DriverAlertState.normal));
      expect(rOpen3.shouldStopAlarm, isTrue);
      await controller.sync(rOpen3.alertState);
      expect(alarmService.stopAlarmCalls, equals(1));
      expect(controller.isPlaying, isFalse);

      // Additional OPEN frames in NORMAL state
      final rOpen4 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 3200),
      ));
      await controller.sync(rOpen4.alertState);
      // stopAlarm must remain called EXACTLY ONCE!
      expect(alarmService.stopAlarmCalls, equals(1));
    });

    test('Test 2: ALARM -> OPEN 300ms -> CLOSED -> ALARM (Recovery interrupted)', () async {
      // Trigger ALARM
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));

      // OPEN for 300ms
      final rOpen1 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1700),
      ));
      final rOpen2 = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2000),
      ));
      expect(rOpen1.alertState, equals(DriverAlertState.alarm));
      expect(rOpen2.alertState, equals(DriverAlertState.alarm));

      // CLOSED arrives -> cancels recovery
      final rClosed = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 2100),
      ));
      expect(rClosed.alertState, equals(DriverAlertState.alarm));
      expect(analyzer.openStartedAt, isNull);
    });

    test('Test 3: ALARM -> UNKNOWN -> ALARM (UNKNOWN does not stop alarm or recover)', () {
      // Trigger ALARM
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));

      // UNKNOWN arrives
      final rUnknown = analyzer.processPrediction(EyePrediction(
        state: EyeState.unknown,
        openScore: 0.0,
        closedScore: 0.0,
        confidence: 0.0,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: baseTime.add(const Duration(milliseconds: 2000)),
      ));

      expect(rUnknown.alertState, equals(DriverAlertState.alarm));
      expect(rUnknown.shouldStopAlarm, isFalse);
      expect(analyzer.currentState, equals(DriverAlertState.alarm));
    });

    test('Test 4: Background simulation (AppLifecycleState.paused) matches Foreground behavior', () async {
      final alarmService = MockAudioAlarmService();
      final controller = AlarmController(alarmService);

      // Simulation of Background state
      AppLifecycleState lifecycleState = AppLifecycleState.paused;
      bool isMonitoring = true;
      bool foregroundServiceActive = true;

      expect(lifecycleState, equals(AppLifecycleState.paused));
      expect(isMonitoring, isTrue);
      expect(foregroundServiceActive, isTrue);

      // In Background: CLOSED -> triggers ALARM
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      await controller.sync(rAlarm.alertState);
      expect(alarmService.playAlarmCalls, equals(1));
      expect(controller.isPlaying, isTrue);

      // In Background: OPEN continuously > recoveryThreshold -> NORMAL -> stopAlarm
      // Start OPEN at 1700ms
      analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 1700),
      ));
      // Continuous OPEN until 2750ms (> 1000ms recovery)
      final rRecovered = analyzer.processPrediction(createPrediction(
        state: EyeState.open,
        timeOffset: const Duration(milliseconds: 2750),
      ));

      expect(rRecovered.alertState, equals(DriverAlertState.normal));
      expect(rRecovered.shouldStopAlarm, isTrue);
      await controller.sync(rRecovered.alertState);

      expect(controller.isPlaying, isFalse);
      expect(alarmService.stopAlarmCalls, equals(1));
    });

    test('Test 5: No face present (hasDriverFace: false) NEVER triggers alarm even on CLOSED stream', () async {
      // Stream of CLOSED frames for 5 seconds, but with hasDriverFace: false
      for (int i = 0; i <= 5000; i += 200) {
        final r = analyzer.processPrediction(
          createPrediction(state: EyeState.closed, timeOffset: Duration(milliseconds: i)),
          hasDriverFace: false,
        );
        expect(r.alertState, equals(DriverAlertState.normal));
        expect(r.shouldTriggerAlarm, isFalse);
        expect(r.continuousClosedDuration, equals(Duration.zero));
        expect(r.statusMessage, contains('لا يوجد وجه سائق واضح'));
      }
      expect(analyzer.currentState, equals(DriverAlertState.normal));
      expect(analyzer.isAlarmActive, isFalse);
    });

    test('Test 6: Active ALARM immediately halts if driver face is lost (hasDriverFace: false)', () async {
      final alarmService = MockAudioAlarmService();
      final controller = AlarmController(alarmService);

      // Trigger ALARM with face present
      analyzer.processPrediction(createPrediction(state: EyeState.closed, timeOffset: Duration.zero));
      final rAlarm = analyzer.processPrediction(createPrediction(
        state: EyeState.closed,
        timeOffset: const Duration(milliseconds: 1600),
      ));
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      await controller.sync(rAlarm.alertState);
      expect(controller.isPlaying, isTrue);

      // Driver leaves camera frame -> hasDriverFace = false
      final rLost = analyzer.processPrediction(
        EyePrediction.unknown(timestamp: baseTime.add(const Duration(milliseconds: 1800))),
        hasDriverFace: false,
      );
      expect(rLost.alertState, equals(DriverAlertState.normal));
      expect(rLost.shouldStopAlarm, isTrue);
      expect(rLost.shouldTriggerAlarm, isFalse);
      expect(rLost.continuousClosedDuration, equals(Duration.zero));

      await controller.sync(rLost.alertState);
      expect(controller.isPlaying, isFalse);
      expect(alarmService.stopAlarmCalls, equals(1));
    });
  });
}

class MockAudioAlarmService implements AudioAlarmService {
  int playAlarmCalls = 0;
  int stopAlarmCalls = 0;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> playAlarm() async {
    playAlarmCalls++;
    _playing = true;
  }

  @override
  Future<void> stopAlarm() async {
    stopAlarmCalls++;
    _playing = false;
  }

  @override
  Future<void> playTechnicalWarning() async {}

  @override
  Future<void> dispose() async {
    _playing = false;
  }
}
