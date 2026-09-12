import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/app/theme/app_theme.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart';
import 'package:safe_drive_monitor/features/onboarding/data/services/onboarding_preferences_service.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/screens/onboarding_screen.dart';

class SafeDriveApp extends StatelessWidget {
  final bool? initialOnboardingCompleted;

  const SafeDriveApp({
    super.key,
    this.initialOnboardingCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DrowsinessDetectionProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        home: initialOnboardingCompleted != null
            ? (initialOnboardingCompleted!
                ? const DriverMonitorScreen()
                : const OnboardingScreen(isFirstLaunch: true))
            : FutureBuilder<bool>(
                future: OnboardingPreferencesService.isOnboardingCompleted(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: AppColors.background,
                      body: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    );
                  }
                  final completed = snapshot.data ?? false;
                  if (completed) {
                    return const DriverMonitorScreen();
                  }
                  return const OnboardingScreen(isFirstLaunch: true);
                },
              ),
      ),
    );
  }
}
