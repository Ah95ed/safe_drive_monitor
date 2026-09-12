import 'package:flutter/widgets.dart';

/// Data model representing an individual onboarding step.
class OnboardingPageData {
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String? footnoteAr;
  final String? footnoteEn;

  const OnboardingPageData({
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    this.footnoteAr,
    this.footnoteEn,
  });

  String title(BuildContext context) {
    final isArabic =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    return isArabic ? titleAr : titleEn;
  }

  String description(BuildContext context) {
    final isArabic =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    return isArabic ? descriptionAr : descriptionEn;
  }

  String? footnote(BuildContext context) {
    final isArabic =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    return isArabic ? footnoteAr : footnoteEn;
  }
}
