
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;

  CameraService._internal();

  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<void> initializeCamera() async {
    try {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          _controller = CameraController(
            _cameras![0], // استخدام الكاميرا الخلفية
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await _controller!.initialize();
        } else {
          throw Exception('لم يتم العثور على كاميرا');
        }
      } else {
        throw Exception('تم رفض إذن الكاميرا');
      }
    } catch (e) {
      throw Exception('خطأ في تهيئة الكاميرا: $e');
    }
  }

  CameraController? get controller => _controller;

  List<CameraDescription>? get cameras => _cameras;

  Future<void> startImageStream(CameraImageCallback onImage) async {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.startImageStream(onImage);
    }
  }

  Future<void> stopImageStream() async {
    if (_controller != null) {
      _controller!.stopImageStream();
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}

typedef CameraImageCallback = void Function(CameraImage image);
