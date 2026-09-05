import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:vibration/vibration.dart';

abstract class HapticService {
  bool get isVibrating;
  Future<void> startAlarmHaptic();
  Future<void> playWarningHaptic();
  Future<void> stopAlarmHaptic();
  Future<void> suspendHapticTemporarily({Duration duration});
  Future<void> dispose();
}

class AppHapticService implements HapticService {
  static const String _tag = 'HapticService';
  bool _isVibrating = false;
  DateTime? _suspendedUntil;

  @override
  bool get isVibrating => _isVibrating;

  @override
  Future<void> startAlarmHaptic() async {
    if (_isVibrating) return;
    if (_suspendedUntil != null && DateTime.now().isBefore(_suspendedUntil!)) {
      return;
    }
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        _isVibrating = true;
        // Pulse pattern per Phase 12: 250ms vibrate, 400ms pause, 250ms vibrate, 800ms pause
        // [wait, vibrate, wait, vibrate, wait]
        await Vibration.vibrate(pattern: [0, 250, 400, 250, 800], repeat: 0);
        AppLogger.info(_tag, 'Alarm haptic vibration started with gentle pulse pattern.');
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Vibration not supported or failed: $e');
    }
  }

  @override
  Future<void> suspendHapticTemporarily({
    Duration duration = const Duration(milliseconds: 350),
  }) async {
    _suspendedUntil = DateTime.now().add(duration);
    if (_isVibrating) {
      await stopAlarmHaptic();
      AppLogger.info(_tag, 'Haptic suspended for ${duration.inMilliseconds}ms for camera stabilization.');
    }
  }

  @override
  Future<void> playWarningHaptic() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Distinct short triple-buzz for technical degradation/warnings
        await Vibration.vibrate(pattern: [0, 150, 100, 150, 100, 300]);
        AppLogger.info(_tag, 'Technical warning haptic played.');
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Warning vibration failed: $e');
    }
  }

  @override
  Future<void> stopAlarmHaptic() async {
    if (!_isVibrating) return;
    try {
      _isVibrating = false;
      await Vibration.cancel();
      AppLogger.info(_tag, 'Alarm haptic vibration stopped.');
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to cancel vibration: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopAlarmHaptic();
  }
}
