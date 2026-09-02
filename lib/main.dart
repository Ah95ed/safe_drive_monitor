import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/app/app.dart';

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

      runApp(const SafeDriveApp());
    },
    (error, stack) async {
      log('Zoned error: $error', error: error, stackTrace: stack);
    },
  );
}
