/// Supported model architectures
enum ModelArchitecture {
  classification, // e.g. [1, 2]
  yoloDetector,   // e.g. [1, 6300, 7]
}

/// Supported model input normalizations
enum ModelInputNormalization {
  zeroToOne,      // pixel / 255.0 (Standard YOLO)
  minusOneToOne,  // (pixel - 128.0) / 128.0 (TensorFlow default)
}

/// Model constants matching the TensorFlow Lite model specification.
class ModelConstants {
  ModelConstants._();

  static const String modelAssetPath = String.fromEnvironment(
    'EYE_MODEL',
    defaultValue: 'assets/models/eye_detector_5n_320_float16.enc',
  );

  static const String cloudflareWorkerBaseUrl =
      'https://drivealert-model-service.amhmeed31.workers.dev';

  /// Ed25519 Public Key for verifying digital signatures of Model Manifests
  static const String modelSigningPublicKeyBase64 =
      'MCowBQYDK2VwAyEAsR49zvjMtlSOzWteh/8OyG/McD7SIKhe/HULH76+22I=';

  /// Anti-rollback versioning
  static const int minSupportedModelVersion = 1;
  static const int currentModelVersion = 1;

  /// Expected SHA-256 digests for model integrity validation
  static const String bundledEncryptedSha256 =
      'd916701d89db7018979d24d81db42519f5f43e6b7cc0e535bc884904914b5f44';
  static const String bundledPlainModelSha256 =
      '90909fc26dc9217c2948879af72b72d94c55ef97b47e7a76a11e11fc193f5918';

  static const int inputWidth = 320;
  static const int inputHeight = 320;
  static const int inputChannels = 3;
  static const int batchSize = 1;
  static const int totalInputFloats = inputWidth * inputHeight * inputChannels;

  static const double imageMean = 128.0;
  static const double imageStd = 128.0;

  static const int outputBatch = 1;
  static const int outputClasses = 2;
}

/// Explicit label mapping:
/// In Roboflow YOLO dataset (rmbg_all):
/// Class 0: closedeyes
/// Class 1: openeyes
class ModelLabels {
  ModelLabels._();

  static const int open = 0;
  static const int closed = 1;

  static const int yoloClosed = 0;
  static const int yoloOpen = 1;
}
