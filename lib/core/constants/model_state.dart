/// Represents the discrete states of the AI model lifecycle.
enum ModelState {
  /// No valid model has been downloaded or verified locally yet.
  notInstalled,

  /// Checking if a valid active model already exists locally.
  checking,

  /// Currently downloading candidate model bytes from Cloudflare Worker / R2.
  downloading,

  /// Verifying model container checksums and Ed25519 manifest digital signature.
  verifying,

  /// Decrypting AES-256-GCM model container via native hardware Keystore.
  decrypting,

  /// Executing TFLite health check and shape/tensor contract verification.
  validating,

  /// Verified model is fully loaded, authenticated, and ready for inference.
  ready,

  /// Model bootstrap, download, or integrity check failed.
  failed,
}

extension ModelStateX on ModelState {
  bool get isReady => this == ModelState.ready;
  bool get isFailed => this == ModelState.failed;
  bool get isBusy =>
      this == ModelState.checking ||
      this == ModelState.downloading ||
      this == ModelState.verifying ||
      this == ModelState.decrypting ||
      this == ModelState.validating;

  String get arabicLabel {
    switch (this) {
      case ModelState.notInstalled:
        return 'يتطلب تنزيل نظام الذكاء الاصطناعي لأول مرة';
      case ModelState.checking:
        return 'جاري التحقق من وجود الموديل المحلي...';
      case ModelState.downloading:
        return 'جاري تنزيل نموذج الذكاء الاصطناعي...';
      case ModelState.verifying:
        return 'جاري التحقق من سلامة الموديل والتوقيع الرقمي...';
      case ModelState.decrypting:
        return 'جاري فك تشفير النموذج بأمان...';
      case ModelState.validating:
        return 'جاري اختبار صحة الذكاء الاصطناعي...';
      case ModelState.ready:
        return '✓ نظام الذكاء الاصطناعي جاهز';
      case ModelState.failed:
        return 'تعذر تجهيز نظام الذكاء الاصطناعي';
    }
  }
}
