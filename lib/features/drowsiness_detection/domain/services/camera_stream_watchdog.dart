import 'dart:async';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Monitors camera frame arrival to detect hardware/stream stalls and trigger automatic recovery.
class CameraStreamWatchdog {
  static const String _tag = 'CameraWatchdog';

  final Duration stallTimeout;
  final Duration checkInterval;

  Timer? _timer;
  DateTime? _lastHeartbeatTimestamp;
  bool _isRunning = false;
  int _stallRecoveryCount = 0;

  CameraStreamWatchdog({
    this.stallTimeout = const Duration(milliseconds: 2500),
    this.checkInterval = const Duration(milliseconds: 1000),
  });

  bool get isRunning => _isRunning;
  int get stallRecoveryCount => _stallRecoveryCount;
  DateTime? get lastHeartbeatTimestamp => _lastHeartbeatTimestamp;

  /// Records a frame heartbeat from the camera image stream.
  void recordHeartbeat([DateTime? timestamp]) {
    _lastHeartbeatTimestamp = timestamp ?? DateTime.now();
  }

  /// Starts the watchdog monitor with a stall recovery callback.
  void start({
    required Future<void> Function() onStallDetected,
  }) {
    stop();
    _isRunning = true;
    _lastHeartbeatTimestamp = DateTime.now();

    _timer = Timer.periodic(checkInterval, (timer) async {
      if (!_isRunning) return;

      final now = DateTime.now();
      if (_lastHeartbeatTimestamp != null) {
        final elapsed = now.difference(_lastHeartbeatTimestamp!);

        if (elapsed > stallTimeout) {
          _stallRecoveryCount++;
          AppLogger.warning(
            _tag,
            'Camera frame stall detected (no frames for ${elapsed.inMilliseconds}ms). Triggering recovery #$_stallRecoveryCount...',
          );

          // Reset timestamp to give recovery time to take effect
          _lastHeartbeatTimestamp = now;

          try {
            await onStallDetected();
          } catch (e, st) {
            AppLogger.error(_tag, 'Watchdog stall recovery failed', e, st);
          }
        }
      }
    });

    AppLogger.info(_tag, 'Camera watchdog started.');
  }

  /// Stops the watchdog timer.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _lastHeartbeatTimestamp = null;
  }

  /// Resets recovery counters.
  void reset() {
    stop();
    _stallRecoveryCount = 0;
  }
}
