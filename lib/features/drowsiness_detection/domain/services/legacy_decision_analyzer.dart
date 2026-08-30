import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

/// Legacy Java decision algorithm reproducing MainActivity.java:
/// - if closed > open: isclosed++
/// - if open > closed: isclosed = 0
/// - if isclosed > 1: trigger alarm
class LegacyDecisionAnalyzer {
  int _isClosedCount = 0;

  int get isClosedCount => _isClosedCount;
  bool get isAlarmTriggered => _isClosedCount > 1;

  void reset() {
    _isClosedCount = 0;
  }

  bool processPrediction(EyePrediction prediction) {
    if (prediction.closedScore > prediction.openScore) {
      _isClosedCount++;
    } else if (prediction.openScore > prediction.closedScore) {
      _isClosedCount = 0;
    }
    return isAlarmTriggered;
  }
}
