import 'dart:math';
import 'package:safe_drive_monitor/core/services/thermal_manager_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

/// Target frequencies and throttled intervals calculated adaptively by the scheduler.
class AdaptiveSchedule {
  final double targetInferenceHz;
  final Duration inferenceInterval;
  final double targetFaceDetectionHz;
  final Duration faceDetectionInterval;
  final Duration uiThrottleInterval;
  final bool isSafetyOverrideActive;
  final String debugReason;

  const AdaptiveSchedule({
    required this.targetInferenceHz,
    required this.inferenceInterval,
    required this.targetFaceDetectionHz,
    required this.faceDetectionInterval,
    required this.uiThrottleInterval,
    required this.isSafetyOverrideActive,
    required this.debugReason,
  });

  static Duration hzToInterval(double hz) {
    if (hz <= 0.0) return const Duration(milliseconds: 250);
    return Duration(microseconds: (1000000.0 / hz).round());
  }
}

/// Adaptive Inference Scheduler implementing the "UPSHIFT FAST, DOWNSHIFT SLOW"
/// safety policy, thermal integration, and zero-redundancy workload optimization.
class AdaptiveInferenceScheduler {
  final double minimumSafeInferenceHz;
  final double maxInferenceHz;

  // Hysteresis tracking
  DateTime? _recoveryConfirmedAt;
  DateTime? _lastClosedDetectedAt;
  double _currentInferenceHz = 4.0;

  AdaptiveInferenceScheduler({
    this.minimumSafeInferenceHz = 4.0, // 4 Hz = 250ms floor
    this.maxInferenceHz = 15.0,        // 15 Hz = 66ms ceiling
  });

  double get currentInferenceHz => _currentInferenceHz;
  DateTime? get lastClosedDetectedAt => _lastClosedDetectedAt;

  /// Resets the scheduler state (e.g. at driving session start/stop).
  void reset() {
    _recoveryConfirmedAt = null;
    _lastClosedDetectedAt = null;
    _currentInferenceHz = minimumSafeInferenceHz;
  }

