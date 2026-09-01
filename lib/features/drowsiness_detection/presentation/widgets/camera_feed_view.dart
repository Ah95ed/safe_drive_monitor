import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';

class CameraFeedView extends StatelessWidget {
  final CameraController? controller;
  final bool isInitialized;
  final bool isMonitoring;
  final bool hasDriverFace;
  final bool isLowLight;
  final DriverAlertState alertState;

  const CameraFeedView({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.isMonitoring,
    this.hasDriverFace = false,
    this.isLowLight = false,
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
          if (isInitialized && controller != null && controller!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.previewSize?.height ?? 480,
                  height: controller!.value.previewSize?.width ?? 640,
                  child: CameraPreview(controller!),
                ),
              ),
            )
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

          // Dynamic Driver Face & Eye Reticle Overlay
          if (isMonitoring)
            Center(
              child: Container(
                width: 220,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasDriverFace
                        ? AppColors.normalGreen.withValues(alpha: 0.7)
                        : AppColors.watchingAmber.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasDriverFace
                                ? AppColors.normalGreen
                                : AppColors.watchingAmber,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasDriverFace
                                  ? Icons.face_retouching_natural
                                  : Icons.face_unlock_rounded,
                              size: 14,
                              color: hasDriverFace
                                  ? AppColors.normalGreen
                                  : AppColors.watchingAmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasDriverFace
                                  ? 'تم قفل تتبع وجه السائق'
                                  : 'جاري البحث عن وجه السائق...',
                              style: TextStyle(
                                color: hasDriverFace
                                    ? AppColors.normalGreen
                                    : AppColors.watchingAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: hasDriverFace
                            ? AppColors.normalGreen
                            : AppColors.watchingAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Low-Light / Night Driving Warning Badge
          if (isMonitoring && isLowLight)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.watchingAmber, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nightlight_round, size: 13, color: AppColors.watchingAmber),
                    SizedBox(width: 4),
                    Text(
                      'إضاءة خافتة (Low-Light)',
                      style: TextStyle(
                        color: AppColors.watchingAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
