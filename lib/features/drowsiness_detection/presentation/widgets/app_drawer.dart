import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/core/localization/locale_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/providers/drowsiness_detection_provider.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driving_hud_screen.dart';
import 'package:safe_drive_monitor/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:safe_drive_monitor/features/permissions/presentation/screens/permissions_screen.dart';
import 'package:safe_drive_monitor/features/safety/presentation/screens/safety_guidelines_screen.dart';
import 'package:safe_drive_monitor/features/settings/presentation/screens/settings_screen.dart';

/// Navigation Drawer for DriveAlert providing quick access to HUD, Audio Test,
/// Permissions, Safety Guidelines, Onboarding, and Settings.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final provider = Provider.of<DrowsinessDetectionProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceElevated,
                  AppColors.primaryCyan.withValues(alpha: 0.15),
                ],
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.remove_red_eye_rounded,
                        color: AppColors.primaryCyan,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DriveAlert',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            loc.translate('app_subtitle'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Session Status Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: provider.isMonitoring
                        ? AppColors.normalGreen.withValues(alpha: 0.15)
                        : AppColors.primaryCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: provider.isMonitoring
                          ? AppColors.normalGreen.withValues(alpha: 0.4)
                          : AppColors.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isMonitoring
                              ? AppColors.normalGreen
                              : AppColors.primaryCyan,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isMonitoring
                            ? loc.translate('monitoring_active')
                            : loc.translate('monitoring_inactive'),
                        style: TextStyle(
                          color: provider.isMonitoring
                              ? AppColors.normalGreen
                              : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 1. Audio Alarm Test
                _buildDrawerItem(
                  context,
                  icon: Icons.volume_up_rounded,
                  iconColor: AppColors.watchingAmber,
                  title: loc.translate('drawer_test_alarm'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.translate('alarm_test_snack')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    await provider.testAlarm();
                  },
                ),

                // 2. Night Driving HUD Mode
                _buildDrawerItem(
                  context,
                  icon: Icons.speed_rounded,
                  iconColor: AppColors.primaryCyan,
                  title: loc.translate('drawer_hud_mode'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DrivingHudScreen(),
                      ),
                    );
                  },
                ),

                const Divider(color: AppColors.border, height: 16),

                // 3. Permissions Status Screen
                _buildDrawerItem(
                  context,
                  icon: Icons.security_rounded,
                  iconColor: AppColors.normalGreen,
                  title: loc.translate('drawer_permissions'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionsScreen(),
                      ),
                    );
                  },
                ),

                // 4. Safety Guidelines & Disclaimer
                _buildDrawerItem(
                  context,
                  icon: Icons.shield_outlined,
                  iconColor: Colors.deepOrangeAccent,
                  title: loc.translate('drawer_safety_guide'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SafetyGuidelinesScreen(),
                      ),
                    );
                  },
                ),

                // 5. Quick Start / Onboarding
                _buildDrawerItem(
                  context,
                  icon: Icons.menu_book_rounded,
                  iconColor: Colors.purpleAccent,
                  title: loc.translate('drawer_quick_start'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const OnboardingScreen(isFirstLaunch: false),
                      ),
                    );
                  },
                ),

                const Divider(color: AppColors.border, height: 16),

                // 6. Settings & Languages
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  iconColor: AppColors.textPrimary,
                  title: loc.translate('drawer_settings'),
                  trailing: Text(
                    localeProvider.currentLanguage.flag,
                    style: const TextStyle(fontSize: 18),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${loc.translate('version')} ${AppConstants.appVersion}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Offline AI',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
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
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
      onTap: onTap,
    );
  }
}
