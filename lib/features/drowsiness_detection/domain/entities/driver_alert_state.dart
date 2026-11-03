enum DriverAlertState {
  /// Eyes open and responsive. Normal driving state.
  normal,

  /// Eyes closed between 350ms and 800ms. Potential onset of micro-sleep or extended blink.
  watching,

  /// Eyes closed between 800ms and 1200ms. Drowsiness suspected.
  drowsy,

  /// Eyes closed >= 1200ms. Severe drowsiness / sleep confirmed. Loud alarm active.
  alarm,

  /// Eyes confirmed reopening from alarm; confirmation window in progress.
  recovering,

  /// No face detected in camera frame (> 2s). Degraded state requiring audible alert.
  noFaceDetected,

  /// Ambient lighting critically low. Vision unreliable; requires audible alert.
  insufficientLight,

  /// Camera frame stream or inference pipeline stalled (> 3s). Requires audible alert.
  monitoringStalled,

  /// Device hardware is under severe thermal throttling. Requires audible alert.
  thermalThrottled,
}

extension DriverAlertStateX on DriverAlertState {
  bool get isAlarm =>
      this == DriverAlertState.alarm || this == DriverAlertState.recovering;
  bool get isRecovering => this == DriverAlertState.recovering;
  bool get isDrowsy => this == DriverAlertState.drowsy;
  bool get isWatching => this == DriverAlertState.watching;
  bool get isNormal => this == DriverAlertState.normal;
  bool get isDegraded =>
      this == DriverAlertState.noFaceDetected ||
      this == DriverAlertState.insufficientLight ||
      this == DriverAlertState.monitoringStalled ||
      this == DriverAlertState.thermalThrottled;

  String get warningMessage {
    switch (this) {
      case DriverAlertState.noFaceDetected:
        return 'وجه السائق غير ظاهر — اضبط موضع الهاتف';
      case DriverAlertState.insufficientLight:
        return 'الإضاءة منخفضة جداً — شغل إضاءة المقصورة';
      case DriverAlertState.monitoringStalled:
        return 'توقف تحليل الكاميرا — أعد تشغيل التطبيق';
      case DriverAlertState.thermalThrottled:
        return 'حرارة الجهاز مرتفعة — تم تقليل معدل المعالجة';
      default:
        return arabicLabel;
    }
  }

  String get arabicLabel {
    switch (this) {
      case DriverAlertState.normal:
        return 'منتبه';
      case DriverAlertState.watching:
        return 'متابعة حذرة';
      case DriverAlertState.drowsy:
        return 'نعاس محتمل';
      case DriverAlertState.alarm:
        return 'إنذار نعاس!';
      case DriverAlertState.recovering:
        return 'استعادة اليقظة...';
      case DriverAlertState.noFaceDetected:
        return 'لم يُكتشف وجه';
      case DriverAlertState.insufficientLight:
        return 'إضاءة غير كافية';
      case DriverAlertState.monitoringStalled:
        return 'توقف تدفق المراقبة';
      case DriverAlertState.thermalThrottled:
        return 'ارتفاع حرارة الجهاز';
    }
  }
}
