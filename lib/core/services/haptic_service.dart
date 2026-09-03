import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:vibration/vibration.dart';

abstract class HapticService {
  Future<void> startAlarmHaptic();
  Future<void> playWarningHaptic();
  Future<void> stopAlarmHaptic();
  Future<void> dispose();
}

class AppHapticService implements HapticService {
  static const String _tag = 'HapticService';
  bool _isVibrating = false;

  @override
  Future<void> startAlarmHaptic() async {
    if (_isVibrating) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        _isVibrating = true;
        // Pulse pattern: wait 400ms, vibrate 900ms, repeat
        await Vibration.vibrate(pattern: [400, 900], repeat: 0);
        AppLogger.info(_tag, 'Alarm haptic vibration started.');
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Vibration not supported or failed: $e');
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
