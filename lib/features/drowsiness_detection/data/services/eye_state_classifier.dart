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
  set debugRawOutput(bool value);
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

  /// When true, logs raw model output + ROI + layout once per second so the
  /// open/closed label order and preprocessing can be verified on-device.
  bool debugRawOutput = false;
  DateTime _lastRawLog = DateTime.fromMillisecondsSinceEpoch(0);
  Rect? _lastRoi;

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

      final expectedInputShape = [
        ModelConstants.batchSize,
        ModelConstants.inputHeight,
        ModelConstants.inputWidth,
        ModelConstants.inputChannels,
      ];
      final expectedOutputShape = [
        ModelConstants.outputBatch,
        ModelConstants.outputClasses,
      ];

      // 1. Validate input tensor shape [1, H, W, 3]
      if (inputTensor.shape.length != expectedInputShape.length ||
          inputTensor.shape[0] != expectedInputShape[0] ||
          inputTensor.shape[1] != expectedInputShape[1] ||
          inputTensor.shape[2] != expectedInputShape[2] ||
          inputTensor.shape[3] != expectedInputShape[3]) {
        throw ModelLoadException(
          'TFLite model input shape mismatch: got ${inputTensor.shape}, expected $expectedInputShape',
        );
      }

      // 2. Validate input tensor type Float32 or Float16
      if (inputTensor.type != TensorType.float32 &&
          inputTensor.type != TensorType.float16) {
        throw ModelLoadException(
          'TFLite model input type mismatch: got ${inputTensor.type}, expected ${TensorType.float32} or ${TensorType.float16}',
        );
      }

      // 3. Validate output tensor shape [1, 2]
      if (outputTensor.shape.length != expectedOutputShape.length ||
          outputTensor.shape[0] != expectedOutputShape[0] ||
          outputTensor.shape[1] != expectedOutputShape[1]) {
        throw ModelLoadException(
          'TFLite model output shape mismatch: got ${outputTensor.shape}, expected $expectedOutputShape',
        );
      }

      // 4. Validate output tensor type Float32 or Float16
      if (outputTensor.type != TensorType.float32 &&
          outputTensor.type != TensorType.float16) {
        throw ModelLoadException(
          'TFLite model output type mismatch: got ${outputTensor.type}, expected ${TensorType.float32} or ${TensorType.float16}',
        );
      }

      AppLogger.info(
        _tag,
        'TFLite model validated and loaded successfully. '
        'Input shape: ${inputTensor.shape} (${inputTensor.type.name}), '
        'Output shape: ${outputTensor.shape} (${outputTensor.type.name})',
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
    _lastRoi = dynamicRoi;

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
      final double openScore;
      final double closedScore;

      if (outputTensor.type == TensorType.float16) {
        final outputBytes = outputTensor.data;
        final halfList = _convertHalfBytesToFloat32List(outputBytes);
        openScore = halfList.isNotEmpty ? halfList[0] : 0.0;
        closedScore = halfList.length > 1 ? halfList[1] : 0.0;
      } else {
        final outputBytes = outputTensor.data;
        final outputFloats = outputBytes.buffer.asFloat32List(
          outputBytes.offsetInBytes,
          outputBytes.lengthInBytes ~/ 4,
        );
        openScore = outputFloats.isNotEmpty ? outputFloats[0] : 0.0;
        closedScore = outputFloats.length > 1 ? outputFloats[1] : 0.0;
      }

      stopwatch.stop();

      if (debugRawOutput) {
        final now = DateTime.now();
        if (now.difference(_lastRawLog) >= const Duration(seconds: 1)) {
          _lastRawLog = now;
          AppLogger.debug(
            _tag,
            'RAW out=[${openScore.toStringAsFixed(4)}, ${closedScore.toStringAsFixed(4)}] '
            'sum=${(openScore + closedScore).toStringAsFixed(4)} '
            'layout=${_preprocessor.channelLayout.name} '
            'pipeline=${_preprocessor.pipeline.name} '
            'roiStrat=${_preprocessor.roiStrategy.name} '
            'roi=${_lastRoi == null ? "none" : "${_lastRoi!.left.toStringAsFixed(0)},${_lastRoi!.top.toStringAsFixed(0)} ${_lastRoi!.width.toStringAsFixed(0)}x${_lastRoi!.height.toStringAsFixed(0)}"}',
          );
          _logAsciiThumbnail(inputBuffer);
        }
      }

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

  /// Renders the normalized model input buffer as a small ASCII luminance grid so
  /// the actual crop fed to the network is visible in `adb logcat`.
  void _logAsciiThumbnail(Float32List buf) {
    const int w = ModelConstants.inputWidth;
    const int h = ModelConstants.inputHeight;
    const int cols = 40;
    const int rows = 24;
    const int plane = w * h;
    const String ramp = ' .:-=+*#%@';
    final bool planar = _preprocessor.channelLayout == TensorChannelLayout.planarRgb;
    final sb = StringBuffer('\n');
    for (int r = 0; r < rows; r++) {
      final int y = (r * h / rows).floor();
      for (int c = 0; c < cols; c++) {
        final int x = (c * w / cols).floor();
        double rr, gg, bb;
        if (planar) {
          final int i = y * w + x;
          rr = buf[i]; gg = buf[plane + i]; bb = buf[2 * plane + i];
        } else {
          final int i = (y * w + x) * 3;
          rr = buf[i]; gg = buf[i + 1]; bb = buf[i + 2];
        }
        // De-normalize (v*128+128) -> 0..255, then to luma 0..1.
        final double luma = ((rr + gg + bb) / 3.0 * 128.0 + 128.0) / 255.0;
        final int idx = (luma.clamp(0.0, 1.0) * (ramp.length - 1)).round();
        sb.write(ramp[idx]);
      }
      sb.write('\n');
    }
    AppLogger.debug(_tag, 'model-input thumbnail (${cols}x$rows):$sb');
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
