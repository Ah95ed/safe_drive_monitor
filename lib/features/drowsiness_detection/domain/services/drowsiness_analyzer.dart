import 'package:safe_drive_monitor/core/utils/time_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/perclos_calculator.dart';

/// Result of an analysis step by [DrowsinessAnalyzer].
class DrowsinessAnalysisResult {
  final DriverAlertState alertState;
  final Duration continuousClosedDuration;
  final Duration continuousOpenDuration;
  final double perclos;
  final bool isHeadNodDetected;
  final bool shouldTriggerAlarm;
  final bool shouldStopAlarm;
  final String statusMessage;

  const DrowsinessAnalysisResult({
    required this.alertState,
    required this.continuousClosedDuration,
    required this.continuousOpenDuration,
    this.perclos = 0.0,
    this.isHeadNodDetected = false,
    required this.shouldTriggerAlarm,
    required this.shouldStopAlarm,
    required this.statusMessage,
  });
}

/// Advanced multi-level temporal state machine incorporating instantaneous eye closure,
/// rolling PERCLOS fatigue analysis, head pose nod detection, and safe recovery thresholds.
class DrowsinessAnalyzer {
  final DrowsinessConfig config;
  final TimeProvider timeProvider;
  final PerclosCalculator _perclosCalculator;

  DriverAlertState _currentState = DriverAlertState.normal;
  DateTime? _closedStartedAt;
  DateTime? _openStartedAt;
  bool _isAlarmPlaying = false;

  DrowsinessAnalyzer({
    this.config = const DrowsinessConfig(),
    this.timeProvider = const SystemTimeProvider(),
    PerclosCalculator? perclosCalculator,
  }) : _perclosCalculator = perclosCalculator ??
            PerclosCalculator(
              windowDuration: config.perclosWindowDuration,
              warningThreshold: config.perclosWarningThreshold,
              alarmThreshold: config.perclosAlarmThreshold,
            );

  DriverAlertState get currentState => _currentState;
  bool get isAlarmActive => _isAlarmPlaying;
  double get currentPerclos => _perclosCalculator.currentPerclos;
  double get currentPerclosPercentage => _perclosCalculator.currentPerclosPercentage;
  DateTime? get closedStartedAt => _closedStartedAt;
  DateTime? get openStartedAt => _openStartedAt;

  /// Resets the analyzer state and PERCLOS rolling window.
  void reset() {
    _currentState = DriverAlertState.normal;
    _closedStartedAt = null;
    _openStartedAt = null;
    _isAlarmPlaying = false;
    _perclosCalculator.reset();
  }

