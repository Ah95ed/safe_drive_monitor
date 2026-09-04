/// Configurable thresholds for the time-based drowsiness state machine, PERCLOS, and adaptive inference.
class DrowsinessConfig {
  /// Eyes closed duration threshold to enter watching state (e.g. 350ms).
  final Duration watchingThreshold;

  /// Eyes closed duration threshold to enter drowsy state (e.g. 800ms).
  final Duration drowsyThreshold;

  /// Eyes closed duration threshold to trigger loud alarm (e.g. 1200ms).
  final Duration alarmThreshold;

  /// Continuous open eyes duration required to recover from alarm to normal (e.g. 1000ms).
  final Duration recoveryThreshold;

  /// Minimum confidence required to accept a closed prediction.
  final double minimumClosedConfidence;

  /// Minimum confidence required to accept an open prediction.
  final double minimumOpenConfidence;

  /// PERCLOS rolling time window duration (default 60 seconds).
  final Duration perclosWindowDuration;

  /// PERCLOS ratio threshold to enter warning state (default 0.15 = 15%).
  final double perclosWarningThreshold;

  /// PERCLOS ratio threshold to enter alarm state (default 0.25 = 25%).
  final double perclosAlarmThreshold;

  /// Head pitch nod angle threshold (nodding forward/down) to accelerate alert (in degrees, default -20.0).
  final double headNodPitchThreshold;

  /// Whether adaptive inference rate is enabled based on driver risk level.
  final bool enableAdaptiveInference;

  /// Default inference interval in normal / safe state (e.g. 160ms ~ 6 FPS).
  final Duration normalInferenceInterval;

  /// Accelerated inference interval in alert / watching state (e.g. 60ms ~ 16 FPS).
  final Duration alertInferenceInterval;

  const DrowsinessConfig({
    this.watchingThreshold = const Duration(milliseconds: 350),
    this.drowsyThreshold = const Duration(milliseconds: 800),
    this.alarmThreshold = const Duration(milliseconds: 1200),
    this.recoveryThreshold = const Duration(milliseconds: 900),
    this.minimumClosedConfidence = 0.55,
    this.minimumOpenConfidence = 0.55,
    this.perclosWindowDuration = const Duration(seconds: 60),
    this.perclosWarningThreshold = 0.15,
    this.perclosAlarmThreshold = 0.25,
    this.headNodPitchThreshold = -20.0,
    this.enableAdaptiveInference = true,
    this.normalInferenceInterval = const Duration(milliseconds: 220),
    this.alertInferenceInterval = const Duration(milliseconds: 90),
  });

  DrowsinessConfig copyWith({
    Duration? watchingThreshold,
    Duration? drowsyThreshold,
    Duration? alarmThreshold,
    Duration? recoveryThreshold,
    double? minimumClosedConfidence,
    double? minimumOpenConfidence,
    Duration? perclosWindowDuration,
    double? perclosWarningThreshold,
    double? perclosAlarmThreshold,
    double? headNodPitchThreshold,
    bool? enableAdaptiveInference,
    Duration? normalInferenceInterval,
    Duration? alertInferenceInterval,
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
      perclosWindowDuration:
          perclosWindowDuration ?? this.perclosWindowDuration,
      perclosWarningThreshold:
          perclosWarningThreshold ?? this.perclosWarningThreshold,
      perclosAlarmThreshold:
          perclosAlarmThreshold ?? this.perclosAlarmThreshold,
      headNodPitchThreshold:
          headNodPitchThreshold ?? this.headNodPitchThreshold,
      enableAdaptiveInference:
          enableAdaptiveInference ?? this.enableAdaptiveInference,
      normalInferenceInterval:
          normalInferenceInterval ?? this.normalInferenceInterval,
      alertInferenceInterval:
          alertInferenceInterval ?? this.alertInferenceInterval,
    );
  }
}
