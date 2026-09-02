import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/app/theme/app_typography.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';

class SafetyDisclaimerDialog extends StatelessWidget {
  const SafetyDisclaimerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SafetyDisclaimerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(
        Icons.shield_outlined,
        color: AppColors.primaryCyan,
        size: 48,
      ),
      title: const Text(
        'إخلاء المسؤولية وسلامة القيادة',
        style: AppTypography.headline,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.watchingAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.watchingAmber),
              ),
              child: const Text(
                AppConstants.safetyDisclaimerText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '• التطبيق يستخدم الكاميرا الأمامية والذكاء الاصطناعي على الجهاز بدون إنترنت.\n'
              '• في حال شعورك بالنعاس أو الإجهاد، يُرجى التوقف في مكان آمن فوراً وأخذ قسط من الراحة.\n'
              '• يُنصح باستثناء التطبيق من قيود توفير طاقة البطارية لضمان عدم إيقافه بالخلفية أثناء القيادة.\n'
              '• يرجى تثبيت الهاتف في حامل مخصص على لوحة القيادة بحيث تكون العينان واضحتين.',
              style: AppTypography.body,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'أوافق وأتعهد بالقيادة بأمان',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
