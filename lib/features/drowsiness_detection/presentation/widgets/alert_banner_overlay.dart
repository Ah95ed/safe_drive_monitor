import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/app/theme/app_typography.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';

class AlertBannerOverlay extends StatefulWidget {
  final DriverAlertState alertState;
  final bool isMonitoring;

  const AlertBannerOverlay({
    super.key,
    required this.alertState,
    required this.isMonitoring,
  });

  @override
  State<AlertBannerOverlay> createState() => _AlertBannerOverlayState();
}

class _AlertBannerOverlayState extends State<AlertBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMonitoring) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_outline, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'المراقبة متوقفة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    switch (widget.alertState) {
      case DriverAlertState.alarm:
        return ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.alarmRed,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.alarmRedGlow,
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 10),
                    Text('🚨 WAKE UP!', style: AppTypography.heroAlert),
                    SizedBox(width: 10),
                    Icon(Icons.warning_rounded, color: Colors.white, size: 36),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'استيقظ فوراً! العينان مغمضتان!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );

      case DriverAlertState.drowsy:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.drowsyOrange,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: AppColors.drowsyOrangeGlow,
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                '⚠️ تحذير: علامات نعاس!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );

      case DriverAlertState.watching:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.watchingAmber.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, color: Colors.black87, size: 22),
              SizedBox(width: 8),
              Text(
                'مراقبة إغلاق العينين...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );

      case DriverAlertState.normal:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.normalGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.normalGreen),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.normalGreen, size: 22),
              SizedBox(width: 8),
              Text(
                '● السائق متيقظ (Awake) - القيادة آمنة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.normalGreen,
                ),
              ),
            ],
          ),
        );
    }
  }
}
