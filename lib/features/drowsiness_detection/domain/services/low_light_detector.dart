import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service that analyzes camera frame luminance to detect low-light / night driving conditions.
class LowLightDetector {
  final double lowLightThreshold; // e.g. 40.0 on [0..255] scale
  final double smoothingFactor;

  double _smoothedLuminance = 128.0;

  LowLightDetector({
    this.lowLightThreshold = 40.0,
    this.smoothingFactor = 0.25,
  });

  double get currentLuminance => _smoothedLuminance;
  bool get isLowLight => _smoothedLuminance < lowLightThreshold;

  /// Resets luminance tracker.
  void reset() {
    _smoothedLuminance = 128.0;
  }

  /// Calculates fast sub-sampled average luminance from the camera Y plane.
  double processCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return _smoothedLuminance;

    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    final int width = image.width;
    final int height = image.height;
    final int rowStride = yPlane.bytesPerRow;

    int totalLum = 0;
    int sampledCount = 0;

    // Sub-sample grid step (every 16th pixel in x and y)
    const int step = 16;

    for (int y = 0; y < height; y += step) {
      final int rowStart = y * rowStride;
      for (int x = 0; x < width; x += step) {
        totalLum += yBytes[rowStart + x];
        sampledCount++;
      }
    }

    if (sampledCount == 0) return _smoothedLuminance;

    final double instantLum = totalLum / sampledCount;

    // Apply EMA smoothing
    _smoothedLuminance =
        (_smoothedLuminance * (1.0 - smoothingFactor)) + (instantLum * smoothingFactor);

    return _smoothedLuminance;
  }
}
