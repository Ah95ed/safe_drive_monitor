import 'dart:math';
import 'dart:ui';

/// Represents a detected driver face with spatial landmarks, head pose, and eye ROI.
class DriverFace {
  final int? trackingId;
  final Rect boundingBox;
  final Rect eyeRoi;
  final Point<int>? leftEye;
  final Point<int>? rightEye;
  final double? headEulerAngleX; // Pitch (nod up/down)
  final double? headEulerAngleY; // Yaw (turn left/right)
  final double? headEulerAngleZ; // Roll (tilt sideways)
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final DateTime detectedAt;

  const DriverFace({
    this.trackingId,
    required this.boundingBox,
    required this.eyeRoi,
    this.leftEye,
    this.rightEye,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    required this.detectedAt,
  });

  /// Check if the detected face has valid eye landmarks
  bool get hasEyeLandmarks => leftEye != null && rightEye != null;

  /// Average eye open probability reported by ML Kit (if available)
  double? get averageEyeOpenProbability {
    if (leftEyeOpenProbability != null && rightEyeOpenProbability != null) {
      return (leftEyeOpenProbability! + rightEyeOpenProbability!) / 2.0;
    }
    return leftEyeOpenProbability ?? rightEyeOpenProbability;
  }
}
