import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DrowsinessDetector extends StatefulWidget {
  final CameraController camera;
  const DrowsinessDetector({super.key, required this.camera});

  @override
  State<DrowsinessDetector> createState() => _DrowsinessDetectorState();
}

class _DrowsinessDetectorState extends State<DrowsinessDetector> {
  Interpreter? _interpreter;
  late AudioPlayer _audioPlayer;
  bool _isModelLoaded = false;
  bool _isAlarmPlaying = false;
  bool _isProcessing = false;
  bool _isStreaming = false;
  String _prediction = 'جاري تحميل النموذج...';

  int _drowsyFrameCount = 0;
  final int _drowsyThreshold = 5;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadModel();
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
  }

  Future<void> _playAlarm() async {
    if (_isAlarmPlaying) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      await _audioPlayer.setVolume(1.0);
      setState(() {
        _isAlarmPlaying = true;
      });
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarmPlaying) return;
    try {
      await _audioPlayer.stop();
      setState(() {
        _isAlarmPlaying = false;
      });
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/eye_state_model_tensorFlow.tflite',
      );
      setState(() {
        _isModelLoaded = true;
        _prediction = 'جاري المراقبة...';
      });
      _startCameraMonitoring();
    } catch (e) {
      debugPrint('Error loading model: $e');
      setState(() {
        _prediction = 'خطأ في تحميل النموذج';
      });
    }
  }

  void _startCameraMonitoring() {
    if (!_isModelLoaded || _isStreaming) return;
    if (!widget.camera.value.isInitialized) return;

    _isStreaming = true;
    widget.camera.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      _runModelOnImage(image).whenComplete(() {
        _isProcessing = false;
      });
    });
  }

  Float32List _preprocessCameraImage(CameraImage image) {
    final img.Image convertedImage = _convertYUV420ToImage(image);
    final img.Image resizedImage = img.copyResize(
      convertedImage,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );
    return _imageToByteListFloat32(resizedImage, 224, 128, 128);
  }

  img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgData = img.Image(width: width, height: height);
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];
    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      final int uvRow = uvRowStride * (y >> 1);
      for (int x = 0; x < width; x++) {
        final int uvCol = (x >> 1) * uvPixelStride;
        final int yIndex = y * yRowStride + x;
        final int uvIndex = uvRow + uvCol;

        final int yValue = yPlane.bytes[yIndex] & 0xFF;
        final int uValue = uPlane.bytes[uvIndex] & 0xFF;
        final int vValue = vPlane.bytes[uvIndex] & 0xFF;

        final double yf = yValue.toDouble();
        final double uf = uValue.toDouble() - 128.0;
        final double vf = vValue.toDouble() - 128.0;

        int r = (yf + 1.370705 * vf).round();
        int g = (yf - 0.337633 * uf - 0.698001 * vf).round();
        int b = (yf + 1.732446 * uf).round();

        imgData.setPixelRgba(x, y, _clamp(r), _clamp(g), _clamp(b), 255);
      }
    }

    return imgData;
  }

  int _clamp(int value) {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value;
  }

  Future<void> _runModelOnImage(CameraImage image) async {
    if (_interpreter == null) return;

    try {
      final Float32List input = _preprocessCameraImage(image);
      final Float32List output = Float32List(2);
      _interpreter!.run(input, output);

      final double closedScore = output[0];
      final double openScore = output[1];
      final bool isEyesClosed = closedScore >= openScore;

      if (isEyesClosed) {
        _drowsyFrameCount++;
        if (_drowsyFrameCount > _drowsyThreshold) {
          await _playAlarm();
          if (mounted) {
            setState(() {
              _prediction = 'نعاس! استيقظ!';
            });
          }
        }
      } else {
        _drowsyFrameCount = 0;
        await _stopAlarm();
        if (mounted) {
          setState(() {
            _prediction = 'العينان مفتوحتان';
          });
        }
      }
    } catch (e) {
      debugPrint('Error running model: $e');
    }
  }

  Float32List _imageToByteListFloat32(
    img.Image image,
    int inputSize,
    double mean,
    double std,
  ) {
    final Float32List convertedBytes = Float32List(inputSize * inputSize * 3);
    int bufferIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        convertedBytes[bufferIndex++] = (pixel.r - mean) / std;
        convertedBytes[bufferIndex++] = (pixel.g - mean) / std;
        convertedBytes[bufferIndex++] = (pixel.b - mean) / std;
      }
    }

    return convertedBytes;
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _interpreter?.close();
    widget.camera.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف النعاس'),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(child: CameraPreview(widget.camera)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: _isAlarmPlaying
                ? Colors.red
                : Colors.black.withValues(alpha: 0.7),
            child: Text(
              _prediction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
