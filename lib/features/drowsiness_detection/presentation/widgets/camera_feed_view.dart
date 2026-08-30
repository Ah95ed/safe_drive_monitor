import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';

class CameraFeedView extends StatelessWidget {
  final CameraController? controller;
  final bool isInitialized;
  final bool isMonitoring;
  final DriverAlertState alertState;

  const CameraFeedView({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.isMonitoring,
    required this.alertState,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    List<BoxShadow> glow;

    switch (alertState) {
      case DriverAlertState.alarm:
        borderColor = AppColors.alarmRed;
        glow = const [
          BoxShadow(
            color: AppColors.alarmRedGlow,
            blurRadius: 24,
            spreadRadius: 6,
          )
        ];
        break;
      case DriverAlertState.drowsy:
        borderColor = AppColors.drowsyOrange;
        glow = const [
          BoxShadow(
            color: AppColors.drowsyOrangeGlow,
            blurRadius: 18,
            spreadRadius: 4,
          )
        ];
        break;
      case DriverAlertState.watching:
        borderColor = AppColors.watchingAmber;
        glow = const [
          BoxShadow(
            color: AppColors.watchingAmberGlow,
            blurRadius: 14,
            spreadRadius: 2,
          )
        ];
        break;
      case DriverAlertState.normal:
        borderColor = isMonitoring ? AppColors.normalGreen : AppColors.border;
        glow = isMonitoring
            ? const [
                BoxShadow(
                  color: AppColors.normalGreenGlow,
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: glow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isInitialized && controller != null)
            CameraPreview(controller!)
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryCyan),
                  SizedBox(height: 16),
                  Text(
                    'جاري تجهيز الكاميرا...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          // Center Reticle Overlay (Indicating 224x224 Legacy Crop zone)
          if (isMonitoring)
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
