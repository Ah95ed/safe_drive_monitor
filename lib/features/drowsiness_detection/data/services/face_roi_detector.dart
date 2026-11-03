import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Contract for face and eye region of interest (ROI) detection.
abstract class FaceRoiDetector {
  Future<FaceRoiResult?> detect(CameraImage image, int sensorRotation);
  Future<void> dispose();
}

/// Structured outcome of a face and eye ROI detection pass.
class FaceRoiResult {
  final int x;
  final int y;
  final int width;
  final int height;
  final double? leftEyeOpenProb;
  final double? rightEyeOpenProb;
  final double? headEulerAngleY;
  final int? trackingId;
  final DateTime detectedAt;

  const FaceRoiResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.leftEyeOpenProb,
    this.rightEyeOpenProb,
    this.headEulerAngleY,
    this.trackingId,
    required this.detectedAt,
  });

  /// Computes the average eye open probability if at least one eye probability is present.
  double? get averageEyeOpenProbability {
    if (leftEyeOpenProb != null && rightEyeOpenProb != null) {
      return (leftEyeOpenProb! + rightEyeOpenProb!) / 2.0;
    }
    return leftEyeOpenProb ?? rightEyeOpenProb;
  }
}

/// Offline Bundled Google ML Kit implementation for Face & Eye ROI detection.
/// Strictly serves as an ROI provider and secondary signal. TFLite is the primary decision-maker.
class MlKitFaceRoiDetector implements FaceRoiDetector {
  static const String _tag = 'MlKitFaceRoiDetector';

  final FaceDetector _faceDetector;
  Uint8List? _nv21Buffer;

  // Smoothing state for ROI coordinates (EMA factor 0.6)
  FaceRoiResult? _lastResult;
  int? _lastTrackingId;

