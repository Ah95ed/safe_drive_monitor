import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/models/eye_prediction_model.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/eye_state_classifier.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Request message sent to initialize the dedicated inference isolate.
class _WorkerInitRequest {
  final String modelAssetPath;
  final Uint8List? modelBytes;
  final bool invertYoloClasses;
  final RootIsolateToken? rootIsolateToken;
  final SendPort mainSendPort;

  const _WorkerInitRequest({
    required this.modelAssetPath,
    this.modelBytes,
    required this.invertYoloClasses,
    required this.rootIsolateToken,
    required this.mainSendPort,
  });
}

/// Acknowledgment response sent by the worker isolate upon loading interpreter.
class _WorkerInitResponse {
  final bool success;
  final String? error;
  final SendPort? workerSendPort;
  final ModelArchitecture architecture;
  final bool outputIsSoftmaxed;
  final int inputWidth;
  final int inputHeight;

  const _WorkerInitResponse({
    required this.success,
    this.error,
    this.workerSendPort,
    this.architecture = ModelArchitecture.yoloDetector,
    this.outputIsSoftmaxed = false,
    this.inputWidth = 224,
    this.inputHeight = 224,
  });
}

/// Single inference invocation request containing zero-copy transferable tensor data.
class _WorkerInferenceRequest {
  final int requestId;
  final TransferableTypedData inputData;
  final DateTime timestamp;

  const _WorkerInferenceRequest({
    required this.requestId,
    required this.inputData,
    required this.timestamp,
  });
}

/// Inference completion response sent back to main isolate.
class _WorkerInferenceResponse {
  final int requestId;
  final double openScore;
  final double closedScore;
  final int elapsedMicroseconds;
  final DateTime timestamp;
  final String? error;

  const _WorkerInferenceResponse({
    required this.requestId,
    required this.openScore,
    required this.closedScore,
    required this.elapsedMicroseconds,
    required this.timestamp,
    this.error,
  });
}

/// Disposal signal sent to terminate the worker isolate cleanly.
class _WorkerDisposeRequest {
  const _WorkerDisposeRequest();
}

/// Dedicated, long-lived background Isolate-backed [EyeStateClassifier].
/// Completely offloads TFLite invocation from the main UI thread to prevent frame drops.
class IsolateEyeStateClassifier implements EyeStateClassifier {
  static const String _tag = 'IsolateClassifier';

  final ImagePreprocessor _preprocessor;
  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  StreamSubscription? _receiveSubscription;

  ModelArchitecture _architecture = ModelArchitecture.yoloDetector;
  bool _outputIsSoftmaxed = false;
  bool _isLoaded = false;
  int _nextRequestId = 0;
  final Map<int, Completer<_WorkerInferenceResponse>> _pendingRequests = {};

  @override
  bool invertYoloClasses = false;

  @override
  ModelArchitecture get architecture => _architecture;

  @override
  bool get outputIsSoftmaxed => _outputIsSoftmaxed;

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
  bool get isLoaded => _isLoaded;

  @override
  bool get isReady => _isLoaded && _workerSendPort != null;

  IsolateEyeStateClassifier({
    ImagePreprocessor? preprocessor,
    this.outputMode = ModelOutputMode.auto,
    this.minOpenConfidence = 0.55,
    this.minClosedConfidence = 0.50,
  }) : _preprocessor = preprocessor ?? ImagePreprocessor();

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    AppLogger.info(_tag, 'Spawning dedicated inference isolate worker...');
    final initCompleter = Completer<_WorkerInitResponse>();
    _mainReceivePort = ReceivePort();

