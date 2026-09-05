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

  /// Rolling time window duration for alarm recovery evaluation (default 900ms).
  final Duration recoveryWindowDuration;

  /// Minimum ratio of OPEN predictions in the rolling recovery window (default 0.70 = 70%).
  final double recoveryMinOpenRatio;

  /// Minimum Exponential Moving Average (EMA) open confidence for recovery (default 0.60).
  final double recoveryMinEmaConfidence;

  /// Recent window duration where no strong CLOSED prediction is permitted during recovery (default 250ms).
  final Duration recoveryRecentClosedWindow;

  /// Confidence threshold above which a recent CLOSED prediction aborts recovery (default 0.65).
  final double recoveryRecentClosedMinConfidence;

  /// Maximum allowed ratio of UNKNOWN predictions before recovery confirmation is paused (default 0.40).
  final double recoveryMaxUnknownRatio;

  /// Smoothing factor alpha for EMA open confidence (default 0.65).
  final double recoveryEmaAlpha;

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
    this.recoveryWindowDuration = const Duration(milliseconds: 900),
    this.recoveryMinOpenRatio = 0.70,
    this.recoveryMinEmaConfidence = 0.60,
    this.recoveryRecentClosedWindow = const Duration(milliseconds: 250),
    this.recoveryRecentClosedMinConfidence = 0.65,
    this.recoveryMaxUnknownRatio = 0.40,
    this.recoveryEmaAlpha = 0.65,
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
    Duration? recoveryWindowDuration,
    double? recoveryMinOpenRatio,
    double? recoveryMinEmaConfidence,
    Duration? recoveryRecentClosedWindow,
    double? recoveryRecentClosedMinConfidence,
    double? recoveryMaxUnknownRatio,
    double? recoveryEmaAlpha,
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
      recoveryWindowDuration:
          recoveryWindowDuration ?? this.recoveryWindowDuration,
      recoveryMinOpenRatio:
          recoveryMinOpenRatio ?? this.recoveryMinOpenRatio,
      recoveryMinEmaConfidence:
          recoveryMinEmaConfidence ?? this.recoveryMinEmaConfidence,
      recoveryRecentClosedWindow:
          recoveryRecentClosedWindow ?? this.recoveryRecentClosedWindow,
      recoveryRecentClosedMinConfidence:
          recoveryRecentClosedMinConfidence ?? this.recoveryRecentClosedMinConfidence,
      recoveryMaxUnknownRatio:
          recoveryMaxUnknownRatio ?? this.recoveryMaxUnknownRatio,
      recoveryEmaAlpha:
          recoveryEmaAlpha ?? this.recoveryEmaAlpha,
    );
  }
}
