import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
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
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenHeight = constraints.maxHeight;
                // Dynamically adjust camera height to screen height (prevents any overflow)
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
                          // Alert Banner Overlay
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
        );
      },
    );
  }
}
