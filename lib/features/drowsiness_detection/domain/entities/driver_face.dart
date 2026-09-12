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
  final int lifecycleEpoch;

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
    this.lifecycleEpoch = 0,
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

  DriverFace copyWith({
    int? trackingId,
    Rect? boundingBox,
    Rect? eyeRoi,
    Point<int>? leftEye,
    Point<int>? rightEye,
    double? headEulerAngleX,
    double? headEulerAngleY,
    double? headEulerAngleZ,
    double? leftEyeOpenProbability,
    double? rightEyeOpenProbability,
    DateTime? detectedAt,
    int? lifecycleEpoch,
  }) {
    return DriverFace(
      trackingId: trackingId ?? this.trackingId,
      boundingBox: boundingBox ?? this.boundingBox,
      eyeRoi: eyeRoi ?? this.eyeRoi,
      leftEye: leftEye ?? this.leftEye,
      rightEye: rightEye ?? this.rightEye,
      headEulerAngleX: headEulerAngleX ?? this.headEulerAngleX,
      headEulerAngleY: headEulerAngleY ?? this.headEulerAngleY,
      headEulerAngleZ: headEulerAngleZ ?? this.headEulerAngleZ,
      leftEyeOpenProbability: leftEyeOpenProbability ?? this.leftEyeOpenProbability,
      rightEyeOpenProbability: rightEyeOpenProbability ?? this.rightEyeOpenProbability,
      detectedAt: detectedAt ?? this.detectedAt,
      lifecycleEpoch: lifecycleEpoch ?? this.lifecycleEpoch,
    );
  }
}
