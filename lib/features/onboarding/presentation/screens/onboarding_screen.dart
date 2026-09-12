import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart';
import 'package:safe_drive_monitor/features/onboarding/data/services/onboarding_preferences_service.dart';
import 'package:safe_drive_monitor/features/onboarding/domain/models/onboarding_page_data.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/animations/privacy_protection_animation.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/animations/safe_rest_animation.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/animations/smart_monitoring_animation.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/animations/welcome_drive_animation.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/widgets/onboarding_page_indicator.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/widgets/onboarding_page_widget.dart';

/// The 4-page onboarding flow introducing DriveAlert features and safety guidelines.
class OnboardingScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const OnboardingScreen({
    super.key,
    this.isFirstLaunch = true,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _safetyAgreementAccepted = false;

  static const List<OnboardingPageData> _pages = [
    // Page 1: Welcome
    OnboardingPageData(
      titleAr: 'مرحبًا بك في DriveAlert',
      titleEn: 'Welcome to DriveAlert',
      descriptionAr:
          'DriveAlert يساعدك على مراقبة علامات النعاس أثناء القيادة باستخدام الكاميرا الأمامية، وينبهك عندما يكتشف إغلاق العينين لفترة غير طبيعية.',
      descriptionEn:
          'DriveAlert helps monitor drowsiness signs while driving using the front camera, alerting you when eyes remain closed longer than normal.',
    ),
    // Page 2: Smart Monitoring
    OnboardingPageData(
      titleAr: 'المراقبة الذكية',
      titleEn: 'Smart Monitoring',
      descriptionAr:
          'يراقب DriveAlert حالة عينيك أثناء القيادة ويحلل علامات النعاس في الوقت الحقيقي، ليعطيك تنبيهًا عند الحاجة.',
      descriptionEn:
          'DriveAlert observes eye state and analyzes fatigue indicators in real time to deliver prompt alerts whenever needed.',
    ),
    // Page 3: Privacy
    OnboardingPageData(
      titleAr: 'خصوصيتك أولًا',
      titleEn: 'Privacy First',
      descriptionAr:
          'تتم معالجة المراقبة على جهازك بالكامل. لا يحتاج DriveAlert إلى حفظ صور وجهك أثناء القيادة حتى يقوم بوظيفته الأساسية.',
      descriptionEn:
          'All monitoring is processed 100% on your device. DriveAlert does not store face images during driving to perform its core duty.',
      footnoteAr: 'معالجة محلية بالكامل • لا تسجيل • خصوصية مطلقة',
      footnoteEn: 'Fully On-Device • No Video Storage • Complete Privacy',
    ),
    // Page 4: Safety Agreement
    OnboardingPageData(
      titleAr: 'تنبيه مهم للسلامة',
      titleEn: 'Important Safety Notice',
      descriptionAr:
          'DriveAlert أداة مساعدة فقط، ولا يغني عن النوم الكافي أو التركيز أثناء القيادة.\n\nإذا شعرت بالنعاس أو الإرهاق، توقف في مكان آمن وخذ قسطًا من الراحة قبل مواصلة القيادة.',
      descriptionEn:
          'DriveAlert is an assistance tool only and does not replace adequate sleep or focused driving.\n\nIf you feel drowsy or fatigued, stop safely and rest before continuing.',
      footnoteAr:
          'لا تعتمد على التطبيق كبديل عن القيادة الآمنة أو الراحة المناسبة.',
      footnoteEn:
          'Do not rely on the app as a substitute for safe driving or adequate rest.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// Skip jumps directly to Page 4 (the Safety Agreement page) - cannot bypass agreement!
  void _skipToSafetyPage() {
    _goToPage(3);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _completeOnboarding() async {
    if (widget.isFirstLaunch) {
      await OnboardingPreferencesService.setOnboardingCompleted(completed: true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverMonitorScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (!widget.isFirstLaunch)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                tooltip: isArabic ? 'رجوع' : 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          // Skip button on top-right (unless on the final page)
          if (!isLastPage)
            TextButton(
              onPressed: _skipToSafetyPage,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: Text(
                isArabic ? 'تخطي' : 'Skip',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. PageView containing all 4 steps
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Page 1
                  OnboardingPageWidget(
                    data: _pages[0],
                    illustration: WelcomeDriveAnimation(
                      isActive: _currentPage == 0,
                    ),
                  ),
                  // Page 2
                  OnboardingPageWidget(
                    data: _pages[1],
                    illustration: SmartMonitoringAnimation(
                      isActive: _currentPage == 1,
                    ),
                  ),
                  // Page 3
                  OnboardingPageWidget(
                    data: _pages[2],
                    illustration: PrivacyProtectionAnimation(
                      isActive: _currentPage == 2,
                    ),
                  ),
                  // Page 4: Safety Agreement
                  OnboardingPageWidget(
                    data: _pages[3],
                    illustration: SafeRestAnimation(
                      isActive: _currentPage == 3,
                    ),
                    customBottomWidget: _buildSafetyAgreementBox(isArabic),
                  ),
                ],
              ),
            ),

            // 2. Bottom Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
              child: isLastPage
                  ? _buildLastPageButton(isArabic)
                  : _buildNormalBottomBar(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  /// Checkbox box for the safety agreement on Page 4
  Widget _buildSafetyAgreementBox(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: _safetyAgreementAccepted
              ? AppColors.primaryCyan.withValues(alpha: 0.60)
              : const Color(0xFF30363D),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () {
          setState(() {
            _safetyAgreementAccepted = !_safetyAgreementAccepted;
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _safetyAgreementAccepted,
              onChanged: (val) {
                setState(() {
                  _safetyAgreementAccepted = val ?? false;
                });
              },
              activeColor: AppColors.primaryCyan,
              checkColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic
                    ? 'أفهم أن DriveAlert نظام مساعد للسلامة ولا يضمن منع الحوادث، وأنه لا يغني عن النوم الكافي والتركيز أثناء القيادة.'
                    : 'I understand that DriveAlert is a safety assistance tool that does not guarantee accident prevention, nor replace adequate sleep and focused driving.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom navigation bar for pages 0, 1, 2 (Indicator in center, Next on right/leading)
  Widget _buildNormalBottomBar(bool isArabic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Subtle back or spacer
        if (_currentPage > 0)
          IconButton(
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
            tooltip: isArabic ? 'السابق' : 'Previous',
            onPressed: () => _goToPage(_currentPage - 1),
          )
        else
          const SizedBox(width: 40),

        // Indicator
        OnboardingPageIndicator(
          pageCount: _pages.length,
          currentPage: _currentPage,
        ),

        // Next Button
        ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryCyan,
            foregroundColor: const Color(0xFF0D1117),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? 'التالي' : 'Next',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Button on Page 4: "ابدأ الإعداد" (Disabled until safety agreement checked)
  Widget _buildLastPageButton(bool isArabic) {
    final isEnabled = _safetyAgreementAccepted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingPageIndicator(
          pageCount: _pages.length,
          currentPage: _currentPage,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isEnabled ? _completeOnboarding : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              disabledBackgroundColor: const Color(0xFF21262D),
              foregroundColor: const Color(0xFF0D1117),
              disabledForegroundColor: const Color(0xFF484F58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
              elevation: 0,
            ),
            child: Text(
              widget.isFirstLaunch
                  ? (isArabic ? 'ابدأ الإعداد' : 'Start Setup')
                  : (isArabic ? 'تم الفهم والمتابعة' : 'Understood & Continue'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? const Color(0xFF0D1117)
                    : const Color(0xFF8B949E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