  /// Calculates the next adaptive schedule based on driver state, predictions,
  /// thermal state, face tracking stability, and lighting conditions.
  AdaptiveSchedule evaluate({
    required DriverAlertState alertState,
    required EyePrediction? lastPrediction,
    required DriverFace? driverFace,
    required bool isFaceTrackingStable,
    required bool isRoiFresh,
    required bool isLowLight,
    required DeviceThermalState thermalState,
    required DateTime now,
    bool isHeadNodDetected = false,
  }) {
    // 1. Check if state requires high-risk / critical detection
    final bool isAlarmOrDrowsy = alertState == DriverAlertState.alarm || alertState == DriverAlertState.drowsy;
    final bool isWatching = alertState == DriverAlertState.watching;
    final bool isRecovering = alertState == DriverAlertState.recovering;
    final bool isFirstClosed = alertState == DriverAlertState.normal &&
        lastPrediction != null &&
        lastPrediction.isClosed &&
        lastPrediction.confidence >= 0.50;

    if (isFirstClosed) {
      _lastClosedDetectedAt = now;
    }

    // Safety Override applies whenever any suspicious/drowsy condition exists
    final bool isHighRisk = isAlarmOrDrowsy || isWatching || isRecovering || isFirstClosed || isHeadNodDetected;

    double targetHz;
    String reason;

    if (isAlarmOrDrowsy) {
      // States E & F: Drowsy / Alarm -> Maximum required detection rate (15 Hz)
      targetHz = maxInferenceHz;
      _recoveryConfirmedAt = null;
      reason = 'CRITICAL_${alertState.name.toUpperCase()}';
    } else if (isRecovering) {
      // State G: Recovering -> 15 Hz until confirmed open recovery
      targetHz = maxInferenceHz;
      _recoveryConfirmedAt = now;
      reason = 'RECOVERING';
    } else if (isWatching) {
      // State D: Watching -> 12 Hz
      targetHz = 12.0;
      reason = 'WATCHING';
    } else if (isFirstClosed) {
      // State C: First Valid CLOSED while in Normal state -> Instant upshift to 15 Hz
      targetHz = maxInferenceHz;
      reason = 'FIRST_VALID_CLOSED';
    } else if (isHeadNodDetected) {
      // Head nodding downward -> 12 Hz
      targetHz = 12.0;
      reason = 'HEAD_NOD_DETECTED';
    } else {
      // Driver is in Normal state. Apply Downshift Slow (Hysteresis) & Thermal Policy
      if (_recoveryConfirmedAt != null) {
        final elapsedSinceRecovery = now.difference(_recoveryConfirmedAt!).inMilliseconds;
        if (elapsedSinceRecovery < 1000) {
          // 0-1s after recovery: stay on 8-12 Hz
          targetHz = 8.0;
          reason = 'HYSTERESIS_STEP_1';
        } else if (elapsedSinceRecovery < 2500) {
          // 1-2.5s after recovery: 5 Hz
          targetHz = 5.0;
          reason = 'HYSTERESIS_STEP_2';
        } else {
          // >2.5s after recovery: return to normal baseline
          _recoveryConfirmedAt = null;
          targetHz = _computeNormalBaselineHz(
            lastPrediction: lastPrediction,
            isFaceTrackingStable: isFaceTrackingStable,
            isLowLight: isLowLight,
            thermalState: thermalState,
          );
          reason = 'STABLE_NORMAL';
        }
      } else {
        targetHz = _computeNormalBaselineHz(
          lastPrediction: lastPrediction,
          isFaceTrackingStable: isFaceTrackingStable,
          isLowLight: isLowLight,
          thermalState: thermalState,
        );
        reason = 'NORMAL';
      }
    }

    // Safety Floor Guard: never drop below minimumSafeInferenceHz
    targetHz = max(targetHz, minimumSafeInferenceHz).clamp(minimumSafeInferenceHz, maxInferenceHz);
    _currentInferenceHz = targetHz;

    // 2. ML Kit Adaptive Frequency Calculation
    // Stable face & fresh ROI -> 1.0 - 2.0 Hz (reduce expensive ML Kit calls)
    // Face lost / unstable / moved / low-light / high-risk -> 4.0 - 5.0 Hz
    final double targetFaceHz;
    if (isHighRisk || !isFaceTrackingStable || !isRoiFresh || isLowLight || driverFace == null) {
      targetFaceHz = 4.0; // Fast tracking / reacquisition
    } else if (thermalState.isThermalPressure) {
      targetFaceHz = 1.0; // Thermal reduction when stable
    } else {
      targetFaceHz = 1.8; // ~550ms when face is smoothly tracked
    }

    // 3. UI Update Interval: 1-2 Hz for debug/gauges, instant for alertState changes
    final Duration uiThrottleInterval = (thermalState == DeviceThermalState.severe || thermalState == DeviceThermalState.critical)
        ? const Duration(milliseconds: 1000) // 1 Hz during thermal pressure
        : const Duration(milliseconds: 500);  // 2 Hz normal

    return AdaptiveSchedule(
      targetInferenceHz: targetHz,
      inferenceInterval: AdaptiveSchedule.hzToInterval(targetHz),
      targetFaceDetectionHz: targetFaceHz,
      faceDetectionInterval: AdaptiveSchedule.hzToInterval(targetFaceHz),
      uiThrottleInterval: uiThrottleInterval,
      isSafetyOverrideActive: isHighRisk && thermalState.isThermalPressure,
      debugReason: reason,
    );
  }

  double _computeNormalBaselineHz({
    required EyePrediction? lastPrediction,
    required bool isFaceTrackingStable,
    required bool isLowLight,
    required DeviceThermalState thermalState,
  }) {
    // If probabilities are fluctuating / low confidence (State B)
    if (lastPrediction == null || lastPrediction.confidence < 0.65 || lastPrediction.isUnknown) {
      return 8.0; // 8 Hz when confidence is unstable
    }

    // If thermal pressure is present on device, use safe floor
    if (thermalState == DeviceThermalState.moderate ||
        thermalState == DeviceThermalState.severe ||
        thermalState == DeviceThermalState.critical) {
      return minimumSafeInferenceHz; // 4 Hz
    }

    // If face is fully stable and open confidence is high
    if (isFaceTrackingStable && lastPrediction.isOpen && lastPrediction.confidence >= 0.70 && !isLowLight) {
      return minimumSafeInferenceHz; // 4 Hz (~250ms)
    }

    // Default normal baseline
    return 5.0; // 5 Hz (~200ms)
  }
}
