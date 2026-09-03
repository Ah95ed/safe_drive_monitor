import 'package:camera/camera.dart';

/// Centralized application constants.
class AppConstants {
  AppConstants._();

  static const String appTitle = 'Safe Drive Monitor';
  static const String alarmSoundAsset = 'sounds/alarm.mp3';
  static const String technicalWarningSoundAsset = 'sounds/alarm.mp3';

  static const ResolutionPreset defaultCameraResolution =
      ResolutionPreset.medium;

  /// Balanced Eco inference interval (~4.5 FPS) in normal driving, saving battery & cooling device.
  static const Duration defaultInferenceInterval = Duration(milliseconds: 220);

  /// Watchdog stall thresholds
  static const Duration cameraStallTimeout = Duration(milliseconds: 2500);
  static const Duration inferenceStallTimeout = Duration(milliseconds: 3000);
  static const Duration faceLostDegradedTimeout = Duration(milliseconds: 3500);

  /// Lighting analysis thresholds on Y-plane (0..255)
  static const double lowLightThreshold = 40.0;
  static const double criticalDarknessThreshold = 18.0;

  /// Disclaimer displayed to driver on startup.
  static const String safetyDisclaimerText =
      'هذا التطبيق أداة مساعدة لتنبيه السائق ولا يضمن اكتشاف جميع حالات النعاس ولا يغني عن التوقف والراحة عند الشعور بالتعب.';
}
