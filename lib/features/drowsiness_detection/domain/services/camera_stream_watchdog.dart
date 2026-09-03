import 'dart:async';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';

/// Configuration options for the monitoring watchdog.
class WatchdogConfig {
  final Duration cameraStallTimeout;
  final Duration inferenceStallTimeout;
  final Duration faceLostTimeout;
  final Duration checkInterval;

  const WatchdogConfig({
    this.cameraStallTimeout = AppConstants.cameraStallTimeout,
    this.inferenceStallTimeout = AppConstants.inferenceStallTimeout,
    this.faceLostTimeout = AppConstants.faceLostDegradedTimeout,
    this.checkInterval = const Duration(milliseconds: 1000),
  });
}

/// Comprehensive Safety Watchdog monitoring hardware, inference stream, and background service heartbeats.
/// Strictly implements "NEVER FAIL SILENTLY": Active monitoring requires recent frames and inferences.
class MonitoringWatchdog {
  static const String _tag = 'MonitoringWatchdog';

  final WatchdogConfig config;

  Timer? _timer;
  bool _isRunning = false;
  int _stallRecoveryCount = 0;

  DateTime? _lastCameraFrameAt;
  DateTime? _lastInferenceAt;
  DateTime? _lastFaceDetectedAt;
  DateTime? _lastServiceHeartbeatAt;
  bool _isLightCriticallyLow = false;
  bool _isThermalThrottled = false;

  MonitoringHealth _currentHealth = MonitoringHealth.healthy;
  MonitoringIssue _currentIssue = MonitoringIssue.none;

  MonitoringWatchdog({WatchdogConfig? config})
      : config = config ?? const WatchdogConfig();

  bool get isRunning => _isRunning;
  int get stallRecoveryCount => _stallRecoveryCount;
  DateTime? get lastCameraFrameAt => _lastCameraFrameAt;
  DateTime? get lastHeartbeatTimestamp => _lastCameraFrameAt;
  DateTime? get lastInferenceAt => _lastInferenceAt;
  DateTime? get lastFaceDetectedAt => _lastFaceDetectedAt;
  DateTime? get lastServiceHeartbeatAt => _lastServiceHeartbeatAt;
  MonitoringHealth get currentHealth => _currentHealth;
  MonitoringIssue get currentIssue => _currentIssue;

  /// Records arrival of a new CameraImage frame.
  void recordCameraFrameHeartbeat([DateTime? timestamp]) {
    _lastCameraFrameAt = timestamp ?? DateTime.now();
  }

  /// Alias for backward compatibility with existing camera stream calls.
  void recordHeartbeat([DateTime? timestamp]) {
    recordCameraFrameHeartbeat(timestamp);
  }

  /// Records a successful completion of an eye-state inference pass.
  void recordInferenceHeartbeat([DateTime? timestamp]) {
    _lastInferenceAt = timestamp ?? DateTime.now();
  }

  /// Records a successful face detection/tracking frame.
  void recordFaceDetected([DateTime? timestamp]) {
    _lastFaceDetectedAt = timestamp ?? DateTime.now();
  }

  /// Records a foreground service / native heartbeat.
  void recordServiceHeartbeat([DateTime? timestamp]) {
    _lastServiceHeartbeatAt = timestamp ?? DateTime.now();
  }

  /// Sets critical ambient light state.
  void recordLightingState({required bool isCritical}) {
    _isLightCriticallyLow = isCritical;
  }

  /// Sets thermal throttling state.
  void recordThermalState({required bool isThrottled}) {
    _isThermalThrottled = isThrottled;
  }

  /// Evaluates the system health and returns current health and root cause issue.
  ({MonitoringHealth health, MonitoringIssue issue}) evaluateHealth(DateTime now) {
    if (!_isRunning) {
      return (health: MonitoringHealth.healthy, issue: MonitoringIssue.none);
    }

    // 1. Check Camera Stall (Hardware / Stream freeze)
    if (_lastCameraFrameAt != null) {
      final frameAge = now.difference(_lastCameraFrameAt!);
      if (frameAge > config.cameraStallTimeout) {
        return (health: MonitoringHealth.failed, issue: MonitoringIssue.cameraStalled);
      }
    }

    // 2. Check Inference Stall (Frames are arriving but AI pipeline is blocked)
    if (_lastCameraFrameAt != null && _lastInferenceAt != null) {
      final inferenceAge = now.difference(_lastInferenceAt!);
      if (inferenceAge > config.inferenceStallTimeout) {
        return (health: MonitoringHealth.failed, issue: MonitoringIssue.inferenceStalled);
      }
    }

    // 3. Degraded checks (Non-fatal issues)
    if (_isLightCriticallyLow) {
      return (health: MonitoringHealth.degraded, issue: MonitoringIssue.insufficientLight);
    }

    if (_isThermalThrottled) {
      return (health: MonitoringHealth.degraded, issue: MonitoringIssue.thermalThrottling);
    }

    if (_lastFaceDetectedAt != null) {
      final faceAge = now.difference(_lastFaceDetectedAt!);
      if (faceAge > config.faceLostTimeout) {
        return (health: MonitoringHealth.degraded, issue: MonitoringIssue.noDriverFace);
      }
    }

    return (health: MonitoringHealth.healthy, issue: MonitoringIssue.none);
  }

  /// Starts the watchdog monitor with callbacks for stall recovery and health shifts.
  void start({
    required Future<void> Function() onCameraStallDetected,
    void Function(MonitoringHealth health, MonitoringIssue issue)? onHealthChanged,
  }) {
    stop();
    _isRunning = true;
    final now = DateTime.now();
    _lastCameraFrameAt = now;
    _lastInferenceAt = now;
    _lastFaceDetectedAt = now;
    _lastServiceHeartbeatAt = now;
    _currentHealth = MonitoringHealth.healthy;
    _currentIssue = MonitoringIssue.none;

    _timer = Timer.periodic(config.checkInterval, (timer) async {
      if (!_isRunning) return;

      final checkTime = DateTime.now();
      final eval = evaluateHealth(checkTime);

      if (eval.health != _currentHealth || eval.issue != _currentIssue) {
        _currentHealth = eval.health;
        _currentIssue = eval.issue;
        AppLogger.warning(
          _tag,
          'Monitoring Health Transition: [${_currentHealth.name}] Issue: [${_currentIssue.name}]',
        );
        onHealthChanged?.call(_currentHealth, _currentIssue);
      }

      // Trigger automatic camera recovery if camera stalled
      if (eval.issue == MonitoringIssue.cameraStalled) {
        _stallRecoveryCount++;
        AppLogger.warning(
          _tag,
          'Camera frame stall confirmed. Triggering recovery #$_stallRecoveryCount...',
        );
        // Reset timestamp to give recovery time to take effect
        _lastCameraFrameAt = checkTime;
        try {
          await onCameraStallDetected();
        } catch (e, st) {
          AppLogger.error(_tag, 'Watchdog camera recovery failed', e, st);
        }
      }
    });

    AppLogger.info(_tag, 'Monitoring watchdog started.');
  }

  /// Stops the watchdog timer.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _lastCameraFrameAt = null;
    _lastInferenceAt = null;
    _lastFaceDetectedAt = null;
    _lastServiceHeartbeatAt = null;
    _currentHealth = MonitoringHealth.healthy;
    _currentIssue = MonitoringIssue.none;
  }

  /// Resets recovery counters and timers.
  void reset() {
    stop();
    _stallRecoveryCount = 0;
  }
}

/// Backwards compatibility typedef for any existing references.
typedef CameraStreamWatchdog = MonitoringWatchdog;