  /// Processes an [EyePrediction] with optional [DriverFace] pose and custom timestamp [now].
  DrowsinessAnalysisResult processPrediction(
    EyePrediction prediction, {
    DriverFace? driverFace,
    bool hasDriverFace = true,
    DateTime? now,
  }) {
    final currentNow = now ?? prediction.timestamp;

    // 0. Face Presence Gating: A driver face MUST be present to evaluate drowsiness.
    // If no face is detected in the frame, drowsiness alarm must NEVER trigger.
    if (!hasDriverFace) {
      _closedStartedAt = null;
      _openStartedAt = null;
      final wasAlarm = _currentState == DriverAlertState.alarm || _isAlarmPlaying;
      _currentState = DriverAlertState.normal;
      _isAlarmPlaying = false;
      return _buildResult(
        continuousClosed: Duration.zero,
        continuousOpen: Duration.zero,
        perclos: currentPerclos,
        isHeadNod: false,
        shouldTriggerAlarm: false,
        shouldStopAlarm: wasAlarm,
        message: 'لا يوجد وجه سائق واضح — يرجى توجيه الكاميرا نحو الوجه',
      );
    }

    // Check head nod (pitch < threshold)
    final double? pitch = driverFace?.headEulerAngleX;
    final bool isHeadNodding = pitch != null && pitch < config.headNodPitchThreshold;

    // 1. UNKNOWN prediction handling (Requirement 6: UNKNOWN does NOT mean OPEN)
    if (prediction.isUnknown) {
      // Keep current alarm state until confident OPEN or CLOSED is observed
      return _buildResult(
        continuousClosed: _calculateDuration(_closedStartedAt, currentNow),
        continuousOpen: _calculateDuration(_openStartedAt, currentNow),
        perclos: currentPerclos,
        isHeadNod: isHeadNodding,
        shouldTriggerAlarm: _currentState == DriverAlertState.alarm,
        shouldStopAlarm: false,
        message: 'جاري التحقق من وضوح الصورة...',
      );
    }

    // Update rolling PERCLOS window for valid predictions
    final perclos = _perclosCalculator.addPrediction(prediction);

    // 2. CLOSED eye handling (Requirement 5 & 7)
    if (prediction.state == EyeState.closed) {
      // Driver closed eyes: immediately cancel any pending recovery
      _openStartedAt = null;

      _closedStartedAt ??= currentNow;
      final closedDuration = currentNow.difference(_closedStartedAt!);

      final bool isProlongedClosed = closedDuration >= config.alarmThreshold;
      final bool isNodWithClosed = isHeadNodding && closedDuration >= config.watchingThreshold;

      if (isProlongedClosed || isNodWithClosed) {
        _currentState = DriverAlertState.alarm;
        _isAlarmPlaying = true;

        final String msg = isNodWithClosed && !isProlongedClosed
            ? '🚨 انتبه! تم اكتشاف انحناء رأس ونوم السائق!'
            : '🚨 انتبه! تم اكتشاف نوم أثناء القيادة!';

        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: true,
          shouldStopAlarm: false,
          message: msg,
        );
      } else if (closedDuration >= config.drowsyThreshold || _perclosCalculator.isWarningLevel) {
        if (_currentState != DriverAlertState.alarm) {
          _currentState = DriverAlertState.drowsy;
        }
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: _currentState == DriverAlertState.alarm,
          shouldStopAlarm: false,
          message: '⚠️ تحذير: علامات نعاس وإجهاد!',
        );
      } else if (closedDuration >= config.watchingThreshold) {
        if (_currentState != DriverAlertState.alarm &&
            _currentState != DriverAlertState.drowsy) {
          _currentState = DriverAlertState.watching;
        }
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: _currentState == DriverAlertState.alarm,
          shouldStopAlarm: false,
          message: 'مراقبة العينين...',
        );
      } else {
        // Under watching threshold (< 350ms) -> Natural blink
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: _currentState == DriverAlertState.alarm,
          shouldStopAlarm: false,
          message: 'رمش طبيعي',
        );
      }
    } else {
      // 3. OPEN eye handling (Requirement 5)
      // Check confidence threshold: if below minimumOpenConfidence, do NOT count as recovery
      if (prediction.confidence < config.minimumOpenConfidence) {
        return _buildResult(
          continuousClosed: _calculateDuration(_closedStartedAt, currentNow),
          continuousOpen: _calculateDuration(_openStartedAt, currentNow),
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: _currentState == DriverAlertState.alarm,
          shouldStopAlarm: false,
          message: 'جاري تأكيد حالة العينين...',
        );
      }

      // Valid open eye prediction
      _closedStartedAt = null;

      // If alarm is currently active, require continuous open state for recoveryThreshold (900ms)
      if (_currentState == DriverAlertState.alarm || _isAlarmPlaying) {
        _openStartedAt ??= currentNow;
        final openDuration = currentNow.difference(_openStartedAt!);

        if (openDuration >= config.recoveryThreshold) {
          // Successfully recovered from alarm!
          _currentState = DriverAlertState.normal;
          _isAlarmPlaying = false;
          _closedStartedAt = null;
          _openStartedAt = null;

          return _buildResult(
            continuousClosed: Duration.zero,
            continuousOpen: openDuration,
            perclos: perclos,
            isHeadNod: isHeadNodding,
            shouldTriggerAlarm: false,
            shouldStopAlarm: true,
            message: 'تم استعادة الانتباه - العينان مفتوحتان',
          );
        } else {
          // Still in alarm until full recovery window is fulfilled
          return _buildResult(
            continuousClosed: Duration.zero,
            continuousOpen: openDuration,
            perclos: perclos,
            isHeadNod: isHeadNodding,
            shouldTriggerAlarm: true,
            shouldStopAlarm: false,
            message: 'جاري تأكيد استيقاظ السائق...',
          );
        }
      } else {
        // Normal open state
        _openStartedAt ??= currentNow;
        final openDuration = currentNow.difference(_openStartedAt!);

        _currentState = _perclosCalculator.isWarningLevel
            ? DriverAlertState.drowsy
            : DriverAlertState.normal;

        return _buildResult(
          continuousClosed: Duration.zero,
          continuousOpen: openDuration,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: _currentState == DriverAlertState.drowsy
              ? '⚠️ تحذير: مستوى إجهاد مرتفع (PERCLOS)'
              : 'السائق مستيقظ',
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
    double perclos = 0.0,
    bool isHeadNod = false,
    bool shouldTriggerAlarm = false,
    bool shouldStopAlarm = false,
    required String message,
  }) {
    return DrowsinessAnalysisResult(
      alertState: _currentState,
      continuousClosedDuration: continuousClosed,
      continuousOpenDuration: continuousOpen,
      perclos: perclos,
      isHeadNodDetected: isHeadNod,
      shouldTriggerAlarm: shouldTriggerAlarm,
      shouldStopAlarm: shouldStopAlarm,
      statusMessage: message,
    );
  }
}
