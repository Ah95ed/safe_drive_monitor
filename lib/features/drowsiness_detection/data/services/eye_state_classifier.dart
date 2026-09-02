import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class EyeStateClassifier {
  bool get isLoaded;
  ModelArchitecture get architecture;
  bool get invertYoloClasses;
  set invertYoloClasses(bool value);
  TensorChannelLayout get channelLayout;
  set channelLayout(TensorChannelLayout layout);
  DetectionPipeline get pipeline;
  set pipeline(DetectionPipeline pipeline);
  ModelOutputMode get outputMode;
  set outputMode(ModelOutputMode mode);
  double get minOpenConfidence;
  set minOpenConfidence(double value);
  double get minClosedConfidence;
  set minClosedConfidence(double value);
  bool get useDirectFastPipeline;
  set useDirectFastPipeline(bool value);
  set roiStrategy(RoiStrategy value);

  Future<void> load();
  Future<EyePrediction> classify(
    CameraImage image, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
  });
  Future<EyePrediction> classifyFloat32(Float32List inputBuffer);
  Future<void> dispose();
}

class TfliteEyeStateClassifier implements EyeStateClassifier {
  static const String _tag = 'TfliteClassifier';

  Interpreter? _interpreter;
  final ImagePreprocessor _preprocessor;
  ModelArchitecture _architecture = ModelArchitecture.yoloDetector;

  @override
  bool invertYoloClasses = false;

  @override
  ModelArchitecture get architecture => _architecture;

  @override
  ModelOutputMode outputMode;

  @override
  double minOpenConfidence;

  @override
  double minClosedConfidence;

  @override
  bool get useDirectFastPipeline => _preprocessor.useDirectFastPipeline;

  @override
  set useDirectFastPipeline(bool value) {
    _preprocessor.useDirectFastPipeline = value;
  }

  @override
  set roiStrategy(RoiStrategy value) {
    _preprocessor.roiStrategy = value;
  }

  TfliteEyeStateClassifier({
    ImagePreprocessor? preprocessor,
    this.outputMode = ModelOutputMode.auto,
    this.minOpenConfidence = 0.55,
    this.minClosedConfidence = 0.55,
  }) : _preprocessor = preprocessor ?? ImagePreprocessor();

  @override
  bool get isLoaded => _interpreter != null;

  @override
  TensorChannelLayout get channelLayout => _preprocessor.channelLayout;

  @override
  set channelLayout(TensorChannelLayout layout) {
    _preprocessor.channelLayout = layout;
  }

  @override
  DetectionPipeline get pipeline => _preprocessor.pipeline;

  @override
  set pipeline(DetectionPipeline pipeline) {
    _preprocessor.pipeline = pipeline;
  }

  @override
  Future<void> load() async {
    if (_interpreter != null) return;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        ModelConstants.modelAssetPath,
        options: options,
      );

      // Pre-allocate tensors on load
      _interpreter!.allocateTensors();

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      if (inputTensors.isEmpty) {
        throw const ModelLoadException('TFLite model has no input tensors');
      }
      if (outputTensors.isEmpty) {
        throw const ModelLoadException('TFLite model has no output tensors');
      }

      final inputTensor = inputTensors.first;
      final outputTensor = outputTensors.first;

      // 1. Validate and adapt to input tensor shape [1, H, W, 3]
      if (inputTensor.shape.length != 4 ||
          inputTensor.shape[0] != 1 ||
          inputTensor.shape[3] != 3) {
        throw ModelLoadException(
          'TFLite model input shape mismatch: got ${inputTensor.shape}, expected [1, H, W, 3]',
        );
      }

      final int inH = inputTensor.shape[1];
      final int inW = inputTensor.shape[2];
      _preprocessor.setInputDimensions(inW, inH);

      // 2. Validate input tensor type Float32 or Float16
      if (inputTensor.type != TensorType.float32 &&
          inputTensor.type != TensorType.float16) {
        throw ModelLoadException(
          'TFLite model input type mismatch: got ${inputTensor.type}, expected ${TensorType.float32} or ${TensorType.float16}',
        );
      }

