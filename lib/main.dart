import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/app/app.dart';
import 'package:safe_drive_monitor/features/onboarding/data/services/onboarding_preferences_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        log(
          'Flutter error: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        log('Platform channel error: $error', error: error, stackTrace: stack);
        return true; // Handled to prevent crash on platform message channel teardowns
      };

      // Lock to portrait orientation for driving holder consistency
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      final onboardingCompleted =
          await OnboardingPreferencesService.isOnboardingCompleted();

      runApp(SafeDriveApp(initialOnboardingCompleted: onboardingCompleted));
    },
    (error, stack) async {
      log('Zoned error: $error', error: error, stackTrace: stack);
    },
  );
}
