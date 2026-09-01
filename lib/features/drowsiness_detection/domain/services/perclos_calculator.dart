import 'dart:collection';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

class _EyeSample {
  final DateTime timestamp;
  final bool isClosed;
  final double closedScore;

  const _EyeSample(this.timestamp, this.isClosed, this.closedScore);
}

/// Computes PERCLOS (Percentage of Eye Closure over Time) across a rolling time window.
/// PERCLOS is the gold-standard metric for driver drowsiness in automotive safety.
class PerclosCalculator {
  final Duration windowDuration;
  final double warningThreshold; // e.g. 0.15 (15%)
  final double alarmThreshold;   // e.g. 0.25 (25%)

  /// Minimum time span the rolling window must cover before PERCLOS levels are
  /// trusted. Without this, the first blink yields ratio == 1.0 and would
  /// instantly force drowsy/alarm and block recovery. PERCLOS is a *gradual*
  /// fatigue signal, so it must warm up first.
  final Duration minReadyDuration;

  /// Minimum number of valid samples required before PERCLOS levels are trusted.
  final int minReadySamples;

  final DoubleLinkedQueue<_EyeSample> _samples = DoubleLinkedQueue<_EyeSample>();

  PerclosCalculator({
    this.windowDuration = const Duration(seconds: 60),
    this.warningThreshold = 0.15,
    this.alarmThreshold = 0.25,
    this.minReadyDuration = const Duration(seconds: 20),
    this.minReadySamples = 30,
  });

  /// Total number of valid samples in the current sliding window.
  int get sampleCount => _samples.length;

  /// Whether the rolling window has accumulated enough data for the PERCLOS
  /// ratio to be meaningful. Levels are suppressed until this is true.
  bool get isReady {
    if (_samples.length < minReadySamples) return false;
    final span = _samples.last.timestamp.difference(_samples.first.timestamp);
    return span >= minReadyDuration;
  }

  /// Resets the sliding window.
  void reset() {
    _samples.clear();
  }

  /// Adds an eye prediction and returns the updated PERCLOS ratio [0.0 - 1.0].
  double addPrediction(EyePrediction prediction) {
    if (prediction.isUnknown) {
      return currentPerclos;
    }

    final now = prediction.timestamp;
    _samples.addLast(_EyeSample(now, prediction.isClosed, prediction.closedScore));

    // Prune samples older than the rolling window
    _pruneOldSamples(now);

    return currentPerclos;
  }

  /// Current calculated PERCLOS ratio [0.0 - 1.0].
  double get currentPerclos {
    if (_samples.isEmpty) return 0.0;

    int closedCount = 0;
    for (final sample in _samples) {
      if (sample.isClosed) {
        closedCount++;
      }
    }

    return closedCount / _samples.length;
  }

  /// Current PERCLOS as a percentage [0% - 100%].
  double get currentPerclosPercentage => currentPerclos * 100.0;

  /// Indicates whether the current PERCLOS exceeds the alarm threshold.
  /// Always false until the window is [isReady].
  bool get isAlarmLevel => isReady && currentPerclos >= alarmThreshold;

  /// Indicates whether the current PERCLOS exceeds the warning threshold.
  /// Always false until the window is [isReady].
  bool get isWarningLevel => isReady && currentPerclos >= warningThreshold;

  void _pruneOldSamples(DateTime now) {
    final cutoff = now.subtract(windowDuration);
    while (_samples.isNotEmpty && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeFirst();
    }
  }
}
