import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driving_hud_screen.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/safety_disclaimer_screen.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/alert_banner_overlay.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/camera_feed_view.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/driver_status_card.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/primary_action_button.dart';

class DriverMonitorScreen extends StatefulWidget {
  const DriverMonitorScreen({super.key});

  @override
  State<DriverMonitorScreen> createState() => _DriverMonitorScreenState();
}

class _DriverMonitorScreenState extends State<DriverMonitorScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DrowsinessDetectionProvider>();
      provider.initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<DrowsinessDetectionProvider>().handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showBatteryExemptionDialog(BuildContext context, DrowsinessDetectionProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.battery_alert_rounded, color: AppColors.watchingAmber),
            SizedBox(width: 8),
            Text('استثناء قيود البطارية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Safe Drive Monitor يحتاج إلى استمرار المراقبة أثناء الرحلة.\n\nقد تقوم قيود البطارية في Android بإيقاف الكاميرا أو المعالجة في الخلفية.\n\nلرفع موثوقية مراقبة السائق، يمكنك السماح للتطبيق بالعمل دون قيود البطارية أثناء جلسات القيادة.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('لاحقاً (LATER)', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.openBatterySettings();
            },
            child: const Text('إعدادات الجهاز (OEM)', style: TextStyle(color: AppColors.primaryCyan)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.watchingAmber),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.requestIgnoreBatteryOptimizations();
            },
            child: const Text('سماح (ALLOW)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DrowsinessDetectionProvider>(
      builder: (context, provider, child) {
        final isAlarm = provider.alertState.isAlarm;

        return Scaffold(
          backgroundColor:
              isAlarm ? const Color(0xFF2A0909) : AppColors.background,
          appBar: AppBar(
            backgroundColor:
                isAlarm ? AppColors.alarmRed : AppColors.surface,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car_filled, color: AppColors.primaryCyan),
                SizedBox(width: 8),
                Text(
                  'مراقبة يقظة السائق',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              // Test Alarm action button
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryCyan),
                tooltip: 'فحص الإنذار الصوتي والاهتزاز (Test Alarm)',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري تشغيل تجربة الإنذار الصوتي والاهتزاز لمدة ثانيتين...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  await provider.testAlarm();
                },
              ),
              if (provider.isMonitoring)
                IconButton(
                  icon: Icon(
                    provider.isPowerSaverMode
                        ? Icons.energy_savings_leaf
                        : Icons.energy_savings_leaf_outlined,
                    color: provider.isPowerSaverMode
                        ? AppColors.normalGreen
                        : AppColors.primaryCyan,
                  ),
                  tooltip: provider.isPowerSaverMode
                      ? 'وضع توفير الطاقة مفعّل'
                      : 'تفعيل وضع توفير الطاقة (OLED Saver)',
                  onPressed: provider.togglePowerSaverMode,
                ),
              IconButton(
                icon: const Icon(Icons.speed_rounded, color: AppColors.primaryCyan),
                tooltip: 'وضع القيادة المظلمة (HUD Mode)',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DrivingHudScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                tooltip: 'إرشادات السلامة',
                onPressed: () => SafetyDisclaimerDialog.show(context),
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double screenHeight = constraints.maxHeight;
                    final double cameraHeight = (screenHeight * 0.44).clamp(200.0, 360.0);

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight - 20),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Battery Optimization Exemption Banner with Explanatory Dialog
                              if (!provider.isIgnoringBatteryOptimizations)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.watchingAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.watchingAmber.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.battery_alert_rounded,
                                        color: AppColors.watchingAmber,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'لرفع موثوقية المراقبة بالخلفية، يمكنك استثناء التطبيق من قيود البطارية.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () => _showBatteryExemptionDialog(context, provider),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          backgroundColor: AppColors.watchingAmber.withValues(alpha: 0.25),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'تفاصيل',
                                          style: TextStyle(
                                            color: AppColors.watchingAmber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // System Health & Watchdog Issue Banner (Never Fail Silently)
                              if (provider.monitoringHealth != MonitoringHealth.healthy)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: provider.monitoringHealth.isFailed
                                        ? AppColors.alarmRed.withValues(alpha: 0.2)
                                        : AppColors.watchingAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.monitoringHealth.isFailed
                                          ? AppColors.alarmRed
                                          : AppColors.watchingAmber,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        provider.monitoringHealth.isFailed
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline,
                                        color: provider.monitoringHealth.isFailed
                                            ? AppColors.alarmRed
                                            : AppColors.watchingAmber,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${provider.monitoringHealth.arabicLabel}: ${provider.monitoringIssue.arabicDescription}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: provider.monitoringHealth.isFailed
                                                ? AppColors.alarmRed
                                                : AppColors.watchingAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Alert Banner Overlay for Drowsiness
                              AlertBannerOverlay(
                                alertState: provider.alertState,
                                isMonitoring: provider.isMonitoring,
                              ),
                              const SizedBox(height: 10),

                              // Camera Feed Preview with dynamic responsive height
                              SizedBox(
                                height: cameraHeight,
                                child: CameraFeedView(
                                  controller: provider.cameraController,
                                  isInitialized: provider.isInitialized,
                                  isMonitoring: provider.isMonitoring,
                                  hasDriverFace: provider.hasValidDriverFace,
                                  isLowLight: provider.isLowLight,
                                  isPowerSaverMode: provider.isPowerSaverMode,
                                  onTogglePowerSaver: provider.togglePowerSaverMode,
                                  alertState: provider.alertState,
                                  lastPrediction: provider.lastPrediction,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Driver Status Card with PERCLOS & Head Nod indicator
                              DriverStatusCard(
                                prediction: provider.lastPrediction,
                                statusMessage: provider.statusMessage,
                                isMonitoring: provider.isMonitoring,
                                perclosPercentage: provider.perclosPercentage,
                                isHeadNodDetected: provider.isHeadNodDetected,
                              ),
                              const Spacer(),
                              const SizedBox(height: 10),

                              // Start / Stop Primary Action Button
                              PrimaryActionButton(
                                isMonitoring: provider.isMonitoring,
                                onPressed: () {
                                  if (provider.isMonitoring) {
                                    provider.stopMonitoring();
                                  } else {
                                    provider.startMonitoring();
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Dynamic Safe Screen Illumination Fallback (Red/Amber) for critical low light
              if (provider.screenIlluminationOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xFFFF5722).withValues(alpha: provider.screenIlluminationOpacity),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
