import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/perclos_calculator.dart';

void main() {
  EyePrediction pred(EyeState state, DateTime ts) => EyePrediction(
        state: state,
        openScore: state == EyeState.open ? 0.9 : 0.1,
        closedScore: state == EyeState.closed ? 0.9 : 0.1,
        confidence: 0.9,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: ts,
      );

  group('PerclosCalculator readiness gate', () {
    final base = DateTime(2026, 1, 1, 12);

    test('is not ready with only a couple of samples (first blink)', () {
      final calc = PerclosCalculator();
      calc.addPrediction(pred(EyeState.closed, base));
      calc.addPrediction(
          pred(EyeState.closed, base.add(const Duration(milliseconds: 100))));

      expect(calc.currentPerclos, 1.0);
      expect(calc.isReady, isFalse);
      expect(calc.isWarningLevel, isFalse);
      expect(calc.isAlarmLevel, isFalse);
    });

    test('needs both minimum samples AND minimum span before levels fire', () {
      final calc = PerclosCalculator(
        minReadyDuration: const Duration(seconds: 20),
        minReadySamples: 30,
      );

      // 40 samples but only spanning 4 seconds -> still not ready.
      for (var i = 0; i < 40; i++) {
        calc.addPrediction(
            pred(EyeState.closed, base.add(Duration(milliseconds: 100 * i))));
      }
      expect(calc.isReady, isFalse);
      expect(calc.isAlarmLevel, isFalse);
    });

    test('fires warning/alarm once warmed up and closure ratio is high', () {
      final calc = PerclosCalculator(
        minReadyDuration: const Duration(seconds: 20),
        minReadySamples: 30,
        warningThreshold: 0.15,
        alarmThreshold: 0.25,
      );

      // 60 samples across 30 seconds, half closed -> ratio 0.5.
      for (var i = 0; i < 60; i++) {
        final state = i.isEven ? EyeState.closed : EyeState.open;
        calc.addPrediction(
            pred(state, base.add(Duration(milliseconds: 500 * i))));
      }

      expect(calc.isReady, isTrue);
      expect(calc.currentPerclos, closeTo(0.5, 1e-9));
      expect(calc.isWarningLevel, isTrue);
      expect(calc.isAlarmLevel, isTrue);
    });

    test('reset clears readiness', () {
      final calc = PerclosCalculator(minReadySamples: 2, minReadyDuration: Duration.zero);
      calc.addPrediction(pred(EyeState.closed, base));
      calc.addPrediction(pred(EyeState.closed, base.add(const Duration(seconds: 1))));
      expect(calc.isReady, isTrue);
      calc.reset();
      expect(calc.isReady, isFalse);
      expect(calc.currentPerclos, 0.0);
    });
  });
}
