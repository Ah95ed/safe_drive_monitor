import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';

/// Preprocesses camera frames for TensorFlow Lite inference.
/// Includes direct zero-allocation ROI extraction from raw camera buffers (YUV420/NV21/BGRA)
/// as well as legacy image-based pipeline for debugging and compatibility testing.
class ImagePreprocessor {
  static const String _tag = 'ImagePreprocessor';

  TensorChannelLayout channelLayout;
  DetectionPipeline pipeline;
  RoiStrategy roiStrategy;
  bool useDirectFastPipeline;
  ModelInputNormalization normalization;

  int _inputWidth = ModelConstants.inputWidth;
  int _inputHeight = ModelConstants.inputHeight;

  // Reusable Float32List buffer for model inputs
  Float32List _inputBuffer =
      Float32List(ModelConstants.totalInputFloats);

  ImagePreprocessor({
    // A standard [1,224,224,3] or [1,320,320,3] TFLite tensor is channels-last (HWC), i.e.
    // interleaved RGB. Planar is only for byte-parity with the legacy Java path.
    this.channelLayout = TensorChannelLayout.interleavedRgb,
    this.pipeline = DetectionPipeline.legacyCenterCrop,
    this.roiStrategy = RoiStrategy.eyeBand,
    this.useDirectFastPipeline = true,
    this.normalization = ModelInputNormalization.zeroToOne,
  });

  void setInputDimensions(int width, int height) {
    if (_inputWidth != width || _inputHeight != height) {
      _inputWidth = width;
      _inputHeight = height;
      _inputBuffer = Float32List(_inputWidth * _inputHeight * 3);
    }
  }

