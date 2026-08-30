import 'package:camera/camera.dart';

/// Centralized application constants.
class AppConstants {
  AppConstants._();

  static const String appTitle = 'Safe Drive Monitor';
  static const String alarmSoundAsset = 'sounds/alarm.mp3';

  static const ResolutionPreset defaultCameraResolution =
      ResolutionPreset.medium;

  /// Default inference throttling interval (~6-7 frames/sec).
  static const Duration defaultInferenceInterval = Duration(milliseconds: 150);

  /// Disclaimer displayed to driver on startup.
  static const String safetyDisclaimerText =
      'هذا التطبيق أداة مساعدة لتنبيه السائق ولا يضمن اكتشاف جميع حالات النعاس ولا يغني عن التوقف والراحة عند الشعور بالتعب.';
}