    _receiveSubscription = _mainReceivePort!.listen((message) {
      if (message is _WorkerInitResponse) {
        if (!initCompleter.isCompleted) {
          initCompleter.complete(message);
        }
      } else if (message is _WorkerInferenceResponse) {
        final completer = _pendingRequests.remove(message.requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
      }
    });

    RootIsolateToken? token;
    try {
      token = RootIsolateToken.instance;
    } catch (_) {}

    Uint8List? decryptedModelBytes;
    try {
      final byteData = await rootBundle.load(ModelConstants.modelAssetPath);
      final rawBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      if (rawBytes.length > 8 &&
          rawBytes[0] == 0x53 &&
          rawBytes[1] == 0x44 &&
          rawBytes[2] == 0x4D &&
          rawBytes[3] == 0x5F &&
          rawBytes[4] == 0x45 &&
          rawBytes[5] == 0x4E &&
          rawBytes[6] == 0x43 &&
          rawBytes[7] == 0x01) {
        AppLogger.info(_tag, 'Encrypted model detected. Decrypting in-memory via native channel...');
        const nativeChannel = MethodChannel(
          'com.eyewatchdriver.eye.safe_drive_monitor/foreground_service',
        );
        decryptedModelBytes = await nativeChannel.invokeMethod<Uint8List>(
          'decryptModelBuffer',
          {'encryptedBytes': rawBytes},
        );
      }
    } catch (e) {
      AppLogger.info(_tag, 'Direct model loading pass-through: $e');
    }

    final initRequest = _WorkerInitRequest(
      modelAssetPath: ModelConstants.modelAssetPath,
      modelBytes: decryptedModelBytes,
      invertYoloClasses: invertYoloClasses,
      rootIsolateToken: token,
      mainSendPort: _mainReceivePort!.sendPort,
    );

    try {
      _isolate = await Isolate.spawn(
        _inferenceWorkerEntryPoint,
        initRequest,
        debugName: 'DedicatedInferenceWorker',
      );

      final initResponse = await initCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const ModelLoadException('Inference worker initialization timed out'),
      );

      if (!initResponse.success) {
        throw ModelLoadException('Inference worker failed to initialize: ${initResponse.error}');
      }

      _workerSendPort = initResponse.workerSendPort;
      _architecture = initResponse.architecture;
      _outputIsSoftmaxed = initResponse.outputIsSoftmaxed;
      _preprocessor.setInputDimensions(initResponse.inputWidth, initResponse.inputHeight);
      _isLoaded = true;

      AppLogger.info(
        _tag,
        'Dedicated inference worker active: architecture=${_architecture.name}, '
        'dimensions=${initResponse.inputWidth}x${initResponse.inputHeight}',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to launch inference worker isolate', e, st);
      await dispose();
      if (e is AppException) rethrow;
      throw ModelLoadException('ISOLATE_SPAWN_FAILED', e);
    }
  }

