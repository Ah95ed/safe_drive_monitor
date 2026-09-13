import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/constants/model_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/driver_alert_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/domain/entities/monitoring_health_state.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/alert_banner_overlay.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/app_drawer.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/camera_feed_view.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/driver_status_card.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/widgets/primary_action_button.dart';

class DriverMonitorScreen extends StatefulWidget {
  const DriverMonitorScreen({super.key});

  @override
  State<DriverMonitorScreen> createState() => _DriverMonitorScreenState();
}

class _DriverMonitorScreenState extends State<DriverMonitorScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DrowsinessDetectionProvider>();
      provider.initialize();
    });
  }

  void _showBatteryExemptionDialog(BuildContext context, DrowsinessDetectionProvider provider) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.battery_alert_rounded, color: AppColors.watchingAmber),
            const SizedBox(width: 8),
            Text(loc.translate('battery_dialog_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          loc.translate('battery_dialog_body'),
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.translate('dialog_later'), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.openBatterySettings();
            },
            child: Text(loc.translate('dialog_oem_settings'), style: const TextStyle(color: AppColors.primaryCyan)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.watchingAmber),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.requestIgnoreBatteryOptimizations();
            },
            child: Text(loc.translate('dialog_allow'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

        return PopScope(
          canPop: !provider.isMonitoring,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (provider.isMonitoring) {
              await provider.moveTaskToBackground();
            }
          },
          child: Scaffold(
            backgroundColor:
                isAlarm ? const Color(0xFF2A0909) : AppColors.background,
          drawer: const AppDrawer(),
          appBar: AppBar(
            backgroundColor:
                isAlarm ? AppColors.alarmRed : AppColors.surface,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.primaryCyan),
                tooltip: context.tr('menu'),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car_filled, color: AppColors.primaryCyan, size: 22),
                const SizedBox(width: 8),
                Text(
                  context.tr('app_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
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
                                      Expanded(
                                        child: Text(
                                          context.tr('battery_banner_text'),
                                          style: const TextStyle(
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
                                        child: Text(
                                          context.tr('battery_banner_details'),
                                          style: const TextStyle(
                                            color: AppColors.watchingAmber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                               // AI Model Lifecycle Status Banner
                              if (!provider.isModelReady)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: provider.modelState.isFailed
                                        ? AppColors.alarmRed.withValues(alpha: 0.15)
                                        : AppColors.primaryCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: provider.modelState.isFailed
                                          ? AppColors.alarmRed.withValues(alpha: 0.6)
                                          : AppColors.primaryCyan.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (provider.modelState.isBusy)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: AppColors.primaryCyan,
                                          ),
                                        )
                                      else if (provider.modelState.isFailed)
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.alarmRed,
                                          size: 20,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          context.trStatus(provider.modelState.arabicLabel),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: provider.modelState.isFailed
                                                ? AppColors.alarmRed
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (provider.modelState.isFailed)
                                        TextButton.icon(
                                          onPressed: () => provider.retryModelBootstrap(),
                                          icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryCyan),
                                          label: Text(
                                            context.tr('retry'),
                                            style: const TextStyle(
                                              color: AppColors.primaryCyan,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
                                          '${context.trStatus(provider.monitoringHealth.arabicLabel)}: ${context.trStatus(provider.monitoringIssue.arabicDescription)}',
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

                              // Thermal Pressure Status Banner
                              if (provider.thermalState.isThermalPressure)
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
                                        Icons.thermostat_rounded,
                                        color: AppColors.watchingAmber,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${context.tr('thermal_protection_prefix')} (${context.trStatus(provider.thermalState.arabicLabel)})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
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
                                  isInitialized: provider.isInitialized && provider.isModelReady,
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
                                isEnabled: provider.isModelReady && provider.isInitialized,
                                onPressed: (provider.isModelReady && provider.isInitialized)
                                    ? () {
                                        if (provider.isMonitoring) {
                                          provider.stopMonitoring();
                                        } else {
                                          provider.startMonitoring();
                                        }
                                      }
                                    : null,
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
        ),
      );
    },
  );
}
}
