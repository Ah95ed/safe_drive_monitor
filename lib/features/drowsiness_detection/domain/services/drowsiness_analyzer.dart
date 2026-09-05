import 'package:safe_drive_monitor/core/utils/time_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/drowsiness_config.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/timed_eye_prediction.dart';
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
  final double openRatio;
  final double closedRatio;
  final double unknownRatio;
  final double emaOpenConfidence;
  final bool isRecovering;

  const DrowsinessAnalysisResult({
    required this.alertState,
    required this.continuousClosedDuration,
    required this.continuousOpenDuration,
    this.perclos = 0.0,
    this.isHeadNodDetected = false,
    required this.shouldTriggerAlarm,
    required this.shouldStopAlarm,
    required this.statusMessage,
    this.openRatio = 0.0,
    this.closedRatio = 0.0,
    this.unknownRatio = 0.0,
    this.emaOpenConfidence = 0.0,
    this.isRecovering = false,
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

  final List<TimedEyePrediction> _recoveryWindow = [];
  double _emaOpenConfidence = 0.0;

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
  double get emaOpenConfidence => _emaOpenConfidence;
  List<TimedEyePrediction> get recoveryWindow => List.unmodifiable(_recoveryWindow);

  /// Resets the analyzer state and PERCLOS rolling window.
  void reset() {
    _currentState = DriverAlertState.normal;
    _closedStartedAt = null;
    _openStartedAt = null;
    _isAlarmPlaying = false;
    _recoveryWindow.clear();
    _emaOpenConfidence = 0.0;
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

    // Record sample into rolling recovery window
    _recoveryWindow.add(TimedEyePrediction.fromPrediction(prediction));
    final pruneCutoff = currentNow.subtract(config.recoveryWindowDuration + const Duration(milliseconds: 500));
    _recoveryWindow.removeWhere((p) => p.timestamp.isBefore(pruneCutoff));

    // Update Exponential Moving Average (EMA) of open confidence
    final double sampleOpenConf = (prediction.state == EyeState.open && prediction.confidence >= config.minimumOpenConfidence)
        ? prediction.confidence
        : 0.0;
    _emaOpenConfidence = (_emaOpenConfidence == 0.0 && prediction.state == EyeState.open)
        ? sampleOpenConf
        : (config.recoveryEmaAlpha * sampleOpenConf) + ((1.0 - config.recoveryEmaAlpha) * _emaOpenConfidence);

    // Compute window stats for the configured window duration
    final windowCutoff = currentNow.subtract(config.recoveryWindowDuration);
    final activeWindow = _recoveryWindow.where((p) => !p.timestamp.isBefore(windowCutoff)).toList();
    final totalSamples = activeWindow.length;
    final openCount = activeWindow.where((p) => p.isOpen).length;
    final closedCount = activeWindow.where((p) => p.isClosed).length;
    final unknownCount = activeWindow.where((p) => p.isUnknown).length;

    final double openRatio = totalSamples > 0 ? openCount / totalSamples : 0.0;
    final double closedRatio = totalSamples > 0 ? closedCount / totalSamples : 0.0;
    final double unknownRatio = totalSamples > 0 ? unknownCount / totalSamples : 0.0;

    // 0. Face Presence Gating: A driver face MUST be present to evaluate drowsiness.
    // If no face is detected in the frame, drowsiness alarm must NEVER trigger.
    if (!hasDriverFace) {
      _closedStartedAt = null;
      _openStartedAt = null;
      final wasAlarm = _currentState == DriverAlertState.alarm ||
          _currentState == DriverAlertState.recovering ||
          _isAlarmPlaying;
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
        openRatio: openRatio,
        closedRatio: closedRatio,
        unknownRatio: unknownRatio,
      );
    }

    // Check head nod (pitch < threshold)
    final double? pitch = driverFace?.headEulerAngleX;
    final bool isHeadNodding = pitch != null && pitch < config.headNodPitchThreshold;

    // 1. UNKNOWN prediction handling (Requirement 6: UNKNOWN does NOT mean OPEN or CLOSED)
    if (prediction.isUnknown) {
      final isCurrentlyInAlarm = _currentState == DriverAlertState.alarm ||
          _currentState == DriverAlertState.recovering ||
          _isAlarmPlaying;
      return _buildResult(
        continuousClosed: _calculateDuration(_closedStartedAt, currentNow),
        continuousOpen: _calculateDuration(_openStartedAt, currentNow),
        perclos: currentPerclos,
        isHeadNod: isHeadNodding,
        shouldTriggerAlarm: isCurrentlyInAlarm,
        shouldStopAlarm: false,
        message: 'جاري التحقق من وضوح الصورة...',
        openRatio: openRatio,
        closedRatio: closedRatio,
        unknownRatio: unknownRatio,
        emaOpenConfidence: _emaOpenConfidence,
        isRecovering: _currentState == DriverAlertState.recovering,
      );
    }

    // Update rolling PERCLOS window for valid predictions
    final perclos = _perclosCalculator.addPrediction(prediction);

    // 2. ACTIVE ALARM / RECOVERY HANDLING (Phases 6, 7, 8, 9)
    final bool isInAlarmOrRecovering = _currentState == DriverAlertState.alarm ||
        _currentState == DriverAlertState.recovering ||
        _isAlarmPlaying;

    if (isInAlarmOrRecovering) {
      // 1. If eyes haven't opened yet: keep alarm active on closed frames
      if (_openStartedAt == null) {
        if (prediction.state == EyeState.closed &&
            prediction.confidence >= config.minimumClosedConfidence) {
          _currentState = DriverAlertState.alarm;
          _closedStartedAt ??= currentNow;
          final closedDuration = currentNow.difference(_closedStartedAt!);

          return _buildResult(
            continuousClosed: closedDuration,
            continuousOpen: Duration.zero,
            perclos: perclos,
            isHeadNod: isHeadNodding,
            shouldTriggerAlarm: true,
            shouldStopAlarm: false,
            message: '🚨 انتبه! تم اكتشاف نوم أثناء القيادة!',
            openRatio: openRatio,
            closedRatio: closedRatio,
            unknownRatio: unknownRatio,
            emaOpenConfidence: _emaOpenConfidence,
            isRecovering: false,
          );
        }
      }

      // 2. If eyes have begun opening (_openStartedAt != null), check for relapse:
      // A strong closed frame (>= recoveryRecentClosedMinConfidence) or recent strong closed frames abort recovery!
      final bool isCurrentStrongClosed = prediction.state == EyeState.closed &&
          prediction.confidence >= config.recoveryRecentClosedMinConfidence;
      final recentClosedCutoff = currentNow.subtract(config.recoveryRecentClosedWindow);
      final hasRecentStrongClosed = _openStartedAt != null &&
          activeWindow.any((p) =>
              p.isClosed &&
              !p.timestamp.isBefore(_openStartedAt!) &&
              !p.timestamp.isBefore(recentClosedCutoff) &&
              p.confidence >= config.recoveryRecentClosedMinConfidence);

      if (isCurrentStrongClosed || hasRecentStrongClosed) {
        _openStartedAt = null;
        _currentState = DriverAlertState.alarm;
        _closedStartedAt ??= currentNow;
        final closedDuration = currentNow.difference(_closedStartedAt!);

        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: true,
          shouldStopAlarm: false,
          message: '🚨 انتبه! تم اكتشاف نوم أثناء القيادة!',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
          isRecovering: false,
        );
      }

      // 3. Open evaluation:
      if (prediction.state == EyeState.open &&
          prediction.confidence >= config.minimumOpenConfidence) {
        _closedStartedAt = null;
        _openStartedAt ??= currentNow;
      }

      final openDuration = _openStartedAt != null
          ? currentNow.difference(_openStartedAt!)
          : Duration.zero;
      final windowSpan = activeWindow.isNotEmpty
          ? currentNow.difference(activeWindow.first.timestamp)
          : Duration.zero;
      final bool durationMet = openDuration >= config.recoveryThreshold ||
          (windowSpan >= config.recoveryWindowDuration && _openStartedAt != null);

      // openRatio >= recoveryMinOpenRatio (0.70)
      final bool openRatioMet = openRatio >= config.recoveryMinOpenRatio;

      // Last 3 valid predictions: at least 2 are OPEN
      final validPredictions = activeWindow.where((p) => !p.isUnknown).toList();
      final last3 = validPredictions.length >= 3
          ? validPredictions.sublist(validPredictions.length - 3)
          : validPredictions;
      final int openInLast3 = last3.where((p) => p.isOpen).length;
      final bool recentOpenMet = last3.isNotEmpty &&
          (last3.length >= 3 ? openInLast3 >= 2 : openInLast3 >= 1);

      // EMA open confidence >= 0.60
      final bool emaMet = _emaOpenConfidence >= config.recoveryMinEmaConfidence;

      // Unknown ratio is within acceptable limits (<= 0.40)
      final bool unknownMet = unknownRatio <= config.recoveryMaxUnknownRatio;

      if (durationMet && openRatioMet && recentOpenMet && emaMet && unknownMet) {
        // FULL RECOVERY CONFIRMED! Transition to NORMAL
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
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
          isRecovering: false,
        );
      } else {
        // Still in recovery confirmation window
        // Transition ALARM -> RECOVERING when sustained open evidence emerges (> 200ms or openRatio >= 0.50)
        if (_openStartedAt != null &&
            (openDuration >= const Duration(milliseconds: 200) || openRatio >= 0.50)) {
          _currentState = DriverAlertState.recovering;
        } else {
          _currentState = DriverAlertState.alarm;
        }

        return _buildResult(
          continuousClosed: Duration.zero,
          continuousOpen: openDuration,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: true,
          shouldStopAlarm: false,
          message: 'جاري تأكيد استيقاظ السائق...',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
          isRecovering: _currentState == DriverAlertState.recovering,
        );
      }
    }

    // 3. NORMAL MONITORING (NON-ALARM) FLOW
    if (prediction.state == EyeState.closed) {
      if (prediction.confidence < config.minimumClosedConfidence) {
        // Ambiguous closed reading: debounce away
        return _buildResult(
          continuousClosed: _calculateDuration(_closedStartedAt, currentNow),
          continuousOpen: _calculateDuration(_openStartedAt, currentNow),
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: 'مراقبة العينين...',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      }

      // Confirmed closed eye prediction
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
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      } else if (closedDuration >= config.drowsyThreshold || _perclosCalculator.isWarningLevel) {
        _currentState = DriverAlertState.drowsy;
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: '⚠️ تحذير: علامات نعاس وإجهاد!',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      } else if (closedDuration >= config.watchingThreshold) {
        _currentState = DriverAlertState.watching;
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: 'مراقبة العينين...',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      } else {
        // Natural blink (< 350ms)
        return _buildResult(
          continuousClosed: closedDuration,
          continuousOpen: Duration.zero,
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: 'رمش طبيعي',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      }
    } else {
      // Confirmed OPEN eye prediction
      if (prediction.confidence < config.minimumOpenConfidence) {
        return _buildResult(
          continuousClosed: _calculateDuration(_closedStartedAt, currentNow),
          continuousOpen: _calculateDuration(_openStartedAt, currentNow),
          perclos: perclos,
          isHeadNod: isHeadNodding,
          shouldTriggerAlarm: false,
          shouldStopAlarm: false,
          message: 'جاري تأكيد حالة العينين...',
          openRatio: openRatio,
          closedRatio: closedRatio,
          unknownRatio: unknownRatio,
          emaOpenConfidence: _emaOpenConfidence,
        );
      }

      _closedStartedAt = null;
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
        openRatio: openRatio,
        closedRatio: closedRatio,
        unknownRatio: unknownRatio,
        emaOpenConfidence: _emaOpenConfidence,
      );
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
    double openRatio = 0.0,
    double closedRatio = 0.0,
    double unknownRatio = 0.0,
    double emaOpenConfidence = 0.0,
    bool isRecovering = false,
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
      openRatio: openRatio,
      closedRatio: closedRatio,
      unknownRatio: unknownRatio,
      emaOpenConfidence: emaOpenConfidence,
      isRecovering: isRecovering,
    );
  }
}
