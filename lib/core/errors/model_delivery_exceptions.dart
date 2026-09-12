export 'package:safe_drive_monitor/core/errors/app_exceptions.dart' show ModelDeliveryException;

/// Standardized Error Codes for model lifecycle diagnostics
class ModelErrorCodes {
  ModelErrorCodes._();

  static const String modelNotFoundLocal = 'MODEL_NOT_FOUND_LOCAL';
  static const String manifestFetchFailed = 'MANIFEST_FETCH_FAILED';
  static const String manifestSignatureInvalid = 'MANIFEST_SIGNATURE_INVALID';
  static const String modelVersionInvalid = 'MODEL_VERSION_INVALID';
  static const String downloadAuthFailed = 'DOWNLOAD_AUTH_FAILED';
  static const String modelDownloadFailed = 'MODEL_DOWNLOAD_FAILED';
  static const String modelDownloadHttp401 = 'MODEL_DOWNLOAD_HTTP_401';
  static const String modelDownloadHttp403 = 'MODEL_DOWNLOAD_HTTP_403';
  static const String modelDownloadHttp404 = 'MODEL_DOWNLOAD_HTTP_404';
  static const String modelDownloadHttp500 = 'MODEL_DOWNLOAD_HTTP_500';
  static const String modelDownloadTimeout = 'MODEL_DOWNLOAD_TIMEOUT';
  static const String modelDownloadNetworkError = 'MODEL_DOWNLOAD_NETWORK_ERROR';
  static const String modelFileEmpty = 'MODEL_FILE_EMPTY';
  static const String modelFileInvalidSize = 'MODEL_FILE_INVALID_SIZE';
  static const String modelSizeMismatch = 'MODEL_SIZE_MISMATCH';
  static const String modelHashMismatch = 'MODEL_HASH_MISMATCH';
  static const String modelKeyUnwrapFailed = 'MODEL_KEY_UNWRAP_FAILED';
  static const String modelDecryptionFailed = 'MODEL_DECRYPTION_FAILED';
  static const String modelGcmAuthFailed = 'MODEL_GCM_AUTH_FAILED';
  static const String modelTfliteHealthCheckFailed = 'MODEL_TFLITE_HEALTH_CHECK_FAILED';
  static const String modelActivationFailed = 'MODEL_ACTIVATION_FAILED';
  static const String classifierInitFailed = 'CLASSIFIER_INIT_FAILED';
  static const String modelBootstrapFailed = 'MODEL_BOOTSTRAP_FAILED';
}
