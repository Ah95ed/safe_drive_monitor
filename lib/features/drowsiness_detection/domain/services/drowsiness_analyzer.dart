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
  DateTime? _firstClosedTimestamp;
  DateTime? _firstOpenTimestamp;
  DateTime? _recoveryStartTimestamp;
  bool _isAlarmPlaying = false;

  // --- Temporal smoothing (PHASE 7) --------------------------------------
  // The eye model can be noisy near the decision boundary. Debounce isolated
  // flips: a new state must be seen on [_debounceFrames] consecutive readings
  // (or once at high confidence) before it is accepted. This costs at most one
  // extra frame of latency, far below the watching/alarm thresholds, so it
  // does not meaningfully delay a real alarm.
  static const int _debounceFrames = 2;
  static const double _highConfidenceFastSwitch = 0.80;
  EyeState _stableEyeState = EyeState.open;
  EyeState _candidateEyeState = EyeState.open;
  int _candidateStreak = 0;

  EyeState _debounceEyeState(EyePrediction prediction) {
    if (prediction.isUnknown) return _stableEyeState;
    if (prediction.state == _stableEyeState) {
      _candidateEyeState = _stableEyeState;
      _candidateStreak = 0;
      return _stableEyeState;
    }
    if (prediction.state == _candidateEyeState) {
      _candidateStreak++;
    } else {
      _candidateEyeState = prediction.state;
      _candidateStreak = 1;
    }
    final int needed =
        prediction.confidence >= _highConfidenceFastSwitch ? 1 : _debounceFrames;
    if (_candidateStreak >= needed) {
      _stableEyeState = _candidateEyeState;
      _candidateStreak = 0;
    }
    return _stableEyeState;
  }

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

  /// Resets the analyzer state and PERCLOS rolling window.
  void reset() {
    _currentState = DriverAlertState.normal;
    _firstClosedTimestamp = null;
    _firstOpenTimestamp = null;
    _recoveryStartTimestamp = null;
    _isAlarmPlaying = false;
    _stableEyeState = EyeState.open;
    _candidateEyeState = EyeState.open;
    _candidateStreak = 0;
    _perclosCalculator.reset();
  }

  /// Processes an [EyePrediction] with optional [DriverFace] pose.
  DrowsinessAnalysisResult processPrediction(
    EyePrediction prediction, {
    DriverFace? driverFace,
  }) {
    final now = prediction.timestamp;

    // Filter out unknown predictions
    if (prediction.isUnknown) {
      return _buildResult(
        continuousClosed: _calculateDuration(_firstClosedTimestamp, now),
        continuousOpen: _calculateDuration(_firstOpenTimestamp, now),
        perclos: currentPerclos,
        message: 'جاري التحقق من وضوح الصورة...',
      );
    }

    // Update rolling PERCLOS window
    final perclos = _perclosCalculator.addPrediction(prediction);

    // Check head nod (pitch < threshold)
    final double? pitch = driverFace?.headEulerAngleX;
    final bool isHeadNodding = pitch != null && pitch < config.headNodPitchThreshold;

    // Temporal smoothing: act on the debounced eye state, not the raw frame.
    final EyeState effectiveState = _debounceEyeState(prediction);

    if (effectiveState == EyeState.closed) {
      // Driver closed eyes
      _firstOpenTimestamp = null;
      _recoveryStartTimestamp = null; // Interrupt ongoing recovery

      _firstClosedTimestamp ??= now;
      final closedDuration = now.difference(_firstClosedTimestamp!);

      // Loud alarm is driven by *instantaneous* eye closure only (PHASE 7):
      //   Condition 1: prolonged continuous eye closure (>= alarmThreshold)
      //   Condition 2: head nodding forward together with a sustained closure
      // PERCLOS is a gradual fatigue support signal; on its own it only
      // escalates to `drowsy`, it never triggers the loud alarm in this phase.
      final bool isProlongedClosed = closedDuration >= config.alarmThreshold;
      final bool isNodWithClosed = isHeadNodding && closedDuration >= config.watchingThreshold;

      if (isProlongedClosed || isNodWithClosed) {
        _currentState = DriverAlertState.alarm;
        _isAlarmPlaying = true;

        String msg = '🚨 انتبه! تم اكتشاف نوم أثناء القيادة!';
        if (isNodWithClosed && !isProlongedClosed) {
          msg = '🚨 انتبه! تم اكتشاف انحناء رأس ونوم السائق!';
        }

        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: true,
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
          message: 'مراقبة العينين...',
        );
      } else {
        // Under watching threshold (< 350ms) -> Natural blink
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          message: 'رمش طبيعي',
        );
      }
    } else {
      // Driver opened eyes (EyeState.open)
      _firstClosedTimestamp = null;
      _firstOpenTimestamp ??= now;
      final openDuration = now.difference(_firstOpenTimestamp!);

      // If alarm is currently active, require sustained open state for recoveryThreshold (1000ms)
      if (_currentState == DriverAlertState.alarm || _isAlarmPlaying) {
        _recoveryStartTimestamp ??= now;
        final recoveryDuration = now.difference(_recoveryStartTimestamp!);

        // Recovery depends only on sustained continuous OPEN eyes (PHASE 1/3).
        if (recoveryDuration >= config.recoveryThreshold) {
          // Successfully recovered from alarm
          _currentState = DriverAlertState.normal;
          _isAlarmPlaying = false;
          _recoveryStartTimestamp = null;
          return _buildResult(
            continuousClosed: Duration.zero,
            continuousOpen: openDuration,
            perclos: perclos,
            isHeadNod: isHeadNodding,
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
            message: 'جاري تأكيد استيقاظ السائق...',
          );
        }
      } else {
        // Normal open state
        _currentState = _perclosCalculator.isWarningLevel
            ? DriverAlertState.drowsy
            : DriverAlertState.normal;

        return _buildResult(
          continuousClosed: Duration.zero,
          continuousOpen: openDuration,
          perclos: perclos,
          isHeadNod: isHeadNodding,
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
