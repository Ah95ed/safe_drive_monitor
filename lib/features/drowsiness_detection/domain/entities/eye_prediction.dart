enum EyeState {
  open,
  closed,
  unknown,
}

class EyePrediction {
  final EyeState state;
  final double openScore;
  final double closedScore;
  final double confidence;
  final Duration inferenceTime;
  final DateTime timestamp;

  const EyePrediction({
    required this.state,
    required this.openScore,
    required this.closedScore,
    required this.confidence,
    required this.inferenceTime,
    required this.timestamp,
  });

  /// Factory for creating a closed eye prediction
  factory EyePrediction.closed({
    required double confidence,
    DateTime? timestamp,
    Duration inferenceTime = Duration.zero,
  }) {
    return EyePrediction(
      state: EyeState.closed,
      openScore: 1.0 - confidence,
      closedScore: confidence,
      confidence: confidence,
      inferenceTime: inferenceTime,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Factory for creating an open eye prediction
  factory EyePrediction.open({
    required double confidence,
    DateTime? timestamp,
    Duration inferenceTime = Duration.zero,
  }) {
    return EyePrediction(
      state: EyeState.open,
      openScore: confidence,
      closedScore: 1.0 - confidence,
      confidence: confidence,
      inferenceTime: inferenceTime,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Factory for creating an unknown eye prediction when face or eyes are unreadable
  factory EyePrediction.unknown({DateTime? timestamp}) {
    return EyePrediction(
      state: EyeState.unknown,
      openScore: 0.0,
      closedScore: 0.0,
      confidence: 0.0,
      inferenceTime: Duration.zero,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  bool get isClosed => state == EyeState.closed;
  bool get isOpen => state == EyeState.open;
  bool get isUnknown => state == EyeState.unknown;

  @override
  String toString() =>
      'EyePrediction(state: $state, open: ${openScore.toStringAsFixed(3)}, '
      'closed: ${closedScore.toStringAsFixed(3)}, conf: ${(confidence * 100).toStringAsFixed(1)}%, '
      'inference: ${inferenceTime.inMilliseconds}ms)';
}