  MlKitFaceRoiDetector({FaceDetector? detector})
      : _faceDetector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                performanceMode: FaceDetectorMode.fast,
                enableClassification: true,
                enableLandmarks: true,
                enableContours: false,
                enableTracking: true,
                minFaceSize: 0.15,
              ),
            );

  @override
  Future<FaceRoiResult?> detect(CameraImage image, int sensorRotation) async {
    try {
      final inputImage = _convertCameraImageToInputImage(image, sensorRotation);
      if (inputImage == null) {
        return null;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return null;
      }

      // Pick the primary face (largest bounding box or matching current trackingId)
      Face? primaryFace;
      if (_lastTrackingId != null) {
        for (final face in faces) {
          if (face.trackingId == _lastTrackingId) {
            primaryFace = face;
            break;
          }
        }
      }
      primaryFace ??= faces.reduce((a, b) =>
          (a.boundingBox.width * a.boundingBox.height) >
                  (b.boundingBox.width * b.boundingBox.height)
              ? a
              : b);

      final now = DateTime.now();
      final rawResult = computeSquareEyeRoi(
        face: primaryFace,
        frameWidth: image.width,
        frameHeight: image.height,
        sensorRotation: sensorRotation,
        detectedAt: now,
      );

      // Apply Exponential Moving Average (EMA) smoothing if tracking same face
      FaceRoiResult finalResult = rawResult;
      if (_lastResult != null &&
          rawResult.trackingId != null &&
          rawResult.trackingId == _lastTrackingId) {
        final smoothedX =
            (0.6 * rawResult.x + 0.4 * _lastResult!.x).round();
        final smoothedY =
            (0.6 * rawResult.y + 0.4 * _lastResult!.y).round();
        final smoothedW =
            (0.6 * rawResult.width + 0.4 * _lastResult!.width).round();
        final smoothedH =
            (0.6 * rawResult.height + 0.4 * _lastResult!.height).round();

        finalResult = FaceRoiResult(
          x: smoothedX,
          y: smoothedY,
          width: smoothedW,
          height: smoothedH,
          leftEyeOpenProb: rawResult.leftEyeOpenProb,
          rightEyeOpenProb: rawResult.rightEyeOpenProb,
          headEulerAngleY: rawResult.headEulerAngleY,
          trackingId: rawResult.trackingId,
          detectedAt: now,
        );
      }

      _lastResult = finalResult;
      _lastTrackingId = finalResult.trackingId;
      return finalResult;
    } catch (e, st) {
      AppLogger.warning(_tag, 'Face ROI detection failed: $e\n$st');
      return null;
    }
  }

  /// Calculates a square eye-band ROI from ML Kit face landmarks or face bounds, clamped within the frame.
  static FaceRoiResult computeSquareEyeRoi({
    required Face face,
    required int frameWidth,
    required int frameHeight,
    required int sensorRotation,
    required DateTime detectedAt,
  }) {
    final Point<int>? leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final Point<int>? rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    return computeSquareEyeRoiFromComponents(
      leftEye: leftEye,
      rightEye: rightEye,
      boundingBox: face.boundingBox,
      leftEyeOpenProb: face.leftEyeOpenProbability,
      rightEyeOpenProb: face.rightEyeOpenProbability,
      headEulerAngleY: face.headEulerAngleY,
      trackingId: face.trackingId,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      sensorRotation: sensorRotation,
      detectedAt: detectedAt,
    );
  }

  /// Calculates a square eye-band ROI from discrete components for pure, testable geometry.
  static FaceRoiResult computeSquareEyeRoiFromComponents({
    Point<int>? leftEye,
    Point<int>? rightEye,
    required Rect boundingBox,
    double? leftEyeOpenProb,
    double? rightEyeOpenProb,
    double? headEulerAngleY,
    int? trackingId,
    required int frameWidth,
    required int frameHeight,
    required int sensorRotation,
    required DateTime detectedAt,
  }) {
    double centerX;
    double centerY;
    double rawWidth;
    double rawHeight;

    if (leftEye != null && rightEye != null) {
      final double minX = min(leftEye.x, rightEye.x).toDouble();
      final double maxX = max(leftEye.x, rightEye.x).toDouble();
      final double minY = min(leftEye.y, rightEye.y).toDouble();
      final double maxY = max(leftEye.y, rightEye.y).toDouble();

      final double interOcularDist = max(16.0, maxX - minX);
      final double eyeVerticalDist = max(12.0, maxY - minY);

      // Expand 60% horizontally, 120% vertically per Section A1.4
      rawWidth = interOcularDist * 1.60;
      rawHeight = max(interOcularDist * 1.10, eyeVerticalDist * 2.20);
      centerX = (minX + maxX) / 2.0;
      centerY = (minY + maxY) / 2.0;
    } else {
      // Fallback from bounding box upper 40% (eye band)
      rawWidth = boundingBox.width * 0.90;
      rawHeight = boundingBox.height * 0.45;
      centerX = boundingBox.left + (boundingBox.width / 2.0);
      centerY = boundingBox.top + (boundingBox.height * 0.35);
    }

    // Make the ROI square for uniform aspect-ratio input to TFLite
    int side = max(rawWidth, rawHeight).round();

    // Clamp side to maximum available dimension
    side = min(side, min(frameWidth, frameHeight));
    if (side <= 0) side = 64;

    int x = (centerX - (side / 2.0)).round();
    int y = (centerY - (side / 2.0)).round();

    // Clamp coordinates within frame boundaries
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + side > frameWidth) {
      x = frameWidth - side;
    }
    if (y + side > frameHeight) {
      y = frameHeight - side;
    }
    if (x < 0) x = 0;
    if (y < 0) y = 0;

    return FaceRoiResult(
      x: x,
      y: y,
      width: side,
      height: side,
      leftEyeOpenProb: leftEyeOpenProb,
      rightEyeOpenProb: rightEyeOpenProb,
      headEulerAngleY: headEulerAngleY,
      trackingId: trackingId,
      detectedAt: detectedAt,
    );
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image, int sensorRotation) {
    final rotation = _getImageRotation(sensorRotation);

    if (image.format.group == ImageFormatGroup.bgra8888) {
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
      final Uint8List nv21Bytes = _getYuv420Nv21Bytes(image);
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

  Uint8List _getYuv420Nv21Bytes(CameraImage image) {
    if (image.planes.length == 1) {
      return image.planes[0].bytes;
    }

    final int width = image.width;
    final int height = image.height;
    final int requiredSize = width * height + (width * (height ~/ 2));

    if (_nv21Buffer == null || _nv21Buffer!.length != requiredSize) {
      _nv21Buffer = Uint8List(requiredSize);
    }

    return _convertYuv420ToNv21(image, _nv21Buffer!);
  }

  static Uint8List _convertYuv420ToNv21(CameraImage image, Uint8List targetBuffer) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    final int yRowStride = yPlane.bytesPerRow;

    int nvIndex = 0;
    for (int y = 0; y < height; y++) {
      final int yRowStart = y * yRowStride;
      for (int x = 0; x < width; x++) {
        targetBuffer[nvIndex++] = yBytes[yRowStart + x];
      }
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    if (image.planes.length >= 3) {
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;
      final int uRowStride = uPlane.bytesPerRow;
      final int vRowStride = vPlane.bytesPerRow;
      final int uPixelStride = uPlane.bytesPerPixel ?? 1;
      final int vPixelStride = vPlane.bytesPerPixel ?? 1;

      for (int y = 0; y < uvHeight; y++) {
        final int uRowStart = y * uRowStride;
        final int vRowStart = y * vRowStride;
        for (int x = 0; x < uvWidth; x++) {
          targetBuffer[nvIndex++] = vBytes[vRowStart + (x * vPixelStride)];
          targetBuffer[nvIndex++] = uBytes[uRowStart + (x * uPixelStride)];
        }
      }
    } else if (image.planes.length == 2) {
      // Biplanar NV12 / iOS YUV420
      final Plane uvPlane = image.planes[1];
      final Uint8List uvBytes = uvPlane.bytes;
      final int uvRowStride = uvPlane.bytesPerRow;
      final int uvPixelStride = uvPlane.bytesPerPixel ?? 2;

      for (int y = 0; y < uvHeight; y++) {
        final int rowStart = y * uvRowStride;
        for (int x = 0; x < uvWidth; x++) {
          final int base = rowStart + (x * uvPixelStride);
          targetBuffer[nvIndex++] = uvBytes[base + 1]; // V
          targetBuffer[nvIndex++] = uvBytes[base];     // U
        }
      }
    }

    return targetBuffer;
  }

  InputImageRotation _getImageRotation(int sensorRotation) {
    switch (sensorRotation) {
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
    _nv21Buffer = null;
    _lastResult = null;
    _lastTrackingId = null;
    await _faceDetector.close();
  }
}
