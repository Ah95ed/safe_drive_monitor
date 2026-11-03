import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/errors/app_exceptions.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/inference_worker.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/detection_pipeline.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/model_output_mode.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/roi_strategy.dart';

void main() {
  group('IsolateEyeStateClassifier Unit Tests (Section A3)', () {
    late IsolateEyeStateClassifier classifier;

    setUp(() {
      classifier = IsolateEyeStateClassifier(
        minOpenConfidence: 0.55,
        minClosedConfidence: 0.50,
      );
    });

    tearDown(() async {
      await classifier.dispose();
    });

    test('Initial state: isLoaded and isReady are false', () {
      expect(classifier.isLoaded, isFalse);
      expect(classifier.isReady, isFalse);
    });

    test('Calling classifyFloat32 before load throws ModelLoadException', () async {
      final buffer = Float32List(224 * 224 * 3);
      expect(
        () => classifier.classifyFloat32(buffer),
        throwsA(isA<ModelLoadException>()),
      );
    });

    test('Configuration knobs (minOpenConfidence, minClosedConfidence, outputMode) can be updated', () {
      classifier.minOpenConfidence = 0.60;
      classifier.minClosedConfidence = 0.45;
      classifier.outputMode = ModelOutputMode.probabilities;
      classifier.pipeline = DetectionPipeline.faceAware;
      classifier.roiStrategy = RoiStrategy.eyeBand;
      classifier.invertYoloClasses = true;

      expect(classifier.minOpenConfidence, equals(0.60));
      expect(classifier.minClosedConfidence, equals(0.45));
      expect(classifier.outputMode, equals(ModelOutputMode.probabilities));
      expect(classifier.pipeline, equals(DetectionPipeline.faceAware));
      expect(classifier.invertYoloClasses, isTrue);
    });

    test('Dispose is safe and idempotent when called repeatedly', () async {
      await classifier.dispose();
      await classifier.dispose();
      expect(classifier.isReady, isFalse);
    });
  });
}
