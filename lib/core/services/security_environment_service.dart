import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// Data model representing device and runtime security assessment.
class SecurityEnvironmentAssessment {
  final bool isRooted;
  final bool isDebuggerAttached;
  final bool isHookingDetected;
  final int riskScore;

  const SecurityEnvironmentAssessment({
    required this.isRooted,
    required this.isDebuggerAttached,
    required this.isHookingDetected,
    required this.riskScore,
  });

  bool get isHighRisk => riskScore >= 50;

  factory SecurityEnvironmentAssessment.safe() {
    return const SecurityEnvironmentAssessment(
      isRooted: false,
      isDebuggerAttached: false,
      isHookingDetected: false,
      riskScore: 0,
    );
  }

  factory SecurityEnvironmentAssessment.fromMap(Map<dynamic, dynamic> map) {
    return SecurityEnvironmentAssessment(
      isRooted: (map['isRooted'] as bool?) ?? false,
      isDebuggerAttached: (map['isDebuggerAttached'] as bool?) ?? false,
      isHookingDetected: (map['isHookingDetected'] as bool?) ?? false,
      riskScore: (map['riskScore'] as int?) ?? 0,
    );
  }
}

/// Service providing security signals, hardware Keystore keys, and attestation data.
class SecurityEnvironmentService {
  static const String _tag = 'SecurityEnvironment';
  static const MethodChannel _channel = MethodChannel(
    'com.eyewatchdriver.eye.safe_drive_monitor/foreground_service',
  );

  /// Evaluates device and runtime integrity signals (Root, Debugger, Hooking).
  static Future<SecurityEnvironmentAssessment> evaluateEnvironment() async {
    try {
      final dynamic result = await _channel.invokeMethod('checkSecurityEnvironment');
      if (result is Map) {
        final assessment = SecurityEnvironmentAssessment.fromMap(result);
        if (assessment.isHighRisk) {
          AppLogger.warning(
            _tag,
            'High-risk security environment detected: root=${assessment.isRooted}, debugger=${assessment.isDebuggerAttached}, hooking=${assessment.isHookingDetected}, score=${assessment.riskScore}',
          );
        }
        return assessment;
      }
    } on PlatformException catch (e) {
      AppLogger.warning(_tag, 'Platform checkSecurityEnvironment failed: ${e.message}');
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to perform security environment check: $e');
    }
    return SecurityEnvironmentAssessment.safe();
  }
}
