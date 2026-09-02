/// Model constants matching the TensorFlow Lite model specification.
class ModelConstants {
  ModelConstants._();

  static const String modelAssetPath = String.fromEnvironment(
    'EYE_MODEL',
    defaultValue: 'assets/models/eye_detector_5n_320_float16.tflite',
  );

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

/// Explicit label mapping matching Java Android reference:
/// output[0][0] -> Open
/// output[0][1] -> Closed
class ModelLabels {
  ModelLabels._();

  static const int open = 0;
  static const int closed = 1;
}
