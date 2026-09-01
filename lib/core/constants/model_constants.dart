/// Model constants matching the original TensorFlow Lite model specification.
class ModelConstants {
  ModelConstants._();

  /// Active eye-state model. Override for A/B testing without a rebuild of
  /// constants via:
  ///   `flutter run --dart-define=EYE_MODEL=assets/models/NAME.tflite`
  /// Candidates in this repo:
  ///   eye_state_model_tensorFlow.tflite          (12 MB, default)
  ///   eye_state_model_tensorFlow114.tflite       (12 MB)
  ///   eye_state_model_tensorFlow_opt_default.tflite (5.6 MB, optimized)
  static const String modelAssetPath = String.fromEnvironment(
    'EYE_MODEL',
    defaultValue: 'assets/models/eye_state_model_tensorFlow.tflite',
  );

  static const int inputWidth = 224;
  static const int inputHeight = 224;
  static const int inputChannels = 3;
  static const int batchSize = 1;
  static const int totalInputFloats = inputWidth * inputHeight * inputChannels;

  static const double imageMean = 128.0;
  static const double imageStd = 128.0;

  static const int outputBatch = 1;
  static const int outputClasses = 2;
}

/// Explicit label mapping matching Java Android reference:
/// output[0][0] -> Open
/// output[0][1] -> Closed
class ModelLabels {
  ModelLabels._();

  static const int open = 0;
  static const int closed = 1;
}
