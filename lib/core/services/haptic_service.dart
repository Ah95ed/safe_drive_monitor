import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:vibration/vibration.dart';

abstract class HapticService {
  Future<void> startAlarmHaptic();
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
        // Pulse pattern: wait 500ms, vibrate 1000ms, repeat
        await Vibration.vibrate(pattern: [500, 1000], repeat: 0);
        AppLogger.info(_tag, 'Alarm haptic vibration started.');
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Vibration not supported or failed: $e');
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
