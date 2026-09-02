import 'package:camera/camera.dart';

/// Centralized application constants.
class AppConstants {
  AppConstants._();

  static const String appTitle = 'Safe Drive Monitor';
  static const String alarmSoundAsset = 'sounds/alarm.mp3';

  static const ResolutionPreset defaultCameraResolution =
      ResolutionPreset.medium;

  /// Balanced Eco inference interval (~4.5 FPS) in normal driving, saving battery & cooling device.
  static const Duration defaultInferenceInterval = Duration(milliseconds: 220);

  /// Disclaimer displayed to driver on startup.
  static const String safetyDisclaimerText =
      'هذا التطبيق أداة مساعدة لتنبيه السائق ولا يضمن اكتشاف جميع حالات النعاس ولا يغني عن التوقف والراحة عند الشعور بالتعب.';
}
