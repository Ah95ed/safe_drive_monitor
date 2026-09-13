import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/core/localization/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleProvider & AppLocalizations Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default language is Arabic (ar) and is RTL', () {
      final provider = LocaleProvider();
      expect(provider.currentLocale.languageCode, equals('ar'));
      expect(provider.currentLanguage, equals(AppLanguage.arabic));
      expect(provider.isRtl, isTrue);
    });

    test('Switching to English updates locale, language, and LTR', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.english);

      expect(provider.currentLocale.languageCode, equals('en'));
      expect(provider.currentLanguage, equals(AppLanguage.english));
      expect(provider.isRtl, isFalse);
    });

    test('Switching to French updates locale to fr', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.french);

      expect(provider.currentLocale.languageCode, equals('fr'));
      expect(provider.currentLanguage, equals(AppLanguage.french));
      expect(provider.isRtl, isFalse);
    });

    test('Switching to Spanish updates locale to es', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.spanish);

      expect(provider.currentLocale.languageCode, equals('es'));
      expect(provider.currentLanguage, equals(AppLanguage.spanish));
      expect(provider.isRtl, isFalse);
    });

    test('Translations exist across all 4 supported languages', () {
      const testKeys = [
        'app_title',
        'drawer_home',
        'drawer_test_alarm',
        'drawer_hud_mode',
        'drawer_permissions',
        'drawer_safety_guide',
        'drawer_settings',
        'permissions_title',
        'safety_title',
        'settings_title',
      ];

      for (final langCode in ['ar', 'en', 'fr', 'es']) {
        final loc = AppLocalizations(Locale(langCode));
        for (final key in testKeys) {
          final translated = loc.translate(key);
          expect(translated, isNotEmpty, reason: 'Missing translation for $key in $langCode');
          expect(translated, isNot(equals(key)), reason: 'Translation fell back to key for $key in $langCode');
        }
      }
    });

    test('Saved language persists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'user_selected_language': 'fr'});
      final provider = LocaleProvider();
      // Allow async _loadSavedLocale to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.currentLocale.languageCode, equals('fr'));
      expect(provider.currentLanguage, equals(AppLanguage.french));
    });
  });
}
