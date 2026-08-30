import 'package:safe_drive_monitor/core/utils/time_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

/// Result of an analysis step by [DrowsinessAnalyzer].
class DrowsinessAnalysisResult {
  final DriverAlertState alertState;
  final Duration continuousClosedDuration;
  final Duration continuousOpenDuration;
  final bool shouldTriggerAlarm;
  final bool shouldStopAlarm;
  final String statusMessage;

  const DrowsinessAnalysisResult({
    required this.alertState,
    required this.continuousClosedDuration,
    required this.continuousOpenDuration,
    required this.shouldTriggerAlarm,
    required this.shouldStopAlarm,
    required this.statusMessage,
  });
}

/// Time-based State Machine that analyzes eye state predictions and manages alertness transitions.
class DrowsinessAnalyzer {
  final DrowsinessConfig config;
  final TimeProvider timeProvider;

  DriverAlertState _currentState = DriverAlertState.normal;
  DateTime? _firstClosedTimestamp;
  DateTime? _firstOpenTimestamp;
  DateTime? _recoveryStartTimestamp;
  bool _isAlarmPlaying = false;

  DrowsinessAnalyzer({
    this.config = const DrowsinessConfig(),
    this.timeProvider = const SystemTimeProvider(),
  });

  DriverAlertState get currentState => _currentState;
  bool get isAlarmActive => _isAlarmPlaying;

  /// Resets the analyzer state (e.g. at session start/stop).
  void reset() {
    _currentState = DriverAlertState.normal;
    _firstClosedTimestamp = null;
    _firstOpenTimestamp = null;
    _recoveryStartTimestamp = null;
    _isAlarmPlaying = false;
  }

  /// Processes an [EyePrediction] and determines alertness state.
  DrowsinessAnalysisResult processPrediction(EyePrediction prediction) {
    final now = prediction.timestamp;

    // Filter out low confidence / unknown predictions
    if (prediction.isUnknown) {
      return _buildResult(
        continuousClosed: _calculateDuration(_firstClosedTimestamp, now),
        continuousOpen: _calculateDuration(_firstOpenTimestamp, now),
        message: 'جاري التحقق من وضوح الصورة...',
      );
    }

    if (prediction.isClosed) {
      // Driver closed eyes
      _firstOpenTimestamp = null;
      _recoveryStartTimestamp = null; // Interrupt any ongoing recovery

      _firstClosedTimestamp ??= now;
      final closedDuration = now.difference(_firstClosedTimestamp!);

      if (closedDuration >= config.alarmThreshold) {
        _currentState = DriverAlertState.alarm;
        _isAlarmPlaying = true;
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          shouldTriggerAlarm: true,
          message: '🚨 انتبه! تم اكتشاف نوم أثناء القيادة!',
        );
      } else if (closedDuration >= config.drowsyThreshold) {
        if (_currentState != DriverAlertState.alarm) {
          _currentState = DriverAlertState.drowsy;
        }
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          message: '⚠️ تحذير: علامات نعاس!',
        );
      } else if (closedDuration >= config.watchingThreshold) {
        if (_currentState != DriverAlertState.alarm &&
            _currentState != DriverAlertState.drowsy) {
          _currentState = DriverAlertState.watching;
        }
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          message: 'مراقبة العينين...',
        );
      } else {
        // Under watching threshold (< 400ms) -> treated as natural blink
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          message: 'رمش طبيعي',
        );
      }
    } else {
      // Driver opened eyes (EyeState.open)
      _firstClosedTimestamp = null;
      _firstOpenTimestamp ??= now;
      final openDuration = now.difference(_firstOpenTimestamp!);

      // If alarm is currently active, require sustained open state to recover safely
      if (_currentState == DriverAlertState.alarm || _isAlarmPlaying) {
        _recoveryStartTimestamp ??= now;
        final recoveryDuration = now.difference(_recoveryStartTimestamp!);

        if (recoveryDuration >= config.recoveryThreshold) {
          // Successfully recovered from alarm
          _currentState = DriverAlertState.normal;
          _isAlarmPlaying = false;
          _recoveryStartTimestamp = null;
          return _buildResult(
            continuousClosed: Duration.zero,
            continuousOpen: openDuration,
            shouldStopAlarm: true,
            message: 'تم استعادة الانتباه - العينان مفتوحتان',
          );
        } else {
          // Still in alarm until full recovery window is fulfilled
          return _buildResult(
            continuousClosed: Duration.zero,
            continuousOpen: openDuration,
            message: 'جاري تأكيد استيقاظ السائق...',
          );
        }
      } else {
        // Normal open state
        _currentState = DriverAlertState.normal;
        return _buildResult(
          continuousClosed: Duration.zero,
          continuousOpen: openDuration,
          message: 'السائق مستيقظ',
        );
      }
    }
  }

  Duration _calculateDuration(DateTime? start, DateTime now) {
    if (start == null) return Duration.zero;
    return now.difference(start);
  }

  DrowsinessAnalysisResult _buildResult({
    required Duration continuousClosed,
    required Duration continuousOpen,
    bool shouldTriggerAlarm = false,
    bool shouldStopAlarm = false,
    required String message,
  }) {
    return DrowsinessAnalysisResult(
      alertState: _currentState,
      continuousClosedDuration: continuousClosed,
      continuousOpenDuration: continuousOpen,
      shouldTriggerAlarm: shouldTriggerAlarm,
      shouldStopAlarm: shouldStopAlarm,
      statusMessage: message,
    );
  }
}
