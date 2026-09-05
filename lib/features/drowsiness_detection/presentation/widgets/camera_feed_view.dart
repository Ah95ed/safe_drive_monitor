import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/eye_prediction.dart';

class CameraFeedView extends StatelessWidget {
  final CameraController? controller;
  final bool isInitialized;
  final bool isMonitoring;
  final bool hasDriverFace;
  final bool isLowLight;
  final bool isPowerSaverMode;
  final VoidCallback? onTogglePowerSaver;
  final DriverAlertState alertState;
  final EyePrediction? lastPrediction;

  const CameraFeedView({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.isMonitoring,
    this.hasDriverFace = false,
    this.isLowLight = false,
    this.isPowerSaverMode = false,
    this.onTogglePowerSaver,
    required this.alertState,
    this.lastPrediction,
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
          ),
        ];
        break;
      case DriverAlertState.recovering:
        borderColor = AppColors.watchingAmber;
        glow = const [
          BoxShadow(
            color: AppColors.watchingAmberGlow,
            blurRadius: 18,
            spreadRadius: 3,
          ),
        ];
        break;
      case DriverAlertState.drowsy:
        borderColor = AppColors.drowsyOrange;
        glow = const [
          BoxShadow(
            color: AppColors.drowsyOrangeGlow,
            blurRadius: 18,
            spreadRadius: 4,
          ),
        ];
        break;
      case DriverAlertState.watching:
        borderColor = AppColors.watchingAmber;
        glow = const [
          BoxShadow(
            color: AppColors.watchingAmberGlow,
            blurRadius: 14,
            spreadRadius: 2,
          ),
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
                ),
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
          if (isPowerSaverMode && !alertState.isAlarm)
            // Deep OLED / AMOLED Black Screen - CameraPreview unmounted!
            // Consumes 0W on black pixels, stops GPU OpenGL texture render & cools phone!
            GestureDetector(
              onTap: onTogglePowerSaver,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.normalGreen.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.normalGreen.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.energy_savings_leaf_rounded,
                          color: AppColors.normalGreen,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'وضع توفير الطاقة النشط (OLED Saver)',
                        style: TextStyle(
                          color: AppColors.normalGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'معاينة الكاميرا متوقفة لتبريد الهاتف وتوفير البطارية\nالمراقبة بالذكاء الاصطناعي والإنذار يعملان بالخلفية 100%\n(انقر في أي مكان للعودة للمعاينة المباشرة)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (isInitialized &&
              controller != null &&
              controller!.value.isInitialized)
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

          // Dynamic Driver Face & Eye Reticle Overlay (Only in live view)
          if (isMonitoring && !isPowerSaverMode)
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
                          horizontal: 10,
                          vertical: 4,
                        ),
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
          // Power Saver Toggle Button (Top Left)
          if (isMonitoring)
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTogglePowerSaver,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPowerSaverMode
                            ? AppColors.normalGreen
                            : AppColors.primaryCyan.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPowerSaverMode
                              ? Icons.visibility
                              : Icons.energy_savings_leaf_outlined,
                          size: 13,
                          color: isPowerSaverMode
                              ? AppColors.normalGreen
                              : AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isPowerSaverMode ? 'إظهار الكاميرا' : 'توفير الطاقة',
                          style: TextStyle(
                            color: isPowerSaverMode
                                ? AppColors.normalGreen
                                : AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Low-Light / Night Driving Warning Badge
          if (isMonitoring && isLowLight)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.watchingAmber, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      size: 13,
                      color: AppColors.watchingAmber,
                    ),
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
          // Eye State Indicator under camera (تم فتح العين / تم غلق العين)
          if (isMonitoring && lastPrediction != null)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: lastPrediction!.isClosed
                          ? AppColors.alarmRed
                          : lastPrediction!.isOpen
                          ? AppColors.normalGreen
                          : AppColors.watchingAmber,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (lastPrediction!.isClosed
                                    ? AppColors.alarmRed
                                    : lastPrediction!.isOpen
                                    ? AppColors.normalGreen
                                    : AppColors.watchingAmber)
                                .withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lastPrediction!.isClosed
                            ? Icons.visibility_off
                            : lastPrediction!.isOpen
                            ? Icons.visibility
                            : Icons.help_outline,
                        size: 20,
                        color: lastPrediction!.isClosed
                            ? AppColors.alarmRed
                            : lastPrediction!.isOpen
                            ? AppColors.normalGreen
                            : AppColors.watchingAmber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lastPrediction!.isClosed
                            ? 'تم غلق العين'
                            : lastPrediction!.isOpen
                            ? 'تم فتح العين'
                            : 'جاري فحص العين...',
                        style: TextStyle(
                          color: lastPrediction!.isClosed
                              ? AppColors.alarmRed
                              : lastPrediction!.isOpen
                              ? AppColors.normalGreen
                              : AppColors.watchingAmber,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!lastPrediction!.isUnknown) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(lastPrediction!.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
