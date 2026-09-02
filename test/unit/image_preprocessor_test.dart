import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/image_preprocessor.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';

void main() {
  group('ImagePreprocessor Unit Tests', () {
    late ImagePreprocessor preprocessor;

    setUp(() {
      preprocessor = ImagePreprocessor();
    });

    test('Output buffer size matches exactly 320x320x3 (307200 floats)', () {
      final img.Image testImage = img.Image(width: 320, height: 320);
      final Float32List result = preprocessor.processImageToFloat32(testImage);

      expect(result.length, equals(ModelConstants.totalInputFloats));
      expect(result.length, equals(320 * 320 * 3));
    });

    test('Float32 Normalization maps [0, 255] to [-1.0, 0.9921875]', () {
      final img.Image testImage = img.Image(width: 320, height: 320);
      // Pixel (0, 0): R=0, G=128, B=255
      testImage.setPixelRgb(0, 0, 0, 128, 255);

      final Float32List result = preprocessor.processImageToFloat32(
        testImage,
        layout: TensorChannelLayout.interleavedRgb,
      );

      // (0 - 128) / 128.0 = -1.0
      expect(result[0], closeTo(-1.0, 0.001));
      // (128 - 128) / 128.0 = 0.0
      expect(result[1], closeTo(0.0, 0.001));
      // (255 - 128) / 128.0 = 0.9921875
      expect(result[2], closeTo(0.9921875, 0.001));
    });

    test('Planar RGB layout stores all R, then all G, then all B sequentially', () {
      final img.Image testImage = img.Image(width: 320, height: 320);
      // Set pixel at (0, 0)
      testImage.setPixelRgb(0, 0, 200, 100, 50);
      // Set pixel at (1, 0)
      testImage.setPixelRgb(1, 0, 180, 90, 40);

      final Float32List result = preprocessor.processImageToFloat32(
        testImage,
        layout: TensorChannelLayout.planarRgb,
      );

      const int planeSize = 320 * 320; // 102400

      // Pixel (0,0)
      // Planar R at index 0: (200 - 128) / 128.0 = 0.5625
      expect(result[0], closeTo(0.5625, 0.001));
      // Planar G at index 102400: (100 - 128) / 128.0 = -0.21875
      expect(result[planeSize], closeTo(-0.21875, 0.001));
      // Planar B at index 204800: (50 - 128) / 128.0 = -0.609375
      expect(result[2 * planeSize], closeTo(-0.609375, 0.001));

      // Pixel (1,0) at index 1
      expect(result[1], closeTo((180 - 128) / 128.0, 0.001));
      expect(result[planeSize + 1], closeTo((90 - 128) / 128.0, 0.001));
      expect(result[2 * planeSize + 1], closeTo((40 - 128) / 128.0, 0.001));
    });

    test('Interleaved RGB layout stores R, G, B triplets sequentially', () {
      final img.Image testImage = img.Image(width: 320, height: 320);
      testImage.setPixelRgb(0, 0, 200, 100, 50);

      final Float32List result = preprocessor.processImageToFloat32(
        testImage,
        layout: TensorChannelLayout.interleavedRgb,
      );

      expect(result[0], closeTo((200 - 128) / 128.0, 0.001));
      expect(result[1], closeTo((100 - 128) / 128.0, 0.001));
      expect(result[2], closeTo((50 - 128) / 128.0, 0.001));
    });

    test('Center Crop properly extracts center 320x320 from larger camera frame', () {
      // 640x480 image
      final img.Image largeImage = img.Image(width: 640, height: 480);
      // Center of 640x480 is x=[(640-320)/2 = 160], y=[(480-320)/2 = 80]
      // Mark center pixel at (160, 80) with unique color R=255, G=0, B=0
      largeImage.setPixelRgb(160, 80, 255, 0, 0);

      final Float32List result = preprocessor.processImageToFloat32(
        largeImage,
        layout: TensorChannelLayout.interleavedRgb,
      );

      // (0, 0) of cropped result should correspond to (160, 80) of original
      expect(result[0], closeTo((255 - 128) / 128.0, 0.001));
      expect(result[1], closeTo((0 - 128) / 128.0, 0.001));
      expect(result[2], closeTo((0 - 128) / 128.0, 0.001));
    });
  });
}
