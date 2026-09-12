import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/thermal_manager_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_face.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/services/adaptive_inference_scheduler.dart';

void main() {
  late AdaptiveInferenceScheduler scheduler;
  final now = DateTime(2026, 9, 12, 12, 0, 0);

  final dummyDriverFace = DriverFace(
    trackingId: 1,
    boundingBox: const Rect.fromLTWH(100, 100, 200, 200),
    eyeRoi: const Rect.fromLTWH(120, 140, 160, 60),
    detectedAt: now,
  );

  final openPredictionHighConf = EyePrediction(
    state: EyeState.open,
    openScore: 0.95,
    closedScore: 0.05,
    confidence: 0.95,
    inferenceTime: const Duration(milliseconds: 15),
    timestamp: now,
  );

  final closedPredictionHighConf = EyePrediction(
    state: EyeState.closed,
    openScore: 0.05,
    closedScore: 0.95,
    confidence: 0.95,
    inferenceTime: const Duration(milliseconds: 15),
    timestamp: now,
  );

  final unstablePrediction = EyePrediction(
    state: EyeState.open,
    openScore: 0.52,
    closedScore: 0.48,
    confidence: 0.52,
    inferenceTime: const Duration(milliseconds: 15),
    timestamp: now,
  );

  setUp(() {
    scheduler = AdaptiveInferenceScheduler(
      minimumSafeInferenceHz: 4.0,
      maxInferenceHz: 15.0,
    );
  });

  group('AdaptiveInferenceScheduler - State & Rate Switching', () {
    test('State A: Stable awake with high confidence uses 4 Hz (minimumSafeInferenceHz)', () {
      final schedule = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );

      expect(schedule.targetInferenceHz, equals(4.0));
      expect(schedule.inferenceInterval.inMilliseconds, inInclusiveRange(240, 260));
      expect(schedule.targetFaceDetectionHz, equals(1.8)); // Low ML Kit frequency
      expect(schedule.isSafetyOverrideActive, isFalse);
    });

    test('State B: Fluctuating or low confidence increases rate to 8 Hz', () {
      final schedule = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: unstablePrediction,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );

      expect(schedule.targetInferenceHz, equals(8.0));
      expect(schedule.inferenceInterval.inMilliseconds, equals(125));
    });

    test('State C: First valid CLOSED immediately upshifts to 15 Hz', () {
      final schedule = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: closedPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );

      expect(schedule.targetInferenceHz, equals(15.0));
      expect(schedule.debugReason, equals('FIRST_VALID_CLOSED'));
      expect(schedule.targetFaceDetectionHz, equals(4.0)); // Fast face tracking on first closed
    });

    test('State D: Watching state uses 12 Hz', () {
      final schedule = scheduler.evaluate(
        alertState: DriverAlertState.watching,
        lastPrediction: closedPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );

      expect(schedule.targetInferenceHz, equals(12.0));
      expect(schedule.targetFaceDetectionHz, equals(4.0));
    });

    test('State E & F: Drowsy and Alarm states use maximum 15 Hz', () {
      final schedDrowsy = scheduler.evaluate(
        alertState: DriverAlertState.drowsy,
        lastPrediction: closedPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );
      expect(schedDrowsy.targetInferenceHz, equals(15.0));

      final schedAlarm = scheduler.evaluate(
        alertState: DriverAlertState.alarm,
        lastPrediction: closedPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );
      expect(schedAlarm.targetInferenceHz, equals(15.0));
    });

    test('State G & Hysteresis: Recovers with 15 Hz -> 8 Hz -> 5 Hz -> 4 Hz stepwise downshift', () {
      // 1. Recovering state -> 15 Hz
      final schedRec = scheduler.evaluate(
        alertState: DriverAlertState.recovering,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );
      expect(schedRec.targetInferenceHz, equals(15.0));

      // 2. Normal at +500ms after recovery -> 8 Hz (Hysteresis Step 1)
      final schedStep1 = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now.add(const Duration(milliseconds: 500)),
      );
      expect(schedStep1.targetInferenceHz, equals(8.0));
      expect(schedStep1.debugReason, equals('HYSTERESIS_STEP_1'));

      // 3. Normal at +1800ms after recovery -> 5 Hz (Hysteresis Step 2)
      final schedStep2 = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now.add(const Duration(milliseconds: 1800)),
      );
      expect(schedStep2.targetInferenceHz, equals(5.0));
      expect(schedStep2.debugReason, equals('HYSTERESIS_STEP_2'));

      // 4. Normal at +3000ms after recovery -> 4 Hz (Stable Normal baseline)
      final schedStep3 = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now.add(const Duration(milliseconds: 3000)),
      );
      expect(schedStep3.targetInferenceHz, equals(4.0));
      expect(schedStep3.debugReason, equals('STABLE_NORMAL'));
    });

    test('Safety Override activates under severe thermal pressure if drowsiness is detected', () {
      // Normal state under severe thermal pressure -> 4 Hz baseline
      final schedCooling = scheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.severe,
        now: now,
      );
      expect(schedCooling.targetInferenceHz, equals(4.0));
      expect(schedCooling.targetFaceDetectionHz, equals(1.0)); // Throttled ML Kit
      expect(schedCooling.isSafetyOverrideActive, isFalse);

      // BUT if driver becomes Drowsy under severe thermal pressure:
      // SAFETY OVERRIDE forces 15 Hz!
      final schedDrowsyHot = scheduler.evaluate(
        alertState: DriverAlertState.drowsy,
        lastPrediction: closedPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.severe,
        now: now,
      );
      expect(schedDrowsyHot.targetInferenceHz, equals(15.0));
      expect(schedDrowsyHot.isSafetyOverrideActive, isTrue);
    });

    test('Safety Floor ensures target frequency never falls below minimumSafeInferenceHz', () {
      final customScheduler = AdaptiveInferenceScheduler(minimumSafeInferenceHz: 5.0);
      final schedule = customScheduler.evaluate(
        alertState: DriverAlertState.normal,
        lastPrediction: openPredictionHighConf,
        driverFace: dummyDriverFace,
        isFaceTrackingStable: true,
        isRoiFresh: true,
        isLowLight: false,
        thermalState: DeviceThermalState.none,
        now: now,
      );
      expect(schedule.targetInferenceHz, greaterThanOrEqualTo(5.0));
    });
  });
}
