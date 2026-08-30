import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_theme.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart';

class SafeDriveApp extends StatelessWidget {
  const SafeDriveApp({super.key});

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
        home: const DriverMonitorScreen(),
      ),
    );
  }
}
