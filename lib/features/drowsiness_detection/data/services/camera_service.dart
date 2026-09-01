import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

abstract class CameraService {
  CameraController? get controller;
  bool get isInitialized;
  bool get isStreaming;
  int get sensorOrientation;

  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.front,
  });
  Future<void> startImageStream(void Function(CameraImage image) onImage);
  Future<void> stopImageStream();
  Future<void> dispose();
}

class AppCameraService implements CameraService {
  static const String _tag = 'CameraService';

  CameraController? _controller;
  bool _isStreaming = false;
  int _sensorOrientation = 0;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  @override
  bool get isStreaming => _isStreaming;

  @override
  int get sensorOrientation => _sensorOrientation;

  @override
  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw const PermissionDeniedException('تم رفض إذن الوصول إلى الكاميرا');
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const CameraInitializationException('لم يتم العثور على أي كاميرا في الجهاز');
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == lensDirection,
        orElse: () => cameras.first,
      );

      _sensorOrientation = selectedCamera.sensorOrientation;

      final controller = CameraController(
        selectedCamera,
        AppConstants.defaultCameraResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      _controller = controller;

      AppLogger.info(
        _tag,
        'Camera initialized: ${selectedCamera.lensDirection.name}, rotation: $_sensorOrientation',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Camera initialization failed', e, st);
      if (e is AppException) rethrow;
      throw CameraInitializationException('خطأ في تهيئة الكاميرا', e);
    }
  }

  @override
  Future<void> startImageStream(void Function(CameraImage image) onImage) async {
    if (!isInitialized) {
      throw const CameraInitializationException('الكاميرا غير مهيأة لبدء البث');
    }
    if (_isStreaming || _controller!.value.isStreamingImages) return;

    try {
      _isStreaming = true;
      await _controller!.startImageStream(onImage);
      AppLogger.info(_tag, 'Camera image stream started.');
    } catch (e, st) {
      _isStreaming = false;
      AppLogger.error(_tag, 'Failed to start image stream', e, st);
      throw CameraInitializationException('فشل في بدء بث الكاميرا', e);
    }
  }

  @override
  Future<void> stopImageStream() async {
    _isStreaming = false;
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isStreamingImages) {
      try {
        await _controller!.stopImageStream();
        AppLogger.info(_tag, 'Camera image stream stopped.');
      } catch (e) {
        AppLogger.warning(_tag, 'Notice while stopping image stream: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stopImageStream();
      if (_controller != null) {
        // Allow in-flight platform channel frames to settle before tearing down.
        await Future.delayed(const Duration(milliseconds: 60));
        await _controller?.dispose();
        _controller = null;
      }
      AppLogger.info(_tag, 'Camera service disposed.');
    } catch (e) {
      AppLogger.error(_tag, 'Error disposing camera service', e);
    }
  }
}
