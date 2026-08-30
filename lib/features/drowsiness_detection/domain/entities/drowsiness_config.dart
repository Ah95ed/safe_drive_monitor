/// Configurable thresholds for the time-based drowsiness state machine.
class DrowsinessConfig {
  /// Eyes closed duration threshold to enter watching state (e.g. 400ms).
  final Duration watchingThreshold;

  /// Eyes closed duration threshold to enter drowsy state (e.g. 1000ms).
  final Duration drowsyThreshold;

  /// Eyes closed duration threshold to trigger loud alarm (e.g. 1500ms).
  final Duration alarmThreshold;

  /// Continuous open eyes duration required to recover from alarm to normal (e.g. 1000ms).
  final Duration recoveryThreshold;

  /// Minimum confidence required to accept a closed prediction.
  final double minimumClosedConfidence;

  /// Minimum confidence required to accept an open prediction.
  final double minimumOpenConfidence;

  const DrowsinessConfig({
    this.watchingThreshold = const Duration(milliseconds: 400),
    this.drowsyThreshold = const Duration(milliseconds: 1000),
    this.alarmThreshold = const Duration(milliseconds: 1500),
    this.recoveryThreshold = const Duration(milliseconds: 1000),
    this.minimumClosedConfidence = 0.55,
    this.minimumOpenConfidence = 0.55,
  });

  DrowsinessConfig copyWith({
    Duration? watchingThreshold,
    Duration? drowsyThreshold,
    Duration? alarmThreshold,
    Duration? recoveryThreshold,
    double? minimumClosedConfidence,
    double? minimumOpenConfidence,
  }) {
    return DrowsinessConfig(
      watchingThreshold: watchingThreshold ?? this.watchingThreshold,
      drowsyThreshold: drowsyThreshold ?? this.drowsyThreshold,
      alarmThreshold: alarmThreshold ?? this.alarmThreshold,
      recoveryThreshold: recoveryThreshold ?? this.recoveryThreshold,
      minimumClosedConfidence:
          minimumClosedConfidence ?? this.minimumClosedConfidence,
      minimumOpenConfidence:
          minimumOpenConfidence ?? this.minimumOpenConfidence,
    );
  }
}
