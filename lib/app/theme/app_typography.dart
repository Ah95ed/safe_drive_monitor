import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle heroAlert = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 1.2,
    height: 1.1,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle statusTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle metricLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    fontFamily: 'monospace',
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryCyan,
    fontFamily: 'monospace',
  );
}
