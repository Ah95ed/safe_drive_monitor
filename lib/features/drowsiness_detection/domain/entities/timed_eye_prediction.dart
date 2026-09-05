import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

/// Lightweight timestamped prediction structure stored in the rolling recovery window.
class TimedEyePrediction {
  final EyeState state;
  final double confidence;
  final double openScore;
  final double closedScore;
  final DateTime timestamp;

  const TimedEyePrediction({
    required this.state,
    required this.confidence,
    this.openScore = 0.0,
    this.closedScore = 0.0,
    required this.timestamp,
  });

  factory TimedEyePrediction.fromPrediction(EyePrediction prediction) {
    return TimedEyePrediction(
      state: prediction.state,
      confidence: prediction.confidence,
      openScore: prediction.openScore,
      closedScore: prediction.closedScore,
      timestamp: prediction.timestamp,
    );
  }

  bool get isOpen => state == EyeState.open;
  bool get isClosed => state == EyeState.closed;
  bool get isUnknown => state == EyeState.unknown;

  @override
  String toString() =>
      'TimedEyePrediction(state: ${state.name}, conf: ${(confidence * 100).toStringAsFixed(1)}%, at: ${timestamp.toIso8601String()})';
}
