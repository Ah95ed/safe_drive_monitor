/// Represents the discrete states of the local AI model lifecycle.
enum ModelState {
  /// Loading and validating local TFLite model from assets.
  loading,

  /// Verified model is fully loaded and ready for inference.
  ready,

  /// Model asset loading or validation failed.
  failed,
}

extension ModelStateX on ModelState {
  bool get isReady => this == ModelState.ready;
  bool get isFailed => this == ModelState.failed;
  bool get isBusy => this == ModelState.loading;

  String get arabicLabel {
    switch (this) {
      case ModelState.loading:
        return 'جاري تجهيز نظام الذكاء الاصطناعي...';
      case ModelState.ready:
        return 'نظام الذكاء الاصطناعي جاهز';
      case ModelState.failed:
        return 'تعذر تحميل موديل الذكاء الاصطناعي';
    }
  }
}
