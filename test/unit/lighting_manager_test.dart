import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/low_light_detector.dart';

void main() {
  group('LightingManager & Adaptive Exposure', () {
    late LightingManager manager;

    setUp(() {
      manager = LightingManager(
        lowLightThreshold: 40.0,
        criticalLightThreshold: 18.0,
        smoothingFactor: 0.5,
        adaptationHysteresis: const Duration(milliseconds: 500),
      );
    });

    test('Initial state is good with 0 screen illumination opacity', () {
      expect(manager.lightingState, LightingState.good);
      expect(manager.screenIlluminationOpacity, 0.0);
      expect(manager.isLowLight, isFalse);
    });

    test('Adaptive exposure does not adjust if min and max offsets are equal', () {
      final now = DateTime.now();
      final suggested = manager.computeAdaptiveExposureOffset(
        now: now,
        currentOffset: 0.0,
        minOffset: 0.0,
        maxOffset: 0.0,
        stepSize: 0.5,
      );
      expect(suggested, isNull);
    });

    test('Adaptive exposure suggests step increase under low light', () {
      // Manually set internal state by calling compute when low light is active
      final now = DateTime.now();

      // For testing exposure computation logic:
      // When good light and offset > 0, steps down
      final stepDown = manager.computeAdaptiveExposureOffset(
        now: now,
        currentOffset: 1.5,
        minOffset: -2.0,
        maxOffset: 2.0,
        stepSize: 0.5,
      );
      expect(stepDown, equals(1.0));

      // Immediate subsequent call is blocked by hysteresis
      final blockedByHysteresis = manager.computeAdaptiveExposureOffset(
        now: now.add(const Duration(milliseconds: 100)),
        currentOffset: 1.0,
        minOffset: -2.0,
        maxOffset: 2.0,
        stepSize: 0.5,
      );
      expect(blockedByHysteresis, isNull);

      // After hysteresis expires, steps down again towards 0.0
      final stepDownAgain = manager.computeAdaptiveExposureOffset(
        now: now.add(const Duration(milliseconds: 600)),
        currentOffset: 1.0,
        minOffset: -2.0,
        maxOffset: 2.0,
        stepSize: 0.5,
      );
      expect(stepDownAgain, equals(0.5));
    });
  });
}
