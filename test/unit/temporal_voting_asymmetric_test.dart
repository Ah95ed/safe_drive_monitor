import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart';

void main() {
  group('Temporal Voting Buffer & Asymmetric Confidence Unit Tests', () {
    late DrowsinessAnalyzer analyzer;
    final DateTime baseTime = DateTime(2026, 11, 4, 12, 0, 0);

    setUp(() {
      analyzer = DrowsinessAnalyzer(
        config: const DrowsinessConfig(
          watchingThreshold: Duration(milliseconds: 350),
          drowsyThreshold: Duration(milliseconds: 800),
          alarmThreshold: Duration(milliseconds: 1200),
          recoveryThreshold: Duration(milliseconds: 800),
          minimumClosedConfidence: 0.50,
          minimumOpenConfidence: 0.55,
        ),
      );
    });

    test('Asymmetric confidence thresholds: 0.50 for closed, 0.55 for open', () {
      final now = DateTime.now();

      // Closed with 0.51 confidence >= 0.50 -> accepted as closed
      final closedPred = EyePredictionModel.fromRawOutput(
        rawOutput: [0.49, 0.51],
        inferenceTime: Duration.zero,
        timestamp: now,
        minClosedConfidence: 0.50,
        minOpenConfidence: 0.55,
      );
      expect(closedPred.state, equals(EyeState.closed));

      // Open with 0.52 confidence < 0.55 -> rejected as unknown (requires 0.55)
      final openPredLow = EyePredictionModel.fromRawOutput(
        rawOutput: [0.52, 0.48],
        inferenceTime: Duration.zero,
        timestamp: now,
        minClosedConfidence: 0.50,
        minOpenConfidence: 0.55,
      );
      expect(openPredLow.state, equals(EyeState.unknown));

      // Open with 0.56 confidence >= 0.55 -> accepted as open
      final openPredHigh = EyePredictionModel.fromRawOutput(
        rawOutput: [0.56, 0.44],
        inferenceTime: Duration.zero,
        timestamp: now,
        minClosedConfidence: 0.50,
        minOpenConfidence: 0.55,
      );
      expect(openPredHigh.state, equals(EyeState.open));
    });

    test('Isolated single-frame closed noise does not escalate state when surrounded by open frames', () {
      // Frame 1: OPEN
      final r1 = analyzer.processPrediction(
        EyePrediction(
          state: EyeState.open,
          openScore: 0.90,
          closedScore: 0.10,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime,
        ),
      );
      expect(r1.alertState, equals(DriverAlertState.normal));

      // Frame 2: Single CLOSED glitch at +400ms (> 350ms watching threshold if not gated)
      final r2 = analyzer.processPrediction(
        EyePrediction(
          state: EyeState.closed,
          openScore: 0.10,
          closedScore: 0.90,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime.add(const Duration(milliseconds: 400)),
        ),
      );
      // Voting buffer has [OPEN, CLOSED]. Closed is not majority (1 of 2). Must NOT escalate to watching!
      expect(r2.alertState, equals(DriverAlertState.normal));

      // Frame 3: OPEN
      final r3 = analyzer.processPrediction(
        EyePrediction(
          state: EyeState.open,
          openScore: 0.90,
          closedScore: 0.10,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime.add(const Duration(milliseconds: 500)),
        ),
      );
      expect(r3.alertState, equals(DriverAlertState.normal));
    });

    test('Sustained closed frames achieve majority in voting buffer and escalate correctly', () {
      // Frame 1: CLOSED at 0ms
      analyzer.processPrediction(
        EyePrediction(
          state: EyeState.closed,
          openScore: 0.10,
          closedScore: 0.90,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime,
        ),
      );

      // Frame 2: CLOSED at 200ms
      analyzer.processPrediction(
        EyePrediction(
          state: EyeState.closed,
          openScore: 0.10,
          closedScore: 0.90,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime.add(const Duration(milliseconds: 200)),
        ),
      );

      // Frame 3: CLOSED at 400ms (>= 350ms watching threshold + 3 of 3 closed)
      final rWatch = analyzer.processPrediction(
        EyePrediction(
          state: EyeState.closed,
          openScore: 0.10,
          closedScore: 0.90,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime.add(const Duration(milliseconds: 400)),
        ),
      );
      expect(rWatch.alertState, equals(DriverAlertState.watching));

      // Frame 4: CLOSED at 1300ms (>= 1200ms alarm threshold)
      final rAlarm = analyzer.processPrediction(
        EyePrediction(
          state: EyeState.closed,
          openScore: 0.10,
          closedScore: 0.90,
          confidence: 0.90,
          inferenceTime: Duration.zero,
          timestamp: baseTime.add(const Duration(milliseconds: 1300)),
        ),
      );
      expect(rAlarm.alertState, equals(DriverAlertState.alarm));
      expect(rAlarm.shouldTriggerAlarm, isTrue);
    });
  });
}
