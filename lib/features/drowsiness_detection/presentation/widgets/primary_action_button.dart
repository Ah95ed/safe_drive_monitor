import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';

class PrimaryActionButton extends StatelessWidget {
  final bool isMonitoring;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const PrimaryActionButton({
    super.key,
    required this.isMonitoring,
    this.isEnabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isMonitoring
              ? AppColors.alarmRed
              : (isEnabled ? AppColors.normalGreen : Colors.grey.shade800),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade800,
          disabledForegroundColor: Colors.grey.shade500,
          elevation: isEnabled ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(
          isMonitoring ? Icons.stop_circle : Icons.play_arrow_rounded,
          size: 28,
        ),
        label: Text(
          isMonitoring ? loc.translate('btn_stop_monitoring') : loc.translate('btn_start_monitoring'),
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
