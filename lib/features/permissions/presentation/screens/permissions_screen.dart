import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/core/services/battery_optimization_service.dart';

/// Screen for auditing, inspecting and requesting device and OS permissions.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final BatteryOptimizationService _batteryService =
      AppBatteryOptimizationService();

  PermissionStatus? _cameraStatus;
  PermissionStatus? _notificationStatus;
  bool _isBatteryOptIgnored = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);
    try {
      final camera = await Permission.camera.status;
      final notification = await Permission.notification.status;
      final battery = await _batteryService.isIgnoringBatteryOptimizations();

      if (mounted) {
        setState(() {
          _cameraStatus = camera;
          _notificationStatus = notification;
          _isBatteryOptIgnored = battery;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    setState(() => _cameraStatus = status);
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    setState(() => _notificationStatus = status);
  }

  Future<void> _requestBatteryOptimization() async {
    await _batteryService.openBatterySettings();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final allGranted = (_cameraStatus?.isGranted ?? false) &&
        (_notificationStatus?.isGranted ?? false) &&
        _isBatteryOptIgnored;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          loc.translate('permissions_title'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryCyan),
            tooltip: loc.translate('perm_refresh_btn'),
            onPressed: _checkAllPermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: allGranted
                        ? AppColors.normalGreen.withValues(alpha: 0.12)
                        : AppColors.primaryCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: allGranted
                          ? AppColors.normalGreen.withValues(alpha: 0.4)
                          : AppColors.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allGranted
                            ? Icons.verified_user_rounded
                            : Icons.security_rounded,
                        color: allGranted
                            ? AppColors.normalGreen
                            : AppColors.primaryCyan,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allGranted
                                  ? loc.translate('perm_granted')
                                  : loc.translate('permissions_title'),
                              style: TextStyle(
                                color: allGranted
                                    ? AppColors.normalGreen
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.translate('permissions_desc'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Camera Permission Card
                _buildPermissionCard(
                  icon: Icons.camera_alt_rounded,
                  title: loc.translate('perm_camera_title'),
                  description: loc.translate('perm_camera_desc'),
                  isGranted: _cameraStatus?.isGranted ?? false,
                  isPermanentlyDenied:
                      _cameraStatus?.isPermanentlyDenied ?? false,
                  onRequest: _requestCamera,
                  onOpenSettings: () => openAppSettings(),
                ),
                const SizedBox(height: 14),

                // 2. Notification Permission Card
                _buildPermissionCard(
                  icon: Icons.notifications_active_rounded,
                  title: loc.translate('perm_notifications_title'),
                  description: loc.translate('perm_notifications_desc'),
                  isGranted: _notificationStatus?.isGranted ?? false,
                  isPermanentlyDenied:
                      _notificationStatus?.isPermanentlyDenied ?? false,
                  onRequest: _requestNotification,
                  onOpenSettings: () => openAppSettings(),
                ),
                const SizedBox(height: 14),

                // 3. Battery Optimization Card
                _buildPermissionCard(
                  icon: Icons.battery_charging_full_rounded,
                  title: loc.translate('perm_battery_title'),
                  description: loc.translate('perm_battery_desc'),
                  isGranted: _isBatteryOptIgnored,
                  isPermanentlyDenied: false,
                  onRequest: _requestBatteryOptimization,
                  onOpenSettings: _requestBatteryOptimization,
                ),
                const SizedBox(height: 24),

                // Global Open Settings Button
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryCyan,
                    side: const BorderSide(color: AppColors.primaryCyan),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.settings, size: 20),
                  label: Text(
                    loc.translate('perm_settings_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isPermanentlyDenied,
    required VoidCallback onRequest,
    required VoidCallback onOpenSettings,
  }) {
    final loc = context.loc;
    final statusColor = isGranted
        ? AppColors.normalGreen
        : (isPermanentlyDenied ? AppColors.alarmRed : AppColors.watchingAmber);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isGranted
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isGranted
                              ? loc.translate('perm_granted')
                              : (isPermanentlyDenied
                                  ? loc.translate('perm_restricted')
                                  : loc.translate('perm_denied')),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isPermanentlyDenied ? onOpenSettings : onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  isPermanentlyDenied ? Icons.settings : Icons.touch_app,
                  size: 16,
                ),
                label: Text(
                  isPermanentlyDenied
                      ? loc.translate('perm_settings_btn')
                      : loc.translate('perm_request_btn'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
