import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/core/utils/app_logger.dart';

/// State management provider for application language and text direction.
class LocaleProvider extends ChangeNotifier {
  static const String _tag = 'LocaleProvider';
  static const String _prefLanguageKey = 'user_selected_language';

  Locale _currentLocale = const Locale('ar');

  Locale get currentLocale => _currentLocale;
  AppLanguage get currentLanguage => AppLanguage.fromCode(_currentLocale.languageCode);
  bool get isRtl => _currentLocale.languageCode == 'ar';

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefLanguageKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        _currentLocale = Locale(savedCode);
        AppLogger.info(_tag, 'Loaded saved locale: $savedCode');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to load saved locale, defaulting to ar: $e');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLocale.languageCode == language.code) return;

    _currentLocale = Locale(language.code);
    AppLogger.info(_tag, 'Setting application language to: ${language.nativeName} (${language.code})');
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLanguageKey, language.code);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to save locale to SharedPreferences: $e');
    }
  }
}
