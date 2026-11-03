// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';

CameraImage createTestYuv420Image({
  int width = 480,
  int height = 640,
  int fillY = 160,
  int fillU = 110,
  int fillV = 140,
}) {
  final yBytes = Uint8List(width * height)..fillRange(0, width * height, fillY);
  final uvSize = (width ~/ 2) * (height ~/ 2);
  final uBytes = Uint8List(uvSize)..fillRange(0, uvSize, fillU);
  final vBytes = Uint8List(uvSize)..fillRange(0, uvSize, fillV);

  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
      planes: [
        CameraImagePlane(bytes: yBytes, bytesPerRow: width, bytesPerPixel: 1, width: width, height: height),
        CameraImagePlane(bytes: uBytes, bytesPerRow: width ~/ 2, bytesPerPixel: 1, width: width ~/ 2, height: height ~/ 2),
        CameraImagePlane(bytes: vBytes, bytesPerRow: width ~/ 2, bytesPerPixel: 1, width: width ~/ 2, height: height ~/ 2),
      ],
      width: width,
      height: height,
    ),
  );
}

CameraImage createTestBgraImage({
  int width = 480,
  int height = 640,
  int b = 100,
  int g = 150,
  int r = 200,
  int a = 255,
}) {
  final bytes = Uint8List(width * height * 4);
  for (int i = 0; i < width * height; i++) {
    final idx = i * 4;
    bytes[idx] = b;
    bytes[idx + 1] = g;
    bytes[idx + 2] = r;
    bytes[idx + 3] = a;
  }

  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1),
      planes: [
        CameraImagePlane(bytes: bytes, bytesPerRow: width * 4, bytesPerPixel: 4, width: width, height: height),
      ],
      width: width,
      height: height,
    ),
  );
}

void main() {
  group('Zero-Copy YUV ROI to Normalized Float32 (Section A2)', () {
    late ImagePreprocessor preprocessor;

    setUp(() {
      preprocessor = ImagePreprocessor();
      preprocessor.setInputDimensions(224, 224);
    });

    test('Parity check: single-pass yuvRoiToNormalizedFloat32 closely matches legacy full conversion', () {
      final image = createTestYuv420Image(width: 480, height: 640, fillY: 180, fillU: 120, fillV: 130);
      const roi = Rect.fromLTWH(100, 150, 224, 224);

      final fastResult = yuvRoiToNormalizedFloat32(
        image: image,
        roi: roi,
        targetWidth: 224,
        targetHeight: 224,
        rotationDegrees: 0,
        isMirrored: false,
        normalization: ModelInputNormalization.zeroToOne,
      );

      final legacyResult = preprocessor.preprocessCameraImageLegacy(
        image,
        sensorRotation: 0,
        isMirrored: false,
        dynamicRoi: roi,
      );

      expect(fastResult.length, equals(legacyResult.length));
      expect(fastResult.length, equals(224 * 224 * 3));

      // Compare pixel values: fixed-point integer YUV->RGB vs float conversion error is bounded within 0.05
      double maxDiff = 0.0;
      for (int i = 0; i < fastResult.length; i++) {
        final diff = (fastResult[i] - legacyResult[i]).abs();
        if (diff > maxDiff) maxDiff = diff;
      }

      expect(maxDiff, lessThanOrEqualTo(0.05),
          reason: 'Direct single-pass extraction must match legacy output within fixed-point rounding tolerance');
    });

    test('Direct single-pass execution on BGRA8888 frame extracts exact RGB channels', () {
      final bgraImage = createTestBgraImage(width: 480, height: 640, b: 51, g: 102, r: 204);
      const roi = Rect.fromLTWH(50, 50, 100, 100);

      final result = yuvRoiToNormalizedFloat32(
        image: bgraImage,
        roi: roi,
        targetWidth: 224,
        targetHeight: 224,
        rotationDegrees: 0,
        isMirrored: false,
        normalization: ModelInputNormalization.zeroToOne,
      );

      // In zeroToOne: R=204/255=0.8, G=102/255=0.4, B=51/255=0.2
      expect(result[0], closeTo(0.80, 0.01), reason: 'Channel 0 must be Red');
      expect(result[1], closeTo(0.40, 0.01), reason: 'Channel 1 must be Green');
      expect(result[2], closeTo(0.20, 0.01), reason: 'Channel 2 must be Blue');
    });

    test('Micro-benchmark: yuvRoiToNormalizedFloat32 executes in < 8ms', () {
      final image = createTestYuv420Image(width: 480, height: 640);
      const roi = Rect.fromLTWH(120, 180, 224, 224);
      final dest = Float32List(224 * 224 * 3);

      // Warm up
      for (int i = 0; i < 5; i++) {
        yuvRoiToNormalizedFloat32(
          image: image,
          roi: roi,
          targetWidth: 224,
          targetHeight: 224,
          rotationDegrees: 270,
          isMirrored: true,
          normalization: ModelInputNormalization.zeroToOne,
          destinationBuffer: dest,
        );
      }

      // Benchmark 20 iterations
      final sw = Stopwatch()..start();
      const iterations = 20;
      for (int i = 0; i < iterations; i++) {
        yuvRoiToNormalizedFloat32(
          image: image,
          roi: roi,
          targetWidth: 224,
          targetHeight: 224,
          rotationDegrees: 270,
          isMirrored: true,
          normalization: ModelInputNormalization.zeroToOne,
          destinationBuffer: dest,
        );
      }
      sw.stop();

      final avgMs = sw.elapsedMilliseconds / iterations;
      // In host VM testing, single-pass processing is extremely fast (< 8ms target per A2)
      expect(avgMs, lessThan(8.0), reason: 'Preprocessing must execute in < 8ms per frame');
    });

    test('Unsupported image format throws ImageConversionException', () {
      final invalidImage = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.unknown, raw: 999),
          planes: const [],
          width: 480,
          height: 640,
        ),
      );

      expect(
        () => yuvRoiToNormalizedFloat32(
          image: invalidImage,
          roi: const Rect.fromLTWH(0, 0, 100, 100),
          targetWidth: 224,
          targetHeight: 224,
          rotationDegrees: 0,
          isMirrored: false,
          normalization: ModelInputNormalization.zeroToOne,
        ),
        throwsA(isA<ImageConversionException>()),
      );
    });
  });
}
