import 'package:flutter/material.dart';

class AppConstants {
  // إعدادات النموذج
  static const String modelPath = "assets/models/drowsiness.tflite";
  static const String labelsPath = "assets/models/labels.txt";

  // إعدادات الصوت
  static const String alarmSoundPath = "assets/sounds/alarm.mp3";

  // إعدادات الكاميرا
  static const CameraResolution cameraResolution = CameraResolution.medium;

  // إعدادات الكشف عن النعاس
  static const int drowsyThreshold =
      5; // عدد الإطارات المتتالية المغلقة لتشغيل التنبيه

  // إعدادات واجهة المستخدم
  static const Color alertColor = Colors.red;
  static const Color normalColor = Colors.black;
  static const TextStyle alertTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
}

enum CameraResolution { low, medium, high }