      // 3. Detect architecture from output tensor shape:
      // YOLOv5/v8: [1, N, 7] (e.g. [1, 6300, 7])
      // Classification: [1, 2] or [1, 1, 2]
      final bool isYolo = (outputTensor.shape.length == 3 && outputTensor.shape[2] == 7) ||
                          (outputTensor.shape.length == 2 && outputTensor.shape[1] == 7);
      final bool isClassification = (outputTensor.shape.length == 2 && outputTensor.shape[1] == 2) ||
                                    (outputTensor.shape.length == 3 && outputTensor.shape[2] == 2);

      if (!isYolo && !isClassification) {
        throw ModelLoadException(
          'Unsupported TFLite output shape: ${outputTensor.shape}. '
          'Expected [1, 2] (classification) or [1, N, 7] (YOLO detector)',
        );
      }

      _architecture = isYolo ? ModelArchitecture.yoloDetector : ModelArchitecture.classification;

      // 4. Set appropriate normalization:
      // YOLO models use [0.0, 1.0] (zeroToOne), while older TF classifier uses [-1.0, 1.0] (minusOneToOne)
      if (isYolo) {
        _preprocessor.normalization = ModelInputNormalization.zeroToOne;
      } else {
        _preprocessor.normalization = ModelInputNormalization.minusOneToOne;
      }

