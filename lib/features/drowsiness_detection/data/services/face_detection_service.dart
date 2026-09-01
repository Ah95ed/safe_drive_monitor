import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';

abstract class FaceDetectionService {
  Future<List<DriverFace>> detectFaces(
    CameraImage image, {
    int sensorRotation = 0,
  });
  Future<void> dispose();
}

class MlKitFaceDetectionService implements FaceDetectionService {
  static const String _tag = 'MlKitFaceDetection';

  final FaceDetector _faceDetector;

  // Throttled diagnostics: log the detection outcome at most ~once per second so
  // "no face detected" problems are visible on-device without per-frame spam.
  DateTime _lastDiagLog = DateTime.fromMillisecondsSinceEpoch(0);
  int _framesSinceDiag = 0;
  int _facesSinceDiag = 0;

  MlKitFaceDetectionService({FaceDetector? detector})
    : _faceDetector =
          detector ??
          FaceDetector(
            options: FaceDetectorOptions(
              enableLandmarks: true,
              enableClassification: true,
              enableTracking: true,
              performanceMode: FaceDetectorMode.fast,
              minFaceSize: 0.12,
            ),
          );

  @override
  Future<List<DriverFace>> detectFaces(
    CameraImage image, {
    int sensorRotation = 0,
  }) async {
    try {
      final inputImage = _convertCameraImageToInputImage(image, sensorRotation);
      if (inputImage == null) {
        AppLogger.warning(_tag, 'Could not convert CameraImage to InputImage');
        return const [];
      }

      final faces = await _faceDetector.processImage(inputImage);
      final now = DateTime.now();

      _logDiagnostics(now, image, sensorRotation, faces.length);

      return faces.map((face) {
        Point<int>? leftEye;
        Point<int>? rightEye;

        final leftLandmark = face.landmarks[FaceLandmarkType.leftEye];
        if (leftLandmark != null) {
          leftEye = Point(leftLandmark.position.x, leftLandmark.position.y);
        }

        final rightLandmark = face.landmarks[FaceLandmarkType.rightEye];
        if (rightLandmark != null) {
          rightEye = Point(rightLandmark.position.x, rightLandmark.position.y);
        }

        final rect = face.boundingBox;

        // Compute initial eye ROI from landmarks or upper face bounds
        Rect eyeRoi;
        if (leftEye != null && rightEye != null) {
          final minX = min(leftEye.x, rightEye.x).toDouble();
          final maxX = max(leftEye.x, rightEye.x).toDouble();
          final minY = min(leftEye.y, rightEye.y).toDouble();
          final maxY = max(leftEye.y, rightEye.y).toDouble();

          final eyeWidth = (maxX - minX);
          final eyeHeight = max(16.0, (maxY - minY));

          final padX = eyeWidth * 0.40;
          final padY = max(eyeWidth * 0.35, eyeHeight * 1.2);

          eyeRoi = Rect.fromLTRB(
            minX - padX,
            minY - padY,
            maxX + padX,
            maxY + padY,
          );
        } else {
          eyeRoi = Rect.fromLTRB(
            rect.left,
            rect.top + rect.height * 0.18,
            rect.right,
            rect.top + rect.height * 0.55,
          );
        }

        return DriverFace(
          trackingId: face.trackingId,
          boundingBox: rect,
          eyeRoi: eyeRoi,
          leftEye: leftEye,
          rightEye: rightEye,
          headEulerAngleX: face.headEulerAngleX,
          headEulerAngleY: face.headEulerAngleY,
          headEulerAngleZ: face.headEulerAngleZ,
          leftEyeOpenProbability: face.leftEyeOpenProbability,
          rightEyeOpenProbability: face.rightEyeOpenProbability,
          detectedAt: now,
        );
      }).toList();
    } on MissingPluginException {
      AppLogger.warning(
        _tag,
        'ML Kit Face Detection Native Plugin is not compiled into the running binary. Stop the app and run "flutter run" to compile the new native dependency.',
      );
      return const [];
    } catch (e, st) {
      AppLogger.error(_tag, 'Face detection error', e, st);
      return const [];
    }
  }

  void _logDiagnostics(
    DateTime now,
    CameraImage image,
    int sensorRotation,
    int faceCount,
  ) {
    if (!kDebugMode) return;
    _framesSinceDiag++;
    _facesSinceDiag += faceCount;
    if (now.difference(_lastDiagLog) < const Duration(seconds: 1)) return;

    AppLogger.debug(
      _tag,
      'face-detect: frames=$_framesSinceDiag faces(sum)=$_facesSinceDiag '
      'last=$faceCount fmt=${image.format.group.name} '
      '${image.width}x${image.height} planes=${image.planes.length} '
      'rot=$sensorRotation',
    );
    _lastDiagLog = now;
    _framesSinceDiag = 0;
    _facesSinceDiag = 0;
  }

  InputImage? _convertCameraImageToInputImage(
    CameraImage image,
    int sensorRotation,
  ) {
    final rotation = _mapRotation(sensorRotation);

    if (image.format.group == ImageFormatGroup.bgra8888) {
      // iOS / BGRA
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // Android YUV420 / NV21: Convert 3-plane YUV to standard NV21 for ML Kit
      final Uint8List nv21Bytes = _convertYuv420ToNv21(image);

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }
  }

  /// Converts Android 3-plane YUV_420_888 to standard single-buffer NV21 format.
  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    // If single plane is already NV21
    if (image.planes.length == 1) {
      return image.planes[0].bytes;
    }

    final int ySize = width * height;
    final int uvSize = width * (height ~/ 2);
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;

    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    // 1. Copy Y Plane row by row (accounting for row stride padding)
    int nvIndex = 0;
    for (int y = 0; y < height; y++) {
      final int yRowStart = y * yRowStride;
      for (int x = 0; x < width; x++) {
        nv21[nvIndex++] = yBytes[yRowStart + x];
      }
    }

    // 2. Interleave V and U bytes (NV21 expects V then U)
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    for (int y = 0; y < uvHeight; y++) {
      final int uRowStart = y * uRowStride;
      final int vRowStart = y * vRowStride;
      for (int x = 0; x < uvWidth; x++) {
        final int uIndex = uRowStart + (x * uPixelStride);
        final int vIndex = vRowStart + (x * vPixelStride);

        // NV21 = Y... V0 U0 V1 U1...
        nv21[nvIndex++] = vBytes[vIndex];
        nv21[nvIndex++] = uBytes[uIndex];
      }
    }

    return nv21;
  }

  InputImageRotation _mapRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _faceDetector.close();
      AppLogger.info(_tag, 'ML Kit Face Detector disposed.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error disposing Face Detector', e, st);
    }
  }
}