  /// Converts a [CameraImage] and fills the normalized Float32 input buffer.
  /// Uses zero-allocation direct ROI sampling by default for maximum performance.
  Float32List preprocessCameraImage(
    CameraImage cameraImage, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
  }) {
    try {
      if (useDirectFastPipeline) {
        return preprocessCameraImageDirect(
          cameraImage,
          sensorRotation: sensorRotation,
          isMirrored: isMirrored,
          dynamicRoi: dynamicRoi,
          layout: channelLayout,
        );
      } else {
        return preprocessCameraImageLegacy(
          cameraImage,
          sensorRotation: sensorRotation,
          isMirrored: isMirrored,
          dynamicRoi: dynamicRoi,
        );
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to preprocess camera image', e, st);
      throw ImageConversionException('Image preprocessing failed', e);
    }
  }

  /// Zero-allocation direct ROI sub-sampling from [CameraImage] planes directly into the Float32 buffer.
  /// Handles YUV420_888, NV21, and BGRA8888 without creating intermediate full-frame images.
  Float32List preprocessCameraImageDirect(
    CameraImage cameraImage, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
    TensorChannelLayout? layout,
    Float32List? destinationBuffer,
  }) {
    final activeLayout = layout ?? channelLayout;
    final buffer = destinationBuffer ?? _inputBuffer;

    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;

    // Dimensions of the rotated coordinate space
    final bool isSwapped = sensorRotation == 90 || sensorRotation == 270;
    final int rotWidth = isSwapped ? srcHeight : srcWidth;
    final int rotHeight = isSwapped ? srcWidth : srcHeight;

    // 1. Determine target ROI in rotated coordinates
    double roiLeft;
    double roiTop;
    double roiWidth;
    double roiHeight;

    if (dynamicRoi != null && dynamicRoi.width > 10 && dynamicRoi.height > 10) {
      roiLeft = dynamicRoi.left.clamp(0.0, rotWidth - 1.0);
      roiTop = dynamicRoi.top.clamp(0.0, rotHeight - 1.0);
      roiWidth = dynamicRoi.width.clamp(1.0, rotWidth - roiLeft);
      roiHeight = dynamicRoi.height.clamp(1.0, rotHeight - roiTop);
    } else {
      // Fallback ROI based on pipeline
      if (rotWidth >= ModelConstants.inputWidth &&
          rotHeight >= ModelConstants.inputHeight) {
        roiWidth = ModelConstants.inputWidth.toDouble();
        roiHeight = ModelConstants.inputHeight.toDouble();
        roiLeft = ((rotWidth - ModelConstants.inputWidth) / 2.0);

        if (pipeline == DetectionPipeline.faceAware) {
          roiTop = ((rotHeight - ModelConstants.inputHeight) * 0.38)
              .clamp(0.0, (rotHeight - ModelConstants.inputHeight).toDouble());
        } else {
          roiTop = ((rotHeight - ModelConstants.inputHeight) / 2.0);
        }
      } else {
        roiLeft = 0.0;
        roiTop = 0.0;
        roiWidth = rotWidth.toDouble();
        roiHeight = rotHeight.toDouble();
      }
    }

    // 2. Direct Sub-sampling loop
    final int outWidth = _inputWidth;
    final int outHeight = _inputHeight;
    final int planeSize = outWidth * outHeight;

    final double stepX = roiWidth / outWidth;
    final double stepY = roiHeight / outHeight;

    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      _sampleBgraDirect(
        cameraImage,
        buffer,
        outWidth: outWidth,
        outHeight: outHeight,
        planeSize: planeSize,
        srcWidth: srcWidth,
        srcHeight: srcHeight,
        roiLeft: roiLeft,
        roiTop: roiTop,
        stepX: stepX,
        stepY: stepY,
        sensorRotation: sensorRotation,
        isMirrored: isMirrored,
        isPlanar: activeLayout == TensorChannelLayout.planarRgb,
        normalization: normalization,
      );
    } else {
      // YUV420_888 & NV21
      _sampleYuvDirect(
        cameraImage,
        buffer,
        outWidth: outWidth,
        outHeight: outHeight,
        planeSize: planeSize,
        srcWidth: srcWidth,
        srcHeight: srcHeight,
        roiLeft: roiLeft,
        roiTop: roiTop,
        stepX: stepX,
        stepY: stepY,
        sensorRotation: sensorRotation,
        isMirrored: isMirrored,
        isPlanar: activeLayout == TensorChannelLayout.planarRgb,
        normalization: normalization,
      );
    }

    return buffer;
  }

  static void _sampleYuvDirect(
    CameraImage cameraImage,
    Float32List buffer, {
    required int outWidth,
    required int outHeight,
    required int planeSize,
    required int srcWidth,
    required int srcHeight,
    required double roiLeft,
    required double roiTop,
    required double stepX,
    required double stepY,
    required int sensorRotation,
    required bool isMirrored,
    required bool isPlanar,
    required ModelInputNormalization normalization,
  }) {
    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    final bool isZeroToOne = normalization == ModelInputNormalization.zeroToOne;

    int pixelIndex = 0;

    for (int yOut = 0; yOut < outHeight; yOut++) {
      final double rotY = roiTop + (yOut * stepY);

      for (int xOut = 0; xOut < outWidth; xOut++) {
        final double rotX = isMirrored
            ? (roiLeft + (outWidth - 1 - xOut) * stepX)
            : (roiLeft + xOut * stepX);

        // Map (rotX, rotY) back to raw camera sensor space (srcX, srcY)
        int srcX;
        int srcY;

        switch (sensorRotation) {
          case 90:
            srcX = rotY.toInt().clamp(0, srcWidth - 1);
            srcY = (srcHeight - 1 - rotX.toInt()).clamp(0, srcHeight - 1);
            break;
          case 180:
            srcX = (srcWidth - 1 - rotX.toInt()).clamp(0, srcWidth - 1);
            srcY = (srcHeight - 1 - rotY.toInt()).clamp(0, srcHeight - 1);
            break;
          case 270:
            srcX = (srcWidth - 1 - rotY.toInt()).clamp(0, srcWidth - 1);
            srcY = rotX.toInt().clamp(0, srcHeight - 1);
            break;
          case 0:
          default:
            srcX = rotX.toInt().clamp(0, srcWidth - 1);
            srcY = rotY.toInt().clamp(0, srcHeight - 1);
            break;
        }

        // Direct YUV to RGB Conversion
        final int yIndex = srcY * yRowStride + srcX;
        final int uvX = srcX >> 1;
        final int uvY = srcY >> 1;
        final int uIndex = uvY * uRowStride + (uvX * uPixelStride);
        final int vIndex = uvY * uRowStride + (uvX * vPixelStride);

        final int yVal = yBytes[yIndex];
        final int uVal = uBytes[uIndex] - 128;
        final int vVal = vBytes[vIndex] - 128;

        // Fixed-point RGB conversion
        final int r = (yVal + ((1436 * vVal) >> 10)).clamp(0, 255);
        final int g = (yVal - ((352 * uVal + 731 * vVal) >> 10)).clamp(0, 255);
        final int b = (yVal + ((1814 * uVal) >> 10)).clamp(0, 255);

        // Normalize into buffer (zeroToOne for YOLO [0,1], minusOneToOne for TF [-1,1])
        final double normR = isZeroToOne ? (r / 255.0) : ((r - 128.0) / 128.0);
        final double normG = isZeroToOne ? (g / 255.0) : ((g - 128.0) / 128.0);
        final double normB = isZeroToOne ? (b / 255.0) : ((b - 128.0) / 128.0);

        if (isPlanar) {
          buffer[pixelIndex] = normR;
          buffer[planeSize + pixelIndex] = normG;
          buffer[2 * planeSize + pixelIndex] = normB;
        } else {
          final int idx = pixelIndex * 3;
          buffer[idx] = normR;
          buffer[idx + 1] = normG;
          buffer[idx + 2] = normB;
        }

        pixelIndex++;
      }
    }
  }

  static void _sampleBgraDirect(
    CameraImage cameraImage,
    Float32List buffer, {
    required int outWidth,
    required int outHeight,
    required int planeSize,
    required int srcWidth,
    required int srcHeight,
    required double roiLeft,
    required double roiTop,
    required double stepX,
    required double stepY,
    required int sensorRotation,
    required bool isMirrored,
    required bool isPlanar,
    required ModelInputNormalization normalization,
  }) {
    final Plane bgraPlane = cameraImage.planes[0];
    final Uint8List bytes = bgraPlane.bytes;
    final int rowStride = bgraPlane.bytesPerRow;

    final bool isZeroToOne = normalization == ModelInputNormalization.zeroToOne;

    int pixelIndex = 0;

    for (int yOut = 0; yOut < outHeight; yOut++) {
      final double rotY = roiTop + (yOut * stepY);

      for (int xOut = 0; xOut < outWidth; xOut++) {
        final double rotX = isMirrored
            ? (roiLeft + (outWidth - 1 - xOut) * stepX)
            : (roiLeft + xOut * stepX);

        int srcX;
        int srcY;

        switch (sensorRotation) {
          case 90:
            srcX = rotY.toInt().clamp(0, srcWidth - 1);
            srcY = (srcHeight - 1 - rotX.toInt()).clamp(0, srcHeight - 1);
            break;
          case 180:
            srcX = (srcWidth - 1 - rotX.toInt()).clamp(0, srcWidth - 1);
            srcY = (srcHeight - 1 - rotY.toInt()).clamp(0, srcHeight - 1);
            break;
          case 270:
            srcX = (srcWidth - 1 - rotY.toInt()).clamp(0, srcWidth - 1);
            srcY = rotX.toInt().clamp(0, srcHeight - 1);
            break;
          case 0:
          default:
            srcX = rotX.toInt().clamp(0, srcWidth - 1);
            srcY = rotY.toInt().clamp(0, srcHeight - 1);
            break;
        }

        final int byteIndex = (srcY * rowStride) + (srcX * 4);
        final int b = bytes[byteIndex];
        final int g = bytes[byteIndex + 1];
        final int r = bytes[byteIndex + 2];

        // Normalize (zeroToOne for YOLO [0,1], minusOneToOne for TF [-1,1])
        final double normR = isZeroToOne ? (r / 255.0) : ((r - 128.0) / 128.0);
        final double normG = isZeroToOne ? (g / 255.0) : ((g - 128.0) / 128.0);
        final double normB = isZeroToOne ? (b / 255.0) : ((b - 128.0) / 128.0);

        if (isPlanar) {
          buffer[pixelIndex] = normR;
          buffer[planeSize + pixelIndex] = normG;
          buffer[2 * planeSize + pixelIndex] = normB;
        } else {
          final int idx = pixelIndex * 3;
          buffer[idx] = normR;
          buffer[idx + 1] = normG;
          buffer[idx + 2] = normB;
        }

        pixelIndex++;
      }
    }
  }

  /// Legacy image-based conversion method for compatibility checks and test assertions.
  Float32List preprocessCameraImageLegacy(
    CameraImage cameraImage, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
  }) {
    final img.Image rgbImage = convertCameraImageToRgb(cameraImage);
    return processImageToFloat32(
      rgbImage,
      sensorRotation: sensorRotation,
      isMirrored: isMirrored,
      dynamicRoi: dynamicRoi,
      layout: channelLayout,
    );
  }

  /// Direct method for processing an [img.Image] into normalized Float32List.
  /// Used for both camera frames and golden unit tests.
  Float32List processImageToFloat32(
    img.Image sourceImage, {
    int sensorRotation = 0,
    bool isMirrored = false,
    Rect? dynamicRoi,
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

    // 2. Mirror if specified (e.g. front camera horizontal flip)
    if (isMirrored) {
      processed = img.copyFlip(processed, direction: img.FlipDirection.horizontal);
    }

    // 3. Extract ROI (either dynamic eye/face ROI or legacy center crop)
    if (dynamicRoi != null) {
      final int roiX = dynamicRoi.left.round().clamp(0, processed.width - 1);
      final int roiY = dynamicRoi.top.round().clamp(0, processed.height - 1);
      final int roiW = dynamicRoi.width.round().clamp(1, processed.width - roiX);
      final int roiH = dynamicRoi.height.round().clamp(1, processed.height - roiY);

      if (roiW > 10 && roiH > 10) {
        processed = img.copyCrop(
          processed,
          x: roiX,
          y: roiY,
          width: roiW,
          height: roiH,
        );
        processed = img.copyResize(
          processed,
          width: ModelConstants.inputWidth,
          height: ModelConstants.inputHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    } else if (processed.width != ModelConstants.inputWidth ||
        processed.height != ModelConstants.inputHeight) {
      if (processed.width >= ModelConstants.inputWidth &&
          processed.height >= ModelConstants.inputHeight) {
        int cropX = (processed.width - ModelConstants.inputWidth) ~/ 2;
        int cropY;

        if (pipeline == DetectionPipeline.faceAware) {
          cropY = ((processed.height - ModelConstants.inputHeight) * 0.38).round();
          cropY = cropY.clamp(0, processed.height - ModelConstants.inputHeight);
        } else {
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
        processed = img.copyResize(
          processed,
          width: ModelConstants.inputWidth,
          height: ModelConstants.inputHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 4. Extract RGB and normalize into Float32 buffer
    final int width = _inputWidth;
    final int height = _inputHeight;
    final int planeSize = width * height;

    const double mean = ModelConstants.imageMean;
    const double std = ModelConstants.imageStd;
    final bool isZeroToOne = normalization == ModelInputNormalization.zeroToOne;

    if (activeLayout == TensorChannelLayout.planarRgb) {
      int pixelIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = processed.getPixel(x, y);
          final double r = isZeroToOne ? (pixel.r / 255.0) : ((pixel.r - mean) / std);
          final double g = isZeroToOne ? (pixel.g / 255.0) : ((pixel.g - mean) / std);
          final double b = isZeroToOne ? (pixel.b / 255.0) : ((pixel.b - mean) / std);
          buffer[pixelIndex] = r;
          buffer[planeSize + pixelIndex] = g;
          buffer[2 * planeSize + pixelIndex] = b;
          pixelIndex++;
        }
      }
    } else {
      int bufferIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = processed.getPixel(x, y);
          final double r = isZeroToOne ? (pixel.r / 255.0) : ((pixel.r - mean) / std);
          final double g = isZeroToOne ? (pixel.g / 255.0) : ((pixel.g - mean) / std);
          final double b = isZeroToOne ? (pixel.b / 255.0) : ((pixel.b - mean) / std);
          buffer[bufferIndex++] = r;
          buffer[bufferIndex++] = g;
          buffer[bufferIndex++] = b;
        }
      }
    }

    return buffer;
  }

  /// Converts platform [CameraImage] into RGB [img.Image].
  static img.Image convertCameraImageToRgb(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToImage(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888ToImage(image);
    } else if (image.format.group == ImageFormatGroup.nv21) {
      return _convertNV21ToImage(image);
    } else {
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
