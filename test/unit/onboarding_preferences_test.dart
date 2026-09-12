import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/features/onboarding/data/services/onboarding_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Defaults to false on first launch', () async {
      final isCompleted = await OnboardingPreferencesService.isOnboardingCompleted();
      expect(isCompleted, isFalse);
    });

    test('Persists true when onboarding is completed', () async {
      await OnboardingPreferencesService.setOnboardingCompleted(completed: true);
      final isCompleted = await OnboardingPreferencesService.isOnboardingCompleted();
      expect(isCompleted, isTrue);
    });

    test('Reset clears the onboarding completion status', () async {
      await OnboardingPreferencesService.setOnboardingCompleted(completed: true);
      expect(await OnboardingPreferencesService.isOnboardingCompleted(), isTrue);

      await OnboardingPreferencesService.reset();
      expect(await OnboardingPreferencesService.isOnboardingCompleted(), isFalse);
    });
  });
}
