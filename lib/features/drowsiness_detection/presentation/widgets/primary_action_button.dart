import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

class PrimaryActionButton extends StatelessWidget {
  final bool isMonitoring;
  final VoidCallback onPressed;

  const PrimaryActionButton({
    super.key,
    required this.isMonitoring,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isMonitoring ? AppColors.alarmRed : AppColors.normalGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(
          isMonitoring ? Icons.stop_circle : Icons.play_arrow_rounded,
          size: 28,
        ),
        label: Text(
          isMonitoring ? 'إيقاف المراقبة (STOP)' : 'بدء المراقبة (START MONITORING)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
