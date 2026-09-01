import 'dart:math' as math;
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';

class EyePredictionModel extends EyePrediction {
  const EyePredictionModel({
    required super.state,
    required super.openScore,
    required super.closedScore,
    required super.confidence,
    required super.inferenceTime,
    required super.timestamp,
  });

  /// Computes numerically stable softmax over two logit scores.
  static List<double> computeStableSoftmax(double logit0, double logit1) {
    final double maxLogit = math.max(logit0, logit1);
    final double exp0 = math.exp(logit0 - maxLogit);
    final double exp1 = math.exp(logit1 - maxLogit);
    final double sumExp = exp0 + exp1;
    if (sumExp == 0.0 || sumExp.isNaN) {
      return const [0.5, 0.5];
    }
    return [exp0 / sumExp, exp1 / sumExp];
  }

  /// Returns `true` when [a] and [b] already look like a probability
  /// distribution: both inside [0,1] (small epsilon) and summing to ≈ 1.
  static bool looksLikeProbabilities(double a, double b) {
    const double eps = 0.02;
    if (a < -eps || a > 1 + eps || b < -eps || b > 1 + eps) return false;
    return (a + b - 1.0).abs() <= 0.05;
  }

  /// Normalizes a raw 2-class output `[open, closed]` into a probability pair
  /// according to [outputMode]. `auto` inspects the values and only applies
  /// softmax when they are clearly not already probabilities.
  static List<double> normalizeScores(
    double rawOpen,
    double rawClosed,
    ModelOutputMode outputMode,
  ) {
    switch (outputMode) {
      case ModelOutputMode.probabilities:
        return [rawOpen, rawClosed];
      case ModelOutputMode.logits:
        return computeStableSoftmax(rawOpen, rawClosed);
      case ModelOutputMode.auto:
        if (looksLikeProbabilities(rawOpen, rawClosed)) {
          return [rawOpen, rawClosed];
        }
        return computeStableSoftmax(rawOpen, rawClosed);
    }
  }

  /// Creates an [EyePredictionModel] from raw TFLite model 2-class output: `[openScore, closedScore]`.
  factory EyePredictionModel.fromRawOutput({
    required List<double> rawOutput,
    required Duration inferenceTime,
    required DateTime timestamp,
    ModelOutputMode outputMode = ModelOutputMode.auto,
    double minOpenConfidence = 0.55,
    double minClosedConfidence = 0.55,
    double? minConfidenceThreshold,
  }) {
    if (rawOutput.length < 2) {
      return EyePredictionModel(
        state: EyeState.unknown,
        openScore: 0.0,
        closedScore: 0.0,
        confidence: 0.0,
        inferenceTime: inferenceTime,
        timestamp: timestamp,
      );
    }

    final double rawOpen = rawOutput[ModelLabels.open];
    final double rawClosed = rawOutput[ModelLabels.closed];

    final normalized = normalizeScores(rawOpen, rawClosed, outputMode);
    final double openScore = normalized[0];
    final double closedScore = normalized[1];

    final double effectiveOpenThresh = minConfidenceThreshold ?? minOpenConfidence;
    final double effectiveClosedThresh = minConfidenceThreshold ?? minClosedConfidence;

    final EyeState state;
    final double confidence;

    if (closedScore > openScore) {
      confidence = closedScore;
      if (confidence >= effectiveClosedThresh) {
        state = EyeState.closed;
      } else {
        state = EyeState.unknown;
      }
    } else {
      confidence = openScore;
      if (confidence >= effectiveOpenThresh) {
        state = EyeState.open;
      } else {
        state = EyeState.unknown;
      }
    }

    return EyePredictionModel(
      state: state,
      openScore: openScore,
      closedScore: closedScore,
      confidence: confidence,
      inferenceTime: inferenceTime,
      timestamp: timestamp,
    );
  }
}
