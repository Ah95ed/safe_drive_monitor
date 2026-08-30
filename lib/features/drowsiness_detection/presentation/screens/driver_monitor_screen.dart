import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/safety_disclaimer_screen.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/alert_banner_overlay.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/camera_feed_view.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/debug_metrics_panel.dart';
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
                icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                tooltip: 'إرشادات السلامة',
                onPressed: () => SafetyDisclaimerDialog.show(context),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Alert Banner Overlay
                  AlertBannerOverlay(
                    alertState: provider.alertState,
                    isMonitoring: provider.isMonitoring,
                  ),
                  const SizedBox(height: 14),

                  // Camera Feed Preview
                  SizedBox(
                    height: 320,
                    child: CameraFeedView(
                      controller: provider.cameraController,
                      isInitialized: provider.isInitialized,
                      isMonitoring: provider.isMonitoring,
                      alertState: provider.alertState,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Driver Status Card
                  DriverStatusCard(
                    prediction: provider.lastPrediction,
                    statusMessage: provider.statusMessage,
                    isMonitoring: provider.isMonitoring,
                  ),
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 14),

                  // Debug Metrics Panel (in debug mode)
                  if (kDebugMode) ...[
                    const DebugMetricsPanel(),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