      AppLogger.info(
        _tag,
        'TFLite model loaded successfully: architecture=${_architecture.name}, '
        'input=${inputTensor.shape} (${inputTensor.type.name}), '
        'output=${outputTensor.shape} (${outputTensor.type.name}), '
        'normalization=${_preprocessor.normalization.name}',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to load or validate TFLite model', e, st);
      if (e is AppException) rethrow;
      throw ModelLoadException('Failed to load eye state TFLite model', e);
    }
  }

  @override
  Future<EyePrediction> classify(
    CameraImage image, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
  }) async {
    if (_interpreter == null) {
      throw const ModelLoadException('Model interpreter is not initialized');
    }

    final Float32List inputTensor = _preprocessor.preprocessCameraImage(
      image,
      sensorRotation: sensorRotation,
      isMirrored: isMirrored,
      dynamicRoi: dynamicRoi,
    );

    return classifyFloat32(inputTensor);
  }

  @override
  Future<EyePrediction> classifyFloat32(Float32List inputBuffer) async {
    if (_interpreter == null) {
      throw const ModelLoadException('Model interpreter is not initialized');
    }

    try {
      final stopwatch = Stopwatch()..start();

      final inputTensor = _interpreter!.getInputTensor(0);
      final Uint8List inputBytes;
      if (inputTensor.type == TensorType.float16) {
        inputBytes = _convertFloat32ToHalfBytes(inputBuffer);
      } else {
        inputBytes = inputBuffer.buffer.asUint8List(
          inputBuffer.offsetInBytes,
          inputBuffer.lengthInBytes,
        );
      }
      inputTensor.data = inputBytes;

      // Execute inference via native C-API invoke
      _interpreter!.invoke();

      // Read output floats directly from output tensor buffer respecting offsets
      final outputTensor = _interpreter!.getOutputTensor(0);
      final Float32List outputFloats;

      if (outputTensor.type == TensorType.float16) {
        final outputBytes = outputTensor.data;
        outputFloats = _convertHalfBytesToFloat32List(outputBytes);
      } else {
        final outputBytes = outputTensor.data;
        outputFloats = outputBytes.buffer.asFloat32List(
          outputBytes.offsetInBytes,
          outputBytes.lengthInBytes ~/ 4,
        );
      }

      double openScore;
      double closedScore;

      if (_architecture == ModelArchitecture.yoloDetector) {
        // Output format [1, N, 7] (e.g. 6300 candidate boxes)
        final int numCandidates = outputFloats.length ~/ 7;
        double maxConf0 = 0.0;
        double maxConf1 = 0.0;
        int detectedBoxes = 0;

        for (int i = 0; i < numCandidates; i++) {
          final int base = i * 7;
          final double objConf = outputFloats[base + 4];
          if (objConf < 0.20) continue; // Filter background noise

          final double c0 = outputFloats[base + 5];
          final double c1 = outputFloats[base + 6];
          final double score0 = objConf * c0;
          final double score1 = objConf * c1;

          if (score0 > maxConf0) maxConf0 = score0;
          if (score1 > maxConf1) maxConf1 = score1;
          detectedBoxes++;
        }

        if (detectedBoxes == 0) {
          openScore = 0.0;
          closedScore = 0.0;
        } else if (invertYoloClasses) {
          openScore = maxConf0;
          closedScore = maxConf1;
        } else {
          // In Roboflow YOLO dataset (rmbg_all):
          // Class 0: closedeyes, Class 1: openeyes
          closedScore = maxConf0;
          openScore = maxConf1;
        }
      } else {
        // Classification model [1, 2]
        openScore = outputFloats.isNotEmpty ? outputFloats[0] : 0.0;
        closedScore = outputFloats.length > 1 ? outputFloats[1] : 0.0;
      }

      stopwatch.stop();

      final result = EyePredictionModel.fromRawOutput(
        rawOutput: [openScore, closedScore],
        inferenceTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
        outputMode: outputMode,
        minOpenConfidence: minOpenConfidence,
        minClosedConfidence: minClosedConfidence,
      );

      return result;
    } catch (e, st) {
      AppLogger.error(_tag, 'Inference execution failed', e, st);
      if (e is AppException) rethrow;
      throw InferenceException('Inference error', e);
    }
  }

  Uint8List _convertFloat32ToHalfBytes(Float32List input) {
    final output = Uint8List(input.length * 2);
    final inputView = ByteData.view(input.buffer, input.offsetInBytes, input.lengthInBytes);
    final outputView = ByteData.sublistView(output);
    for (int i = 0; i < input.length; i++) {
      final int f = inputView.getUint32(i * 4, Endian.little);
      final bits = _float32ToHalfBits(f);
      outputView.setUint16(i * 2, bits, Endian.little);
    }
    return output;
  }

  Float32List _convertHalfBytesToFloat32List(Uint8List halfBytes) {
    final output = Float32List(halfBytes.length ~/ 2);
    final inputView = ByteData.view(halfBytes.buffer, halfBytes.offsetInBytes, halfBytes.lengthInBytes);
    for (int i = 0; i < output.length; i++) {
      final bits = inputView.getUint16(i * 2, Endian.little);
      output[i] = _halfBitsToFloat32(bits);
    }
    return output;
  }

  int _float32ToHalfBits(int f) {
    if ((f & 0x7FFFFFFF) == 0) {
      return (f >> 16) & 0x8000;
    }
    if ((f & 0x7F800000) == 0x7F800000) {
      return ((f >> 16) & 0x8000) | 0x7C00 | ((f & 0x7FFFFF) != 0 ? 0x200 : 0);
    }

    int exponent = ((f >> 23) & 0xFF) - 127 + 15;
    final int mantissa = (f >> 13) & 0x3FF;

    if (exponent <= 0) {
      if (exponent <= -10) {
        return (f >> 16) & 0x8000;
      }
      int m = (0x400 + mantissa) >> (-exponent + 1);
      m += (m & 1);
      if (m > 0x3FF) m = 0x3FF;
      return ((f >> 16) & 0x8000) | m;
    }

    if (exponent >= 31) {
      return ((f >> 16) & 0x8000) | 0x7C00;
    }

    return ((f >> 16) & 0x8000) | (exponent << 10) | mantissa;
  }

  double _halfBitsToFloat32(int bits) {
    final int sign = (bits >> 15) & 0x1;
    final int exponent = (bits >> 10) & 0x1F;
    final int mantissa = bits & 0x3FF;

    if (exponent == 0) {
      if (mantissa == 0) {
        return sign == 1 ? -0.0 : 0.0;
      }
      double m = mantissa / 1024.0;
      int shift = 1;
      while (m < 1.0 && shift <= 10) {
        m *= 2.0;
        shift++;
      }
      return sign == 1 ? -m : m;
    } else if (exponent == 31) {
      if (mantissa == 0) {
        return sign == 1 ? double.negativeInfinity : double.infinity;
      }
      return double.nan;
    }

    final int fExponent = exponent - 15 + 127;
    final int fMantissa = mantissa << 13;
    final int fBits = (sign << 31) | (fExponent << 23) | fMantissa;

    final bd = ByteData(4);
    bd.setUint32(0, fBits, Endian.little);
    return bd.getFloat32(0, Endian.little);
  }

  @override
  Future<void> dispose() async {
    try {
      _interpreter?.close();
      _interpreter = null;
      AppLogger.info(_tag, 'TFLite classifier disposed.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error disposing interpreter', e, st);
    }
  }
}
