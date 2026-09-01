import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';

void main() {
  EyePredictionModel build(
    List<double> raw, {
    ModelOutputMode mode = ModelOutputMode.auto,
  }) {
    return EyePredictionModel.fromRawOutput(
      rawOutput: raw,
      inferenceTime: const Duration(milliseconds: 20),
      timestamp: DateTime.now(),
      outputMode: mode,
    );
  }

  group('ModelOutputMode handling', () {
    test('auto: passes through values that already look like probabilities', () {
      final m = build([0.8, 0.2]);
      expect(m.openScore, closeTo(0.8, 1e-9));
      expect(m.closedScore, closeTo(0.2, 1e-9));
      expect(m.state, EyeState.open);
    });

    test('auto: applies softmax to positive logits', () {
      final m = build([2.0, 0.5]);
      expect(m.openScore + m.closedScore, closeTo(1.0, 1e-6));
      expect(m.openScore, greaterThan(0.5));
      expect(m.state, EyeState.open);
    });

    test('auto: applies softmax to ALL-NEGATIVE logits (old code inverted this)', () {
      // open logit (-2.1) > closed logit (-3.4) => must resolve to OPEN.
      final m = build([-2.1, -3.4]);
      expect(m.openScore + m.closedScore, closeTo(1.0, 1e-6));
      expect(m.openScore, greaterThan(m.closedScore));
      expect(m.state, EyeState.open);
    });

    test('auto: closed wins for closed-dominant logits', () {
      final m = build([-1.0, 3.0]);
      expect(m.closedScore, greaterThan(0.9));
      expect(m.state, EyeState.closed);
    });

    test('logits mode always softmaxes even for in-range values', () {
      final m = build([0.9, 0.1], mode: ModelOutputMode.logits);
      expect(m.openScore + m.closedScore, closeTo(1.0, 1e-6));
      expect(m.openScore, closeTo(0.69, 0.02));
    });

    test('probabilities mode passes values through untouched', () {
      final m = build([0.42, 0.58], mode: ModelOutputMode.probabilities);
      expect(m.openScore, 0.42);
      expect(m.closedScore, 0.58);
    });

    test('stable softmax handles large logits without overflow', () {
      final s = EyePredictionModel.computeStableSoftmax(1000.0, 999.0);
      expect(s[0] + s[1], closeTo(1.0, 1e-9));
      expect(s[0], greaterThan(s[1]));
    });
  });

  group('EyePredictionModel Unit Tests', () {
    test('Correctly maps raw output [0.85, 0.15] to EyeState.open', () {
      final model = EyePredictionModel.fromRawOutput(
        rawOutput: [0.85, 0.15],
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: DateTime.now(),
      );

      expect(model.state, equals(EyeState.open));
      expect(model.openScore, equals(0.85));
      expect(model.closedScore, equals(0.15));
      expect(model.confidence, closeTo(0.85, 0.01));
    });

    test('Correctly maps raw output [0.10, 0.90] to EyeState.closed', () {
      final model = EyePredictionModel.fromRawOutput(
        rawOutput: [0.10, 0.90],
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: DateTime.now(),
      );

      expect(model.state, equals(EyeState.closed));
      expect(model.openScore, equals(0.10));
      expect(model.closedScore, equals(0.90));
      expect(model.confidence, closeTo(0.90, 0.01));
    });

    test('Maps ambiguous output with low confidence to EyeState.unknown', () {
      final model = EyePredictionModel.fromRawOutput(
        rawOutput: [0.51, 0.49],
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: DateTime.now(),
        minConfidenceThreshold: 0.60,
      );

      expect(model.state, equals(EyeState.unknown));
    });
  });
}
