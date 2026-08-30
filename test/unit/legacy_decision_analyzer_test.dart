import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/legacy_decision_analyzer.dart';

void main() {
  group('LegacyDecisionAnalyzer Unit Tests', () {
    late LegacyDecisionAnalyzer analyzer;

    setUp(() {
      analyzer = LegacyDecisionAnalyzer();
    });

    EyePrediction createPrediction(double open, double closed) {
      return EyePrediction(
        state: closed > open ? EyeState.closed : EyeState.open,
        openScore: open,
        closedScore: closed,
        confidence: 0.9,
        inferenceTime: const Duration(milliseconds: 20),
        timestamp: DateTime.now(),
      );
    }

    test('1 closed frame increments isclosed to 1 but does not trigger alarm', () {
      final isAlarm = analyzer.processPrediction(createPrediction(0.2, 0.8));
      expect(analyzer.isClosedCount, equals(1));
      expect(isAlarm, isFalse);
    });

    test('2 consecutive closed frames trigger alarm (isclosed > 1)', () {
      analyzer.processPrediction(createPrediction(0.2, 0.8));
      final isAlarm = analyzer.processPrediction(createPrediction(0.1, 0.9));
      expect(analyzer.isClosedCount, equals(2));
      expect(isAlarm, isTrue);
    });

    test('Open frame resets count to 0 and stops alarm', () {
      analyzer.processPrediction(createPrediction(0.2, 0.8));
      analyzer.processPrediction(createPrediction(0.1, 0.9));
      expect(analyzer.isAlarmTriggered, isTrue);

      final isAlarm = analyzer.processPrediction(createPrediction(0.9, 0.1));
      expect(analyzer.isClosedCount, equals(0));
      expect(isAlarm, isFalse);
    });
  });
}
