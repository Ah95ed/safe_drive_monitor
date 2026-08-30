import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class EyeStateClassifier {
  bool get isLoaded;
  TensorChannelLayout get channelLayout;
  set channelLayout(TensorChannelLayout layout);
  DetectionPipeline get pipeline;
  set pipeline(DetectionPipeline pipeline);

  Future<void> load();
  Future<EyePrediction> classify(CameraImage image, {int sensorRotation = 0});
  Future<EyePrediction> classifyFloat32(Float32List inputBuffer);
  Future<void> dispose();
}

class TfliteEyeStateClassifier implements EyeStateClassifier {
  static const String _tag = 'TfliteClassifier';

  Interpreter? _interpreter;
  ImagePreprocessor _preprocessor;

  // Reusable output buffer [ [openScore, closedScore] ]
  final List<List<double>> _outputBuffer = [
    [0.0, 0.0]
  ];

  TfliteEyeStateClassifier({
    ImagePreprocessor? preprocessor,
  }) : _preprocessor = preprocessor ?? ImagePreprocessor();

  @override
  bool get isLoaded => _interpreter != null;

  @override
  TensorChannelLayout get channelLayout => _preprocessor.channelLayout;

  @override
  set channelLayout(TensorChannelLayout layout) {
    _preprocessor = ImagePreprocessor(
      channelLayout: layout,
      pipeline: _preprocessor.pipeline,
    );
  }

  @override
  DetectionPipeline get pipeline => _preprocessor.pipeline;

  @override
  set pipeline(DetectionPipeline pipeline) {
    _preprocessor = ImagePreprocessor(
      channelLayout: _preprocessor.channelLayout,
      pipeline: pipeline,
    );
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
      AppLogger.info(
        _tag,
        'TFLite model loaded. Input shape: ${inputTensors.isNotEmpty ? inputTensors.first.shape : "unknown"}, '
        'Output shape: ${outputTensors.isNotEmpty ? outputTensors.first.shape : "unknown"}',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to load TFLite model', e, st);
      throw ModelLoadException('Failed to load eye state TFLite model', e);
    }
  }

  @override
  Future<EyePrediction> classify(
    CameraImage image, {
    int sensorRotation = 0,
  }) async {
    if (_interpreter == null) {
      throw const ModelLoadException('Model interpreter is not initialized');
    }

    final Float32List inputTensor = _preprocessor.preprocessCameraImage(
      image,
      sensorRotation: sensorRotation,
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

      // Direct copy of normalized Float32 bytes into TFLite input tensor
      final inputBytes = inputBuffer.buffer.asUint8List();
      final inputTensor = _interpreter!.getInputTensor(0);
      inputTensor.data = inputBytes;

      // Execute inference via native C-API invoke
      _interpreter!.invoke();

      // Read output floats directly from output tensor buffer
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputFloats = outputTensor.data.buffer.asFloat32List();

      final double openScore = outputFloats.isNotEmpty ? outputFloats[0] : 0.0;
      final double closedScore = outputFloats.length > 1 ? outputFloats[1] : 0.0;

      stopwatch.stop();

      final result = EyePredictionModel.fromRawOutput(
        rawOutput: [openScore, closedScore],
        inferenceTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );

      return result;
    } catch (e, st) {
      AppLogger.error(_tag, 'Inference execution failed', e, st);
      throw InferenceException('Inference error', e);
    }
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
