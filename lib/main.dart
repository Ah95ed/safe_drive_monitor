import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_drive_monitor/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for driving holder consistency
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const SafeDriveApp());
}
