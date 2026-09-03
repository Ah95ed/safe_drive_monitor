import 'package:flutter/foundation.dart';

/// Represents the engineering health of the monitoring subsystem.
/// Strictly separated from the driver's alertness state.
enum MonitoringHealth {
  /// Monitoring is functioning completely normally with recent frames and inferences.
  healthy,

  /// Monitoring is active but experiencing non-fatal degradation (e.g. low light, face temporarily lost, thermal throttle).
  degraded,

  /// Monitoring has failed or stalled (e.g. camera frozen, inference halted, foreground service stopped).
  failed,
}

extension MonitoringHealthX on MonitoringHealth {
  bool get isHealthy => this == MonitoringHealth.healthy;
  bool get isDegraded => this == MonitoringHealth.degraded;
  bool get isFailed => this == MonitoringHealth.failed;

  String get arabicLabel {
    switch (this) {
      case MonitoringHealth.healthy:
        return 'المراقبة نشطة ومستقرة';
      case MonitoringHealth.degraded:
        return 'المراقبة بحالة انخفاض كفاءة';
      case MonitoringHealth.failed:
        return 'توقف نظام المراقبة';
    }
  }
}

/// Identifies the specific root cause or issue affecting the monitoring pipeline.
enum MonitoringIssue {
  /// No issue detected; pipeline running as expected.
  none,

  /// Driver face cannot be acquired or locked in the camera feed.
  noDriverFace,

  /// Ambient light is critically low; eye classification cannot be reliably performed.
  insufficientLight,

  /// Camera frames have stopped arriving from hardware or CameraX stream.
  cameraStalled,

  /// Camera frames are arriving but AI inference pipeline is frozen/unresponsive.
  inferenceStalled,

  /// Android foreground service is killed, stopped, or disconnected.
  backgroundServiceFailed,

  /// Thermal throttling detected from Android system.
  thermalThrottling,
}

extension MonitoringIssueX on MonitoringIssue {
  bool get hasIssue => this != MonitoringIssue.none;

  String get arabicDescription {
    switch (this) {
      case MonitoringIssue.none:
        return 'لا توجد أي مشاكل تقنية';
      case MonitoringIssue.noDriverFace:
        return 'لم يتم العثور على وجه السائق';
      case MonitoringIssue.insufficientLight:
        return 'الإضاءة غير كافية لرؤية العين';
      case MonitoringIssue.cameraStalled:
        return 'توقف تدفق إطارات الكاميرا';
      case MonitoringIssue.inferenceStalled:
        return 'توقف محرك الاستدلال والذكاء الاصطناعي';
      case MonitoringIssue.backgroundServiceFailed:
        return 'توقف خدمة المراقبة في الخلفية';
      case MonitoringIssue.thermalThrottling:
        return 'ارتفاع حرارة الجهاز يؤثر على الأداء';
    }
  }
}

/// Immutable snapshot representing the active driving monitoring session.
@immutable
class DrivingSessionState {
  final bool active;
  final DateTime? startedAt;
  final MonitoringHealth health;
  final MonitoringIssue issue;
  final bool foregroundServiceActive;
  final bool batteryOptimizationExempt;
  final bool wakeLockActive;
  final DateTime? lastCameraFrameAt;
  final DateTime? lastInferenceAt;
  final DateTime? lastFaceDetectedAt;
  final DateTime? lastServiceHeartbeatAt;

  const DrivingSessionState({
    this.active = false,
    this.startedAt,
    this.health = MonitoringHealth.healthy,
    this.issue = MonitoringIssue.none,
    this.foregroundServiceActive = false,
    this.batteryOptimizationExempt = false,
    this.wakeLockActive = false,
    this.lastCameraFrameAt,
    this.lastInferenceAt,
    this.lastFaceDetectedAt,
    this.lastServiceHeartbeatAt,
  });

  /// Factory for an idle, stopped session.
  factory DrivingSessionState.idle() => const DrivingSessionState();

  /// Strictly determines if monitoring is actually working.
  /// Rule: Monitoring Active = Service Alive + Recent Camera Frame + Recent Inference.
  bool isActuallyWorking({
    required DateTime now,
    Duration frameStallThreshold = const Duration(milliseconds: 2500),
    Duration inferenceStallThreshold = const Duration(milliseconds: 3000),
  }) {
    if (!active) return false;
    if (lastCameraFrameAt == null || lastInferenceAt == null) return false;

    final frameAge = now.difference(lastCameraFrameAt!);
    final inferenceAge = now.difference(lastInferenceAt!);

    return frameAge <= frameStallThreshold &&
        inferenceAge <= inferenceStallThreshold &&
        health != MonitoringHealth.failed;
  }

  DrivingSessionState copyWith({
    bool? active,
    DateTime? startedAt,
    MonitoringHealth? health,
    MonitoringIssue? issue,
    bool? foregroundServiceActive,
    bool? batteryOptimizationExempt,
    bool? wakeLockActive,
    DateTime? lastCameraFrameAt,
    DateTime? lastInferenceAt,
    DateTime? lastFaceDetectedAt,
    DateTime? lastServiceHeartbeatAt,
  }) {
    return DrivingSessionState(
      active: active ?? this.active,
      startedAt: startedAt ?? this.startedAt,
      health: health ?? this.health,
      issue: issue ?? this.issue,
      foregroundServiceActive:
          foregroundServiceActive ?? this.foregroundServiceActive,
      batteryOptimizationExempt:
          batteryOptimizationExempt ?? this.batteryOptimizationExempt,
      wakeLockActive: wakeLockActive ?? this.wakeLockActive,
      lastCameraFrameAt: lastCameraFrameAt ?? this.lastCameraFrameAt,
      lastInferenceAt: lastInferenceAt ?? this.lastInferenceAt,
      lastFaceDetectedAt: lastFaceDetectedAt ?? this.lastFaceDetectedAt,
      lastServiceHeartbeatAt:
          lastServiceHeartbeatAt ?? this.lastServiceHeartbeatAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrivingSessionState &&
          runtimeType == other.runtimeType &&
          active == other.active &&
          startedAt == other.startedAt &&
          health == other.health &&
          issue == other.issue &&
          foregroundServiceActive == other.foregroundServiceActive &&
          batteryOptimizationExempt == other.batteryOptimizationExempt &&
          wakeLockActive == other.wakeLockActive &&
          lastCameraFrameAt == other.lastCameraFrameAt &&
          lastInferenceAt == other.lastInferenceAt &&
          lastFaceDetectedAt == other.lastFaceDetectedAt &&
          lastServiceHeartbeatAt == other.lastServiceHeartbeatAt;

  @override
  int get hashCode => Object.hash(
        active,
        startedAt,
        health,
        issue,
        foregroundServiceActive,
        batteryOptimizationExempt,
        wakeLockActive,
        lastCameraFrameAt,
        lastInferenceAt,
        lastFaceDetectedAt,
        lastServiceHeartbeatAt,
      );
}
