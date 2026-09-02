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
