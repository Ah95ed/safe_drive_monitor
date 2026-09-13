import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/core/services/security_environment_service.dart';

void main() {
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
