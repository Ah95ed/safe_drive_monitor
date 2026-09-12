import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/onboarding/data/services/onboarding_preferences_service.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    bool isFirstLaunch = true,
    bool disableAnimations = false,
    double textScale = 1.0,
    Locale locale = const Locale('ar'),
  }) {
    return ChangeNotifierProvider(
      create: (_) => DrowsinessDetectionProvider(),
      child: MaterialApp(
        locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
          size: const Size(400, 800),
        ),
        child: Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: OnboardingScreen(isFirstLaunch: isFirstLaunch),
        ),
      ),
    ),
  );
}

  Future<void> pumpFrames(WidgetTester tester, [int count = 10]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  group('OnboardingScreen Flow & Interactions', () {
    testWidgets('Renders Page 1 with title, description, and Next button',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مرحبًا بك في DriveAlert'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
    });

    testWidgets('Tapping "تخطي" jumps directly to Page 4 (Safety Agreement)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "تخطي" (Skip)
      await tester.tap(find.text('تخطي'));
      await pumpFrames(tester);

      // Should land on Page 4 (Safety warning)
      expect(find.text('تنبيه مهم للسلامة'), findsOneWidget);
      expect(find.text('ابدأ الإعداد'), findsOneWidget);

      // Verify "ابدأ الإعداد" button is DISABLED by default
      final buttonFinder = find.widgetWithText(ElevatedButton, 'ابدأ الإعداد');
      expect(buttonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('Safety Agreement checkbox enables "ابدأ الإعداد" button',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Jump to page 4
      await tester.tap(find.text('تخطي'));
      await pumpFrames(tester);

      // Button is disabled initially
      var button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ابدأ الإعداد'),
      );
      expect(button.onPressed, isNull);

      // Scroll until the Checkbox is visible and tap it
      await tester.ensureVisible(find.byType(Checkbox));
      await pumpFrames(tester, 5);
      await tester.tap(find.byType(Checkbox));
      await pumpFrames(tester, 5);

      // Button must now be ENABLED
      button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ابدأ الإعداد'),
      );
      expect(button.onPressed, isNotNull);

      // Tapping the enabled button completes onboarding and persists flag
      await tester.tap(find.widgetWithText(ElevatedButton, 'ابدأ الإعداد'));
      await pumpFrames(tester, 5);

      expect(await OnboardingPreferencesService.isOnboardingCompleted(), isTrue);
    });

    testWidgets('Sequential page navigation via "التالي"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Page 1
      expect(find.text('مرحبًا بك في DriveAlert'), findsOneWidget);

      // Advance to Page 2
      await tester.tap(find.text('التالي'));
      await pumpFrames(tester);
      expect(find.text('المراقبة الذكية'), findsOneWidget);

      // Advance to Page 3
      await tester.tap(find.text('التالي'));
      await pumpFrames(tester);
      expect(find.text('خصوصيتك أولًا'), findsOneWidget);

      // Advance to Page 4
      await tester.tap(find.text('التالي'));
      await pumpFrames(tester);
      expect(find.text('تنبيه مهم للسلامة'), findsOneWidget);
    });

    testWidgets('Manual review mode (isFirstLaunch = false) displays back button',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(isFirstLaunch: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Reduced motion mode (disableAnimations = true) renders cleanly without ticker errors',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مرحبًا بك في DriveAlert'), findsOneWidget);
    });

    testWidgets('Accessibility text scaling (1.8x) renders without overflow errors',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(textScale: 1.8));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مرحبًا بك في DriveAlert'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
