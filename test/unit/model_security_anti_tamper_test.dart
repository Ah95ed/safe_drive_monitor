import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/constants/model_constants.dart';
import 'package:safe_drive_monitor/core/services/security_environment_service.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/data/services/model_delivery_service.dart';

void main() {
  group('ModelDeliveryService Anti-Tamper & Anti-Rollback', () {
    test('SHA-256 validation accurately verifies matching bytes', () {
      final data = Uint8List.fromList('DriveAlertModelTestData123'.codeUnits);
      final expectedDigest = sha256.convert(data).toString();

      expect(ModelDeliveryService.verifySha256(data, expectedDigest), isTrue);
    });

    test('SHA-256 validation rejects tampered data', () {
      final data = Uint8List.fromList('DriveAlertTamperedData'.codeUnits);
      const expectedDigest =
          '0aa29daecf86e3f42621fc53a1523c10a4dbecb3ec834cce5ff99ce207a998b3';

      expect(ModelDeliveryService.verifySha256(data, expectedDigest), isFalse);
    });

    test('Anti-rollback rejects version downgrades', () {
      expect(
        ModelDeliveryService.validateAntiRollback(
          ModelConstants.minSupportedModelVersion - 1,
        ),
        isFalse,
      );
    });

    test('Anti-rollback accepts equal or higher version upgrades', () {
      expect(
        ModelDeliveryService.validateAntiRollback(
          ModelConstants.currentModelVersion,
        ),
        isTrue,
      );
      expect(
        ModelDeliveryService.validateAntiRollback(
          ModelConstants.currentModelVersion + 1,
        ),
        isTrue,
      );
    });
  });

  group('SecurityEnvironmentService Risk Signals', () {
    test('Correctly assesses safe environment', () {
      final assessment = SecurityEnvironmentAssessment.safe();
      expect(assessment.isRooted, isFalse);
      expect(assessment.isDebuggerAttached, isFalse);
      expect(assessment.isHookingDetected, isFalse);
      expect(assessment.riskScore, equals(0));
      expect(assessment.isHighRisk, isFalse);
    });

    test('Identifies high-risk environment when rooted or hooked', () {
      final assessment = SecurityEnvironmentAssessment.fromMap({
        'isRooted': true,
        'isDebuggerAttached': false,
        'isHookingDetected': true,
        'riskScore': 90,
      });
      expect(assessment.isRooted, isTrue);
      expect(assessment.isHookingDetected, isTrue);
      expect(assessment.isHighRisk, isTrue);
    });
  });
}
