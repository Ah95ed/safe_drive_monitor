import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

void main() {
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
