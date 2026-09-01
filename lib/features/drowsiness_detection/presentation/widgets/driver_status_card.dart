import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/app/theme/app_typography.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

class DriverStatusCard extends StatelessWidget {
  final EyePrediction? prediction;
  final String statusMessage;
  final bool isMonitoring;
  final double perclosPercentage;
  final bool isHeadNodDetected;

  const DriverStatusCard({
    super.key,
    required this.prediction,
    required this.statusMessage,
    required this.isMonitoring,
    this.perclosPercentage = 0.0,
    this.isHeadNodDetected = false,
  });

  @override
  Widget build(BuildContext context) {
    String eyeStateText;
    Color eyeStateColor;
    IconData eyeIcon;

    if (!isMonitoring || prediction == null) {
      eyeStateText = 'غير نشط';
      eyeStateColor = AppColors.textMuted;
      eyeIcon = Icons.remove_red_eye_outlined;
    } else {
      switch (prediction!.state) {
        case EyeState.open:
          eyeStateText = 'العينان مفتوحتان (Open)';
          eyeStateColor = AppColors.normalGreen;
          eyeIcon = Icons.visibility;
          break;
        case EyeState.closed:
          eyeStateText = 'العينان مغمضتان (Closed)';
          eyeStateColor = AppColors.alarmRed;
          eyeIcon = Icons.visibility_off;
          break;
        case EyeState.unknown:
          eyeStateText = 'غير محدد (Unknown)';
          eyeStateColor = AppColors.watchingAmber;
          eyeIcon = Icons.help_outline;
          break;
      }
    }

    final double confidence = prediction?.confidence ?? 0.0;
    final int confidencePercent = (confidence * 100).round();

    Color perclosColor = AppColors.normalGreen;
    if (perclosPercentage >= 25.0) {
      perclosColor = AppColors.alarmRed;
    } else if (perclosPercentage >= 15.0) {
      perclosColor = AppColors.watchingAmber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(eyeIcon, color: eyeStateColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    eyeStateText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: eyeStateColor,
                    ),
                  ),
                ],
              ),
              if (isMonitoring && prediction != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'الثقة: $confidencePercent%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusMessage,
            style: AppTypography.body.copyWith(
              color: isMonitoring ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (isMonitoring) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'مؤشر الإجهاد التراكمي (PERCLOS): ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${perclosPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: perclosColor,
                      ),
                    ),
                  ],
                ),
                if (isHeadNodDetected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.alarmRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.alarmRed, width: 0.8),
                    ),
                    child: const Text(
                      '⚠️ انحناء رأس',
                      style: TextStyle(fontSize: 10, color: AppColors.alarmRed, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (perclosPercentage / 100.0).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(perclosColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