  @override
  Future<EyePrediction> classify(
    CameraImage image, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
    bool applyGammaCorrection = false,
  }) async {
    if (!isReady) {
      throw const ModelLoadException('Inference worker is not initialized');
    }

    final Float32List inputTensor = _preprocessor.preprocessCameraImage(
      image,
      sensorRotation: sensorRotation,
      isMirrored: isMirrored,
      dynamicRoi: dynamicRoi,
      applyGammaCorrection: applyGammaCorrection,
    );

    return classifyFloat32(inputTensor);
  }

  @override
  Future<EyePrediction> classifyFloat32(Float32List inputBuffer) async {
    if (!isReady) {
      throw const ModelLoadException('Inference worker is not initialized');
    }

    final int reqId = ++_nextRequestId;
    final completer = Completer<_WorkerInferenceResponse>();
    _pendingRequests[reqId] = completer;

    // Wrap Float32List bytes in zero-copy TransferableTypedData
    final uint8Bytes = inputBuffer.buffer.asUint8List(
      inputBuffer.offsetInBytes,
      inputBuffer.lengthInBytes,
    );
    final transferable = TransferableTypedData.fromList([uint8Bytes]);

    _workerSendPort!.send(
      _WorkerInferenceRequest(
        requestId: reqId,
        inputData: transferable,
        timestamp: DateTime.now(),
      ),
    );

    final response = await completer.future;
    if (response.error != null) {
      throw InferenceException('Worker inference error: ${response.error}');
    }

    return EyePredictionModel.fromRawOutput(
      rawOutput: [response.openScore, response.closedScore],
      inferenceTime: Duration(microseconds: response.elapsedMicroseconds),
      timestamp: response.timestamp,
      outputMode: outputMode,
      minOpenConfidence: minOpenConfidence,
      minClosedConfidence: minClosedConfidence,
    );
  }

  @override
  Future<void> reinitialize() async {
    AppLogger.info(_tag, 'Reinitializing inference worker...');
    await dispose();
    await load();
  }

  @override
  Future<bool> runHealthCheck() async {
    if (!isReady) {
      try {
        await load();
      } catch (_) {
        return false;
      }
    }
    if (!isReady) return false;

    try {
      final dummyBuffer = Float32List(ModelConstants.totalInputFloats);
      final pred = await classifyFloat32(dummyBuffer);
      return pred.state != EyeState.unknown || pred.confidence >= 0.0;
    } catch (e) {
      AppLogger.warning(_tag, 'Health check failed: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _isLoaded = false;
    try {
      if (_workerSendPort != null) {
        _workerSendPort!.send(const _WorkerDisposeRequest());
        _workerSendPort = null;
      }
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      await _receiveSubscription?.cancel();
      _receiveSubscription = null;
      _mainReceivePort?.close();
      _mainReceivePort = null;
      for (final comp in _pendingRequests.values) {
        if (!comp.isCompleted) {
          comp.completeError(const InferenceException('Inference worker disposed'));
        }
      }
      _pendingRequests.clear();
      AppLogger.info(_tag, 'Dedicated inference worker disposed.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error disposing inference worker', e, st);
    }
  }
}

/// Isolate entry point running TFLite inference off the main thread.
void _inferenceWorkerEntryPoint(_WorkerInitRequest initRequest) async {
  if (initRequest.rootIsolateToken != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(initRequest.rootIsolateToken!);
  }

  final workerReceivePort = ReceivePort();
  Interpreter? interpreter;
  ModelArchitecture architecture = ModelArchitecture.yoloDetector;
  bool outputIsSoftmaxed = false;
  int inW = 224;
  int inH = 224;

  try {
    final options = InterpreterOptions()
      ..threads = 2
      ..useNnApiForAndroid = false;

    try {
      options.addDelegate(XNNPackDelegate());
    } catch (e) {
      // Fallback to default CPU delegate
    }

    if (initRequest.modelBytes != null && initRequest.modelBytes!.isNotEmpty) {
      interpreter = Interpreter.fromBuffer(
        initRequest.modelBytes!,
        options: options,
      );
    } else {
      interpreter = await Interpreter.fromAsset(
        initRequest.modelAssetPath,
        options: options,
      );
    }
    interpreter.allocateTensors();

    final inputTensors = interpreter.getInputTensors();
    final outputTensors = interpreter.getOutputTensors();

    if (inputTensors.isNotEmpty && inputTensors.first.shape.length == 4) {
      inH = inputTensors.first.shape[1];
      inW = inputTensors.first.shape[2];
    }

    if (outputTensors.isNotEmpty) {
      final outShape = outputTensors.first.shape;
      final bool isYolo = (outShape.length == 3 && outShape[2] == 7) ||
          (outShape.length == 2 && outShape[1] == 7);
      architecture = isYolo ? ModelArchitecture.yoloDetector : ModelArchitecture.classification;
    }

    initRequest.mainSendPort.send(
      _WorkerInitResponse(
        success: true,
        workerSendPort: workerReceivePort.sendPort,
        architecture: architecture,
        outputIsSoftmaxed: outputIsSoftmaxed,
        inputWidth: inW,
        inputHeight: inH,
      ),
    );
  } catch (e) {
    initRequest.mainSendPort.send(
      _WorkerInitResponse(
        success: false,
        error: e.toString(),
      ),
    );
    workerReceivePort.close();
    return;
  }

  await for (final message in workerReceivePort) {
    if (message is _WorkerInferenceRequest) {
      try {
        final sw = Stopwatch()..start();
        final Uint8List inputBytes = message.inputData.materialize().asUint8List();
        final inputTensor = interpreter.getInputTensor(0);

        if (inputTensor.type == TensorType.float16) {
          final floatList = inputBytes.buffer.asFloat32List(
            inputBytes.offsetInBytes,
            inputBytes.lengthInBytes ~/ 4,
          );
          inputTensor.data = _convertFloat32ToHalfBytes(floatList);
        } else {
          inputTensor.data = inputBytes;
        }

        interpreter.invoke();

        final outputTensor = interpreter.getOutputTensor(0);
        final Float32List outputFloats;

        if (outputTensor.type == TensorType.float16) {
          outputFloats = _convertHalfBytesToFloat32List(outputTensor.data);
        } else if (outputTensor.type == TensorType.uint8) {
          final outBytes = outputTensor.data;
          final params = outputTensor.params;
          outputFloats = Float32List(outBytes.length);
          for (int i = 0; i < outBytes.length; i++) {
            outputFloats[i] = (outBytes[i] - params.zeroPoint) * params.scale;
          }
        } else if (outputTensor.type == TensorType.int8) {
          final outBytes = outputTensor.data;
          final int8Data = outBytes.buffer.asInt8List(outBytes.offsetInBytes, outBytes.lengthInBytes);
          final params = outputTensor.params;
          outputFloats = Float32List(int8Data.length);
          for (int i = 0; i < int8Data.length; i++) {
            outputFloats[i] = (int8Data[i] - params.zeroPoint) * params.scale;
          }
        } else {
          final outBytes = outputTensor.data;
          outputFloats = outBytes.buffer.asFloat32List(
            outBytes.offsetInBytes,
            outBytes.lengthInBytes ~/ 4,
          );
        }

        double openScore;
        double closedScore;

        if (architecture == ModelArchitecture.yoloDetector) {
          final int numCandidates = outputFloats.length ~/ 7;
          double maxConf0 = 0.0;
          double maxConf1 = 0.0;
          int detectedBoxes = 0;

          for (int i = 0; i < numCandidates; i++) {
            final int base = i * 7;
            final double objConf = outputFloats[base + 4];
            if (objConf < 0.20) continue;

            final double c0 = outputFloats[base + 5];
            final double c1 = outputFloats[base + 6];
            final double s0 = objConf * c0;
            final double s1 = objConf * c1;

            if (s0 > maxConf0) maxConf0 = s0;
            if (s1 > maxConf1) maxConf1 = s1;
            detectedBoxes++;
          }

          if (detectedBoxes == 0) {
            openScore = 0.0;
            closedScore = 0.0;
          } else if (initRequest.invertYoloClasses) {
            openScore = maxConf0;
            closedScore = maxConf1;
          } else {
            closedScore = maxConf0;
            openScore = maxConf1;
          }
        } else {
          openScore = outputFloats.isNotEmpty ? outputFloats[0] : 0.0;
          closedScore = outputFloats.length > 1 ? outputFloats[1] : 0.0;
        }

        sw.stop();

        initRequest.mainSendPort.send(
          _WorkerInferenceResponse(
            requestId: message.requestId,
            openScore: openScore,
            closedScore: closedScore,
            elapsedMicroseconds: sw.elapsedMicroseconds,
            timestamp: message.timestamp,
          ),
        );
      } catch (e) {
        initRequest.mainSendPort.send(
          _WorkerInferenceResponse(
            requestId: message.requestId,
            openScore: 0.0,
            closedScore: 0.0,
            elapsedMicroseconds: 0,
            timestamp: message.timestamp,
            error: e.toString(),
          ),
        );
      }
    } else if (message is _WorkerDisposeRequest) {
      try {
        interpreter.close();
      } catch (_) {}
      workerReceivePort.close();
      break;
    }
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
