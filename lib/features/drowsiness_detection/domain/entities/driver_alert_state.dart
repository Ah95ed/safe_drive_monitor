enum DriverAlertState {
  /// Eyes open and responsive. Normal driving state.
  normal,

  /// Eyes closed between 400ms and 1000ms. Potential onset of micro-sleep or extended blink.
  watching,

  /// Eyes closed between 1000ms and 1500ms. Drowsiness suspected.
  drowsy,

  /// Eyes closed >= 1500ms. Severe drowsiness / sleep confirmed. Loud alarm active.
  alarm,

  /// Eyes confirmed reopening from alarm; confirmation window in progress.
  recovering,
}

extension DriverAlertStateX on DriverAlertState {
  bool get isAlarm =>
      this == DriverAlertState.alarm || this == DriverAlertState.recovering;
  bool get isRecovering => this == DriverAlertState.recovering;
  bool get isDrowsy => this == DriverAlertState.drowsy;
  bool get isWatching => this == DriverAlertState.watching;
  bool get isNormal => this == DriverAlertState.normal;
}
