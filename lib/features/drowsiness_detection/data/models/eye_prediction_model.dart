import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

class EyePredictionModel extends EyePrediction {
  const EyePredictionModel({
    required super.state,
    required super.openScore,
    required super.closedScore,
    required super.confidence,
    required super.inferenceTime,
    required super.timestamp,
  });

  /// Creates an [EyePredictionModel] from raw TFLite model 2-class output: `[openScore, closedScore]`.
  factory EyePredictionModel.fromRawOutput({
    required List<double> rawOutput,
    required Duration inferenceTime,
    required DateTime timestamp,
    double minConfidenceThreshold = 0.55,
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

    final double openScore = rawOutput[ModelLabels.open];
    final double closedScore = rawOutput[ModelLabels.closed];

    // Compute softmax/confidence
    final double maxScore = openScore > closedScore ? openScore : closedScore;
    final double total = openScore + closedScore;
    final double confidence = total > 0 ? (maxScore / total) : maxScore;

    EyeState state;
    if (confidence < minConfidenceThreshold) {
      state = EyeState.unknown;
    } else if (closedScore > openScore) {
      state = EyeState.closed;
    } else {
      state = EyeState.open;
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
