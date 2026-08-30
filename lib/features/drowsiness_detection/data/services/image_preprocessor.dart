import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';

/// Preprocesses camera frames for TensorFlow Lite inference.
class ImagePreprocessor {
  static const String _tag = 'ImagePreprocessor';

  final TensorChannelLayout channelLayout;
  final DetectionPipeline pipeline;

  // Reusable Float32List buffer for model inputs (224 * 224 * 3 = 150,528 floats)
  final Float32List _inputBuffer =
      Float32List(ModelConstants.totalInputFloats);

  ImagePreprocessor({
    this.channelLayout = TensorChannelLayout.planarRgb,
    this.pipeline = DetectionPipeline.legacyCenterCrop,
  });

  /// Converts a [CameraImage] and fills the normalized Float32 input buffer.
  Float32List preprocessCameraImage(
    CameraImage cameraImage, {
    int sensorRotation = 0,
  }) {
    try {
      final img.Image rgbImage = convertCameraImageToRgb(cameraImage);
      return processImageToFloat32(
        rgbImage,
        sensorRotation: sensorRotation,
        layout: channelLayout,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to preprocess camera image', e, st);
      throw ImageConversionException('Image preprocessing failed', e);
    }
  }

  /// Direct method for processing an [img.Image] into normalized Float32List.
  /// Used for both camera frames and unit tests.
  Float32List processImageToFloat32(
    img.Image sourceImage, {
    int sensorRotation = 0,
    TensorChannelLayout? layout,
    Float32List? destinationBuffer,
  }) {
    final activeLayout = layout ?? channelLayout;
    final buffer = destinationBuffer ?? _inputBuffer;

    img.Image processed = sourceImage;

    // 1. Rotate according to sensor orientation if needed
    if (sensorRotation != 0) {
      processed = img.copyRotate(processed, angle: sensorRotation);
    }

    // 2. Crop to 224x224 with dynamic eye-level tracking
    if (processed.width != ModelConstants.inputWidth ||
        processed.height != ModelConstants.inputHeight) {
      if (processed.width >= ModelConstants.inputWidth &&
          processed.height >= ModelConstants.inputHeight) {
        int cropX = (processed.width - ModelConstants.inputWidth) ~/ 2;
        int cropY;

        if (pipeline == DetectionPipeline.faceAware) {
          // Dynamic Driver Eye-Zone Tracking (upper 38% region where eyes sit in driver cockpit)
          cropY = ((processed.height - ModelConstants.inputHeight) * 0.38).round();
          cropY = cropY.clamp(0, processed.height - ModelConstants.inputHeight);
        } else {
          // Legacy Center Crop (dead center)
          cropY = (processed.height - ModelConstants.inputHeight) ~/ 2;
        }

        processed = img.copyCrop(
          processed,
          x: cropX,
          y: cropY,
          width: ModelConstants.inputWidth,
          height: ModelConstants.inputHeight,
        );
      } else {
        // Resize to 224x224 if smaller
        processed = img.copyResize(
          processed,
          width: ModelConstants.inputWidth,
          height: ModelConstants.inputHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 3. Extract RGB and normalize into Float32 buffer
    final int width = ModelConstants.inputWidth;
    final int height = ModelConstants.inputHeight;
    final int planeSize = width * height; // 50,176

    const double mean = ModelConstants.imageMean;
    const double std = ModelConstants.imageStd;

    if (activeLayout == TensorChannelLayout.planarRgb) {
      // Planar RGB: All R pixels, then all G pixels, then all B pixels
      // [ R0, R1, ... R50175, G0, G1, ... G50175, B0, B1, ... B50175 ]
      int pixelIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = processed.getPixel(x, y);
          buffer[pixelIndex] = (pixel.r - mean) / std;
          buffer[planeSize + pixelIndex] = (pixel.g - mean) / std;
          buffer[2 * planeSize + pixelIndex] = (pixel.b - mean) / std;
          pixelIndex++;
        }
      }
    } else {
      // Interleaved RGB: R0, G0, B0, R1, G1, B1, ...
      int bufferIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = processed.getPixel(x, y);
          buffer[bufferIndex++] = (pixel.r - mean) / std;
          buffer[bufferIndex++] = (pixel.g - mean) / std;
          buffer[bufferIndex++] = (pixel.b - mean) / std;
        }
      }
    }

    return buffer;
  }

  /// Converts platform [CameraImage] (YUV420_888 / NV21 on Android or BGRA8888 on iOS) into RGB [img.Image].
  static img.Image convertCameraImageToRgb(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToImage(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888ToImage(image);
    } else if (image.format.group == ImageFormatGroup.nv21) {
      return _convertNV21ToImage(image);
    } else {
      // Fallback
      return _convertYUV420ToImage(image);
    }
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      final int uvRow = uvRowStride * (y >> 1);
      final int yRow = y * yRowStride;
      for (int x = 0; x < width; x++) {
        final int uvCol = (x >> 1) * uvPixelStride;
        final int uvIndex = uvRow + uvCol;

        final int yValue = yPlane.bytes[yRow + x] & 0xFF;
        final int uValue = uPlane.bytes[uvIndex] & 0xFF;
        final int vValue = vPlane.bytes[uvIndex] & 0xFF;

        final double yf = yValue.toDouble();
        final double uf = uValue.toDouble() - 128.0;
        final double vf = vValue.toDouble() - 128.0;

        final int r = (yf + 1.370705 * vf).round().clamp(0, 255);
        final int g =
            (yf - 0.337633 * uf - 0.698001 * vf).round().clamp(0, 255);
        final int b = (yf + 1.732446 * uf).round().clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgbImage;
  }

  static img.Image _convertNV21ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final Plane yPlane = image.planes[0];
    final Plane uvPlane = image.planes[1];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uvPlane.bytesPerRow;

    for (int y = 0; y < height; y++) {
      final int uvRow = uvRowStride * (y >> 1);
      final int yRow = y * yRowStride;
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvRow + (x & ~1);

        final int yValue = yPlane.bytes[yRow + x] & 0xFF;
        final int vValue = uvPlane.bytes[uvIndex] & 0xFF;
        final int uValue = uvPlane.bytes[uvIndex + 1] & 0xFF;

        final double yf = yValue.toDouble();
        final double uf = uValue.toDouble() - 128.0;
        final double vf = vValue.toDouble() - 128.0;

        final int r = (yf + 1.370705 * vf).round().clamp(0, 255);
        final int g =
            (yf - 0.337633 * uf - 0.698001 * vf).round().clamp(0, 255);
        final int b = (yf + 1.732446 * uf).round().clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgbImage;
  }

  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane plane = image.planes[0];
    final Uint8List bytes = plane.bytes;

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }
}
