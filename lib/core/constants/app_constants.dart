import 'package:camera/camera.dart';

/// Centralized application constants.
class AppConstants {
  AppConstants._();

  static const String appTitle = 'Safe Drive Monitor';
  static const String appVersion = '1.0.2';
  static const String alarmSoundAsset = 'sounds/alarm.mp3';
  static const String technicalWarningSoundAsset = 'sounds/warning.mp3';

  static const ResolutionPreset defaultCameraResolution =
      ResolutionPreset.medium;

  /// Balanced Eco inference interval (~4.5 FPS) in normal driving, saving battery & cooling device.
  static const Duration defaultInferenceInterval = Duration(milliseconds: 220);

  /// Low-rate face ROI detection interval (2 Hz = 500ms)
  static const Duration faceDetectionInterval = Duration(milliseconds: 500);

  /// Stale face ROI threshold (2 seconds)
  static const Duration roiStaleTimeout = Duration(milliseconds: 2000);

  /// Watchdog stall thresholds
  static const Duration frameWatchdogTimeout = Duration(milliseconds: 3000);
  static const Duration cameraStallTimeout = Duration(milliseconds: 2500);
  static const Duration inferenceStallTimeout = Duration(milliseconds: 7000);
  static const Duration faceLostDegradedTimeout = Duration(milliseconds: 2000);
  static const Duration backgroundGraceWindow = Duration(seconds: 5);

  /// Lighting analysis thresholds on Y-plane (0..255)
  static const double lowLightThreshold = 40.0;
  static const double criticalDarknessThreshold = 15.0;

  /// Disclaimer displayed to driver on startup.
  static const String safetyDisclaimerText =
      'هذا التطبيق أداة مساعدة لتنبيه السائق ولا يضمن اكتشاف جميع حالات النعاس ولا يغني عن التوقف والراحة عند الشعور بالتعب.';
}
