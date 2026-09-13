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

    test('Default language is Arabic (ar) with Iraqi flag and is RTL', () {
      final provider = LocaleProvider();
      expect(provider.currentLocale.languageCode, equals('ar'));
      expect(provider.currentLanguage, equals(AppLanguage.arabic));
      expect(provider.currentLanguage.flag, equals('🇮🇶'));
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

    test('Switching to Hindi updates locale to hi and flag to India', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.hindi);

      expect(provider.currentLocale.languageCode, equals('hi'));
      expect(provider.currentLanguage, equals(AppLanguage.hindi));
      expect(provider.currentLanguage.flag, equals('🇮🇳'));
      expect(provider.isRtl, isFalse);
    });

    test('Switching to Chinese updates locale to zh and flag to China', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.chinese);

      expect(provider.currentLocale.languageCode, equals('zh'));
      expect(provider.currentLanguage, equals(AppLanguage.chinese));
      expect(provider.currentLanguage.flag, equals('🇨🇳'));
      expect(provider.isRtl, isFalse);
    });

    test('Switching to Japanese updates locale to ja and flag to Japan', () async {
      final provider = LocaleProvider();
      await provider.setLanguage(AppLanguage.japanese);

      expect(provider.currentLocale.languageCode, equals('ja'));
      expect(provider.currentLanguage, equals(AppLanguage.japanese));
      expect(provider.currentLanguage.flag, equals('🇯🇵'));
      expect(provider.isRtl, isFalse);
    });

    test('Translations exist across all 7 supported languages', () {
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
        // Newly added UI keys
        'battery_banner_text',
        'battery_banner_details',
        'battery_dialog_title',
        'monitoring_stopped',
        'alert_banner_wake_up',
        'status_inactive',
        'status_eyes_open',
        'confidence_label',
        'perclos_label',
        'btn_start_monitoring',
        'btn_stop_monitoring',
        'camera_preparing',
        'face_locked',
        'hud_driver_awake',
        'hud_alarm',
        'hud_perclos_label',
      ];

      for (final langCode in ['ar', 'en', 'fr', 'es', 'hi', 'zh', 'ja']) {
        final loc = AppLocalizations(Locale(langCode));
        for (final key in testKeys) {
          final translated = loc.translate(key);
          expect(translated, isNotEmpty, reason: 'Missing translation for $key in $langCode');
          expect(translated, isNot(equals(key)), reason: 'Translation fell back to key for $key in $langCode');
        }

        // Test translateStatus
        final statusMsg = loc.translateStatus('تمت التهيئة بنجاح. اضغط على زر البدء لبدء المراقبة.');
        expect(statusMsg, isNotEmpty);
      }
    });

    test('Saved language persists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'user_selected_language': 'ja'});
      final provider = LocaleProvider();
      // Allow async _loadSavedLocale to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.currentLocale.languageCode, equals('ja'));
      expect(provider.currentLanguage, equals(AppLanguage.japanese));
    });
  });
}
