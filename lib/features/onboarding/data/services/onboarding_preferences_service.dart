import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting and retrieving Onboarding completion status.
class OnboardingPreferencesService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  /// Returns true if the user has completed the onboarding flow and agreed to safety terms.
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Sets the onboarding completion status.
  static Future<void> setOnboardingCompleted({bool completed = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, completed);
  }

  /// Resets the onboarding status (useful for development/testing).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
  }
}
