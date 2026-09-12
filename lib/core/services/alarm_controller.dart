import 'package:safe_drive_monitor/core/services/audio_alarm_service.dart';
import 'package:safe_drive_monitor/core/services/haptic_service.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
/// Reason indicating why the alarm was triggered.
enum AlarmTriggerReason {
  none,
  drowsiness,
  monitoringFailure,
  test,
}

/// Unified AlarmController managing both audio alarm and haptic vibration feedback
/// based strictly on [DriverAlertState], independent of UI, Widget mounted status,
/// or [AppLifecycleState].
class AlarmController {
  static const String _tag = 'AlarmController';
  final AudioAlarmService _alarmService;
  final HapticService? _hapticService;

  bool _isPlaying = false;
  AlarmTriggerReason _activeReason = AlarmTriggerReason.none;

  AlarmController(this._alarmService, [this._hapticService]);

  /// Returns true if the alarm is currently active.
  bool get isPlaying => _isPlaying;

  /// Returns the reason why the alarm was triggered.
  AlarmTriggerReason get activeReason => _activeReason;

  /// Synchronizes the alarm output state with the evaluated [DriverAlertState].
  ///
  /// - When [state] is [DriverAlertState.alarm] and alarm is not active: starts audio & haptics.
  /// - When [state] is NOT [DriverAlertState.alarm] and alarm is active: stops audio & haptics.
  /// - Safe to invoke on every single frame/prediction.
  Future<void> sync(
    DriverAlertState state, {
    AlarmTriggerReason reason = AlarmTriggerReason.drowsiness,
    Map<String, dynamic>? diagnostics,
  }) async {
    final shouldPlay =
        state == DriverAlertState.alarm ||
        state == DriverAlertState.recovering;

    if (shouldPlay && !_isPlaying) {
      _isPlaying = true;
      _activeReason = reason;
      final diagStr = diagnostics != null
          ? diagnostics.entries.map((e) => '${e.key}=${e.value}').join(' ')
          : '';
      AppLogger.info(
        _tag,
        'ALARM_START reason=${reason.name} $diagStr'.trim(),
      );
      await Future.wait([
        _alarmService.playAlarm(),
        if (_hapticService != null) _hapticService!.startAlarmHaptic(),
      ]);
      return;
    }

    if (!shouldPlay && _isPlaying) {
      _isPlaying = false;
      AppLogger.info(
        _tag,
        'AlarmController: sync stopped ALARM playback (alert state transitioned to: ${state.name}).',
      );
      await Future.wait([
        _alarmService.stopAlarm(),
        if (_hapticService != null) _hapticService!.stopAlarmHaptic(),
      ]);
    }
  }

  /// Explicitly halts any ongoing alarm playback unconditionally regardless of state.
  Future<void> stop() async {
    _isPlaying = false;
    _activeReason = AlarmTriggerReason.none;
    AppLogger.info(_tag, 'AlarmController: explicit stop invoked.');
    try {
      await Future.wait([
        _alarmService.stopAlarm(),
        if (_hapticService != null) _hapticService!.stopAlarmHaptic(),
      ]);
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed during explicit stop', e, st);
    }
  }

  /// Force-stops alarm audio and haptic feedback. Idempotent.
  Future<void> forceStop() async {
    await stop();
  }

  /// Releases resources held by the controller.
  Future<void> dispose() async {
    await stop();
  }
}
