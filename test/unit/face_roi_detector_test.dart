import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/face_roi_detector.dart';

void main() {
  group('FaceRoiDetector & Square Eye ROI Geometry Unit Tests', () {
    test('Landmark-based ROI expands 60% horizontally and 120% vertically and is square', () {
      final leftEye = const Point<int>(100, 150);
      final rightEye = const Point<int>(150, 150);
      // Inter-ocular distance = 50px
      // eyeVerticalDist = 12px (min floor)
      // rawWidth = 50 * 1.6 = 80px
      // rawHeight = max(50 * 1.1, 12 * 2.2) = 55px
      // Square side = max(80, 55) = 80px
      // Center = (125, 150)
      // x = 125 - 40 = 85
      // y = 150 - 40 = 110

      final roi = MlKitFaceRoiDetector.computeSquareEyeRoiFromComponents(
        leftEye: leftEye,
        rightEye: rightEye,
        boundingBox: const Rect.fromLTWH(80, 100, 90, 120),
        frameWidth: 480,
        frameHeight: 640,
        sensorRotation: 270,
        detectedAt: DateTime.now(),
      );

      expect(roi.width, equals(roi.height), reason: 'ROI must be perfectly square');
      expect(roi.width, equals(80));
      expect(roi.x, equals(85));
      expect(roi.y, equals(110));
    });

    test('Fallback bounding box computes square upper-face eye band when landmarks are absent', () {
      final boundingBox = const Rect.fromLTWH(100, 100, 200, 200);
      // rawWidth = 200 * 0.9 = 180
      // rawHeight = 200 * 0.45 = 90
      // side = 180
      // centerX = 100 + 100 = 200
      // centerY = 100 + 70 = 170
      // x = 200 - 90 = 110
      // y = 170 - 90 = 80

      final roi = MlKitFaceRoiDetector.computeSquareEyeRoiFromComponents(
        leftEye: null,
        rightEye: null,
        boundingBox: boundingBox,
        frameWidth: 480,
        frameHeight: 640,
        sensorRotation: 270,
        detectedAt: DateTime.now(),
      );

      expect(roi.width, equals(roi.height));
      expect(roi.width, equals(180));
      expect(roi.x, equals(110));
      expect(roi.y, equals(80));
    });

    test('Clamps coordinates strictly within frame boundaries when face is near edges', () {
      // Face at top-left edge
      final roiTopLeft = MlKitFaceRoiDetector.computeSquareEyeRoiFromComponents(
        leftEye: const Point<int>(10, 15),
        rightEye: const Point<int>(30, 15),
        boundingBox: const Rect.fromLTWH(0, 0, 50, 60),
        frameWidth: 480,
        frameHeight: 640,
        sensorRotation: 0,
        detectedAt: DateTime.now(),
      );

      expect(roiTopLeft.x, greaterThanOrEqualTo(0));
      expect(roiTopLeft.y, greaterThanOrEqualTo(0));
      expect(roiTopLeft.x + roiTopLeft.width, lessThanOrEqualTo(480));
      expect(roiTopLeft.y + roiTopLeft.height, lessThanOrEqualTo(640));

      // Face at bottom-right edge
      final roiBottomRight = MlKitFaceRoiDetector.computeSquareEyeRoiFromComponents(
        leftEye: const Point<int>(450, 620),
        rightEye: const Point<int>(475, 620),
        boundingBox: const Rect.fromLTWH(440, 600, 40, 40),
        frameWidth: 480,
        frameHeight: 640,
        sensorRotation: 0,
        detectedAt: DateTime.now(),
      );

      expect(roiBottomRight.x, greaterThanOrEqualTo(0));
      expect(roiBottomRight.y, greaterThanOrEqualTo(0));
      expect(roiBottomRight.x + roiBottomRight.width, lessThanOrEqualTo(480));
      expect(roiBottomRight.y + roiBottomRight.height, lessThanOrEqualTo(640));
    });

    test('Average eye open probability computation handles single or both eyes', () {
      final roiBoth = FaceRoiResult(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        leftEyeOpenProb: 0.8,
        rightEyeOpenProb: 0.6,
        detectedAt: DateTime.now(),
      );
      expect(roiBoth.averageEyeOpenProbability, closeTo(0.70, 0.001));

      final roiLeftOnly = FaceRoiResult(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        leftEyeOpenProb: 0.85,
        detectedAt: DateTime.now(),
      );
      expect(roiLeftOnly.averageEyeOpenProbability, closeTo(0.85, 0.001));

      final roiNone = FaceRoiResult(
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        detectedAt: DateTime.now(),
      );
      expect(roiNone.averageEyeOpenProbability, isNull);
    });
  });
}
