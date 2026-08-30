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
      AppLogger.info(_tag, 'TFLite eye state model loaded successfully.');
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

      // Format input as [1, 224, 224, 3] or flat Float32List according to tflite_flutter
      // For Float32List with 150528 elements, tflite_flutter handles reshape internally
      final input = inputBuffer.reshape([
        ModelConstants.batchSize,
        ModelConstants.inputHeight,
        ModelConstants.inputWidth,
        ModelConstants.inputChannels,
      ]);

      _outputBuffer[0][0] = 0.0;
      _outputBuffer[0][1] = 0.0;

      _interpreter!.run(input, _outputBuffer);
      stopwatch.stop();

      final result = EyePredictionModel.fromRawOutput(
        rawOutput: _outputBuffer[0],
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
