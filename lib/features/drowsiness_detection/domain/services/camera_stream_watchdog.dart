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
  final Duration transitionGrace;

  const WatchdogConfig({
    this.cameraStallTimeout = AppConstants.cameraStallTimeout,
    this.inferenceStallTimeout = AppConstants.inferenceStallTimeout,
    this.faceLostTimeout = AppConstants.faceLostDegradedTimeout,
    this.checkInterval = const Duration(milliseconds: 1000),
    this.transitionGrace = const Duration(milliseconds: 1200),
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
  DateTime? _lastTransitionAt;
  bool _isLightCriticallyLow = false;
  bool _isThermalThrottled = false;

  int _cameraRecoveryAttempts = 0;
  int _inferenceRecoveryAttempts = 0;
  bool _isRecoveringCamera = false;
  bool _isRecoveringInference = false;

  MonitoringHealth _currentHealth = MonitoringHealth.healthy;
  MonitoringIssue _currentIssue = MonitoringIssue.none;

  MonitoringWatchdog({WatchdogConfig? config})
      : config = config ?? const WatchdogConfig();

  bool get isRunning => _isRunning;
  int get stallRecoveryCount => _stallRecoveryCount;
  int get cameraRecoveryAttempts => _cameraRecoveryAttempts;
  int get inferenceRecoveryAttempts => _inferenceRecoveryAttempts;
  DateTime? get lastCameraFrameAt => _lastCameraFrameAt;
  DateTime? get lastHeartbeatTimestamp => _lastCameraFrameAt;
  DateTime? get lastInferenceAt => _lastInferenceAt;
  DateTime? get lastFaceDetectedAt => _lastFaceDetectedAt;
  DateTime? get lastServiceHeartbeatAt => _lastServiceHeartbeatAt;
  DateTime? get lastTransitionAt => _lastTransitionAt;
  MonitoringHealth get currentHealth => _currentHealth;
  MonitoringIssue get currentIssue => _currentIssue;

  /// Records arrival of a new CameraImage frame.
  void recordCameraFrameHeartbeat([DateTime? timestamp]) {
    _lastCameraFrameAt = timestamp ?? DateTime.now();
    _cameraRecoveryAttempts = 0;
  }

  /// Alias for backward compatibility with existing camera stream calls.
  void recordHeartbeat([DateTime? timestamp]) {
    recordCameraFrameHeartbeat(timestamp);
  }

  /// Records a successful completion of an eye-state inference pass.
  void recordInferenceHeartbeat([DateTime? timestamp]) {
    _lastInferenceAt = timestamp ?? DateTime.now();
    _inferenceRecoveryAttempts = 0;
  }

  /// Records a successful face detection/tracking frame.
  void recordFaceDetected([DateTime? timestamp]) {
    _lastFaceDetectedAt = timestamp ?? DateTime.now();
  }

  /// Records a foreground service / native heartbeat.
  void recordServiceHeartbeat([DateTime? timestamp]) {
    _lastServiceHeartbeatAt = timestamp ?? DateTime.now();
  }

  /// Records an app lifecycle transition (e.g. moving to background) to grant a temporary transition grace.
  void recordLifecycleTransition([DateTime? timestamp]) {
    _lastTransitionAt = timestamp ?? DateTime.now();
    AppLogger.info(_tag, 'Watchdog transition grace activated (1200ms).');
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

    final bool isWithinGrace = _lastTransitionAt != null &&
        now.difference(_lastTransitionAt!) < config.transitionGrace + config.cameraStallTimeout;
    final cameraTimeout = isWithinGrace
        ? config.cameraStallTimeout + config.transitionGrace
        : config.cameraStallTimeout;
    final inferenceTimeout = isWithinGrace
        ? config.inferenceStallTimeout + config.transitionGrace
        : config.inferenceStallTimeout;

    // 1. Check Camera Stall (Hardware / Stream freeze)
    if (_lastCameraFrameAt != null) {
      final frameAge = now.difference(_lastCameraFrameAt!);
      if (frameAge > cameraTimeout) {
        final health = (_cameraRecoveryAttempts < 2)
            ? MonitoringHealth.recovering
            : MonitoringHealth.failed;
        return (health: health, issue: MonitoringIssue.cameraStalled);
      }
    }

    // 2. Check Inference Stall (Frames are arriving but AI pipeline is blocked)
    if (_lastCameraFrameAt != null && _lastInferenceAt != null) {
      final inferenceAge = now.difference(_lastInferenceAt!);
      if (inferenceAge > inferenceTimeout) {
        final health = (_inferenceRecoveryAttempts < 2)
            ? MonitoringHealth.recovering
            : MonitoringHealth.failed;
        return (health: health, issue: MonitoringIssue.inferenceStalled);
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

  Future<void> Function()? _onCameraStallDetected;
  Future<bool> Function({required int attempt})? _onCameraRecoveryRequested;
  Future<bool> Function({required int attempt})? _onInferenceRecoveryRequested;
  void Function(MonitoringHealth health, MonitoringIssue issue)? _onHealthChanged;

  /// Starts the watchdog monitor with callbacks for stall recovery and health shifts.
  void start({
    Future<void> Function()? onCameraStallDetected,
    Future<bool> Function({required int attempt})? onCameraRecoveryRequested,
    Future<bool> Function({required int attempt})? onInferenceRecoveryRequested,
    void Function(MonitoringHealth health, MonitoringIssue issue)? onHealthChanged,
  }) {
    stop();
    _isRunning = true;
    final now = DateTime.now();
    _lastCameraFrameAt = now;
    _lastInferenceAt = now;
    _lastFaceDetectedAt = now;
    _lastServiceHeartbeatAt = now;
    _cameraRecoveryAttempts = 0;
    _inferenceRecoveryAttempts = 0;
    _isRecoveringCamera = false;
    _isRecoveringInference = false;
    _currentHealth = MonitoringHealth.healthy;
    _currentIssue = MonitoringIssue.none;
    _onCameraStallDetected = onCameraStallDetected;
    _onCameraRecoveryRequested = onCameraRecoveryRequested;
    _onInferenceRecoveryRequested = onInferenceRecoveryRequested;
    _onHealthChanged = onHealthChanged;

    _timer = Timer.periodic(config.checkInterval, (_) {
      checkHealthTick();
    });

    AppLogger.info(_tag, 'Monitoring watchdog started.');
  }

  /// Evaluates health immediately at [now], firing callbacks if health state transitioned.
  Future<void> checkHealthTick({DateTime? now}) async {
    if (!_isRunning) return;

    final checkTime = now ?? DateTime.now();
    final eval = evaluateHealth(checkTime);

    if (eval.health != _currentHealth || eval.issue != _currentIssue) {
      _currentHealth = eval.health;
      _currentIssue = eval.issue;
      AppLogger.warning(
        _tag,
        'Monitoring Health Transition: [${_currentHealth.name}] Issue: [${_currentIssue.name}]',
      );
      _onHealthChanged?.call(_currentHealth, _currentIssue);
    }

    // Auto-Recovery Phase 6: Camera Stall Recovery
    if (eval.issue == MonitoringIssue.cameraStalled && !_isRecoveringCamera) {
      _isRecoveringCamera = true;
      _stallRecoveryCount++;
      _cameraRecoveryAttempts++;
      AppLogger.warning(
        _tag,
        'Camera stream stall detected. Executing recovery attempt #$_cameraRecoveryAttempts...',
      );

      try {
        bool recovered = false;
        if (_onCameraRecoveryRequested != null) {
          recovered = await _onCameraRecoveryRequested!.call(attempt: _cameraRecoveryAttempts);
        } else if (_onCameraStallDetected != null) {
          await _onCameraStallDetected!.call();
          recovered = true;
        }

        if (recovered) {
          _lastCameraFrameAt = DateTime.now();
          _cameraRecoveryAttempts = 0;
          _currentHealth = MonitoringHealth.healthy;
          _currentIssue = MonitoringIssue.none;
          AppLogger.info(_tag, 'Camera auto-recovery succeeded. Restored healthy state.');
          _onHealthChanged?.call(_currentHealth, _currentIssue);
        }
      } catch (e, st) {
        AppLogger.error(_tag, 'Camera recovery error on attempt #$_cameraRecoveryAttempts', e, st);
      } finally {
        _isRecoveringCamera = false;
      }
    }

    // Auto-Recovery Phase 7: Inference Stall Recovery
    if (eval.issue == MonitoringIssue.inferenceStalled && !_isRecoveringInference) {
      _isRecoveringInference = true;
      _inferenceRecoveryAttempts++;
      AppLogger.warning(
        _tag,
        'Inference stall detected. Executing inference auto-recovery #$_inferenceRecoveryAttempts...',
      );

      try {
        bool recovered = false;
        if (_onInferenceRecoveryRequested != null) {
          recovered = await _onInferenceRecoveryRequested!.call(attempt: _inferenceRecoveryAttempts);
        }

        if (recovered) {
          _lastInferenceAt = DateTime.now();
          _inferenceRecoveryAttempts = 0;
          _currentHealth = MonitoringHealth.healthy;
          _currentIssue = MonitoringIssue.none;
          AppLogger.info(_tag, 'Inference auto-recovery succeeded. Restored healthy state.');
          _onHealthChanged?.call(_currentHealth, _currentIssue);
        }
      } catch (e, st) {
        AppLogger.error(_tag, 'Inference recovery error on attempt #$_inferenceRecoveryAttempts', e, st);
      } finally {
        _isRecoveringInference = false;
      }
    }
  }

  /// Stops the watchdog timer.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _onCameraStallDetected = null;
    _onCameraRecoveryRequested = null;
    _onInferenceRecoveryRequested = null;
    _onHealthChanged = null;
    _lastCameraFrameAt = null;
    _lastInferenceAt = null;
    _lastFaceDetectedAt = null;
    _lastServiceHeartbeatAt = null;
    _cameraRecoveryAttempts = 0;
    _inferenceRecoveryAttempts = 0;
    _isRecoveringCamera = false;
    _isRecoveringInference = false;
    _currentHealth = MonitoringHealth.healthy;
    _currentIssue = MonitoringIssue.none;
  }

  /// Resets recovery counters and timers.
  void reset() {
    stop();
    _stallRecoveryCount = 0;
    _cameraRecoveryAttempts = 0;
    _inferenceRecoveryAttempts = 0;
  }
}

/// Backwards compatibility typedef for any existing references.
typedef CameraStreamWatchdog = MonitoringWatchdog;
