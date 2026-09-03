import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Represents ambient lighting status determined by camera sensor luminance.
enum LightingState {
  /// Adequate ambient light for eye tracking and classification.
  good,

  /// Dim ambient light. Adaptive exposure recommended.
  low,

  /// Critical darkness. Requires maximum exposure + screen illumination or warning.
  critical,
}

extension LightingStateX on LightingState {
  bool get isGood => this == LightingState.good;
  bool get isLow => this == LightingState.low;
  bool get isCritical => this == LightingState.critical;

  String get arabicLabel {
    switch (this) {
      case LightingState.good:
        return 'إضاءة جيدة';
      case LightingState.low:
        return 'إضاءة منخفضة (ليلي)';
      case LightingState.critical:
        return 'ظلام حرج';
    }
  }
}

/// Intelligent Lighting and Night Mode Manager.
/// Performs fast Y-plane luminance sampling and adaptive exposure steering.
class LightingManager {
  static const String _tag = 'LightingManager';

  final double lowLightThreshold;
  final double criticalLightThreshold;
  final double smoothingFactor;
  final Duration adaptationHysteresis;

  double _smoothedLuminance = 128.0;
  LightingState _lightingState = LightingState.good;
  DateTime _lastAdaptationTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _screenIlluminationOpacity = 0.0;
  int _consecutiveCriticalFrames = 0;

  LightingManager({
    this.lowLightThreshold = AppConstants.lowLightThreshold,
    this.criticalLightThreshold = AppConstants.criticalDarknessThreshold,
    this.smoothingFactor = 0.25,
    this.adaptationHysteresis = const Duration(milliseconds: 1400),
  });

  double get currentLuminance => _smoothedLuminance;
  LightingState get lightingState => _lightingState;
  bool get isLowLight => _lightingState != LightingState.good;
  bool get isCriticalDarkness => _lightingState == LightingState.critical;
  double get screenIlluminationOpacity => _screenIlluminationOpacity;

  /// Resets luminance and adaptation state.
  void reset() {
    _smoothedLuminance = 128.0;
    _lightingState = LightingState.good;
    _screenIlluminationOpacity = 0.0;
    _consecutiveCriticalFrames = 0;
    _lastAdaptationTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Calculates fast sub-sampled average luminance from the camera Y plane (0..255).
  LightingState processCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return _lightingState;

    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    final int width = image.width;
    final int height = image.height;
    final int rowStride = yPlane.bytesPerRow;

    int totalLum = 0;
    int sampledCount = 0;

    // Sub-sample grid step (every 16th pixel in x and y) - extremely lightweight
    const int step = 16;

    for (int y = 0; y < height; y += step) {
      final int rowStart = y * rowStride;
      for (int x = 0; x < width; x += step) {
        totalLum += yBytes[rowStart + x];
        sampledCount++;
      }
    }

    if (sampledCount == 0) return _lightingState;

    final double instantLum = totalLum / sampledCount;

    // Exponential Moving Average (EMA) smoothing to prevent transient light flickers
    _smoothedLuminance =
        (_smoothedLuminance * (1.0 - smoothingFactor)) + (instantLum * smoothingFactor);

    if (_smoothedLuminance < criticalLightThreshold) {
      _lightingState = LightingState.critical;
      _consecutiveCriticalFrames++;
    } else if (_smoothedLuminance < lowLightThreshold) {
      _lightingState = LightingState.low;
      _consecutiveCriticalFrames = 0;
      _screenIlluminationOpacity = 0.0;
    } else {
      _lightingState = LightingState.good;
      _consecutiveCriticalFrames = 0;
      _screenIlluminationOpacity = 0.0;
    }

    // Dynamic screen illumination fallback for critical darkness (stepped safely: 5% -> 10% -> 15% max)
    if (_lightingState == LightingState.critical) {
      if (_consecutiveCriticalFrames > 40) {
        _screenIlluminationOpacity = 0.15;
      } else if (_consecutiveCriticalFrames > 20) {
        _screenIlluminationOpacity = 0.10;
      } else if (_consecutiveCriticalFrames > 5) {
        _screenIlluminationOpacity = 0.05;
      }
    }

    return _lightingState;
  }

  /// Evaluates whether camera exposure offset should be adjusted.
  /// Uses hysteresis to prevent hunting/jitter on every frame.
  double? computeAdaptiveExposureOffset({
    required DateTime now,
    required double currentOffset,
    required double minOffset,
    required double maxOffset,
    required double stepSize,
  }) {
    if (minOffset == maxOffset) return null;
    if (now.difference(_lastAdaptationTime) < adaptationHysteresis) return null;

    final step = stepSize > 0 ? stepSize : 0.5;
    double targetOffset = currentOffset;

    switch (_lightingState) {
      case LightingState.good:
        if (currentOffset > 0.0) {
          targetOffset = (currentOffset - step).clamp(0.0, maxOffset);
        }
        break;
      case LightingState.low:
        if (currentOffset < maxOffset) {
          targetOffset = (currentOffset + step).clamp(minOffset, maxOffset);
        }
        break;
      case LightingState.critical:
        // Jump to maximum safe exposure under critical darkness
        targetOffset = maxOffset;
        break;
    }

    if ((targetOffset - currentOffset).abs() > 0.05) {
      _lastAdaptationTime = now;
      AppLogger.info(
        _tag,
        'Adaptive exposure suggested: $currentOffset -> $targetOffset (Lum: ${_smoothedLuminance.toStringAsFixed(1)})',
      );
      return targetOffset;
    }

    return null;
  }
}

/// Backwards compatibility typedef
typedef LowLightDetector = LightingManager;
