// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/low_light_detector.dart';

CameraImage createSimulatedYPlaneImage({required int width, required int height, required int luminance}) {
  final yBytes = Uint8List(width * height);
  yBytes.fillRange(0, yBytes.length, luminance.clamp(0, 255));
  final uvLength = (width ~/ 2) * (height ~/ 2);
  final uBytes = Uint8List(uvLength)..fillRange(0, uvLength, 128);
  final vBytes = Uint8List(uvLength)..fillRange(0, uvLength, 128);

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
      lensAperture: 1.8,
      sensorExposureTime: 10000000,
      sensorSensitivity: 100.0,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LightingManager & Night Mode Tests', () {
    test('Calculates luminance correctly and classifies good lighting', () {
      final manager = LightingManager();
      final brightImage = createSimulatedYPlaneImage(width: 160, height: 160, luminance: 150);

      final state = manager.processCameraImage(brightImage);
      expect(state, equals(LightingState.good));
      expect(manager.isLowLight, isFalse);
      expect(manager.isCriticalDarkness, isFalse);
      expect(manager.currentLuminance, greaterThan(100.0));
    });

    test('Transitions to low lighting when luminance < 40', () {
      final manager = LightingManager();
      final dimImage = createSimulatedYPlaneImage(width: 160, height: 160, luminance: 30);

      // Feed multiple frames to let smoothing settle
      for (int i = 0; i < 15; i++) {
        manager.processCameraImage(dimImage);
      }

      expect(manager.isLowLight, isTrue);
      expect(manager.lightingState, equals(LightingState.low));
      expect(manager.isCriticalDarkness, isFalse);
    });

    test('Requires 3 consecutive seconds below 15 to transition to critical darkness', () {
      final manager = LightingManager();
      final darkImage = createSimulatedYPlaneImage(width: 160, height: 160, luminance: 5);

      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Process frame at t0 - smoothed luminance drops, but time is 0s
      for (int i = 0; i < 20; i++) {
        manager.processCameraImage(darkImage, t0);
      }
      expect(manager.isLowLight, isTrue);
      // Under 3 seconds, should still be low, not critical yet
      expect(manager.lightingState, equals(LightingState.low));
      expect(manager.isCriticalDarkness, isFalse);

      // Process at t0 + 2 seconds (still under 3s threshold)
      manager.processCameraImage(darkImage, t0.add(const Duration(seconds: 2)));
      expect(manager.lightingState, equals(LightingState.low));
      expect(manager.isCriticalDarkness, isFalse);

      // Process at t0 + 3.1 seconds (persisted >= 3 seconds)
      manager.processCameraImage(darkImage, t0.add(const Duration(milliseconds: 3100)));
      expect(manager.lightingState, equals(LightingState.critical));
      expect(manager.isCriticalDarkness, isTrue);

      // Light returns -> immediately resets
      final brightImage = createSimulatedYPlaneImage(width: 160, height: 160, luminance: 200);
      for (int i = 0; i < 25; i++) {
        manager.processCameraImage(brightImage, t0.add(const Duration(seconds: 4)));
      }
      expect(manager.isCriticalDarkness, isFalse);
      expect(manager.lightingState, equals(LightingState.good));
    });
  });

  group('Gamma Correction LUT & Shadow Lifting Tests', () {
    test('Gamma LUT lifts shadows without modifying bounds', () {
      final lut = ImagePreprocessor.gammaLut;
      expect(lut.length, equals(256));
      expect(lut[0], equals(0));
      expect(lut[255], equals(255));

      // For midtone shadow pixel 64: gamma 0.75 elevates it significantly
      expect(lut[64], greaterThan(64));
      // For pixel 32:
      expect(lut[32], greaterThan(32));
    });

    test('yuvRoiToNormalizedFloat32 applies gamma correction when enabled', () {
      final dimImage = createSimulatedYPlaneImage(width: 64, height: 64, luminance: 40);
      const roi = Rect.fromLTWH(0, 0, 64, 64);

      final normalBuffer = yuvRoiToNormalizedFloat32(
        image: dimImage,
        roi: roi,
        targetWidth: 32,
        targetHeight: 32,
        rotationDegrees: 0,
        isMirrored: false,
        normalization: ModelInputNormalization.zeroToOne,
        applyGammaCorrection: false,
      );

      final gammaBuffer = yuvRoiToNormalizedFloat32(
        image: dimImage,
        roi: roi,
        targetWidth: 32,
        targetHeight: 32,
        rotationDegrees: 0,
        isMirrored: false,
        normalization: ModelInputNormalization.zeroToOne,
        applyGammaCorrection: true,
      );

      expect(gammaBuffer.length, equals(normalBuffer.length));
      // Gamma corrected midtones should be strictly higher than non-gamma corrected
      expect(gammaBuffer[0], greaterThan(normalBuffer[0]));
    });
  });

  group('Degraded States Warning Messages', () {
    test('Returns exact Arabic warning messages for all degraded states', () {
      expect(
        DriverAlertState.noFaceDetected.warningMessage,
        equals('وجه السائق غير ظاهر — اضبط موضع الهاتف'),
      );
      expect(
        DriverAlertState.insufficientLight.warningMessage,
        equals('الإضاءة منخفضة جداً — شغل إضاءة المقصورة'),
      );
      expect(
        DriverAlertState.monitoringStalled.warningMessage,
        equals('توقف تحليل الكاميرا — أعد تشغيل التطبيق'),
      );
      expect(
        DriverAlertState.thermalThrottled.warningMessage,
        equals('حرارة الجهاز مرتفعة — تم تقليل معدل المعالجة'),
      );
      expect(
        DriverAlertState.normal.warningMessage,
        equals('منتبه'),
      );
    });
  });
}
