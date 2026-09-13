import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/constants/app_constants.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';
import 'package:safe_drive_monitor/core/localization/locale_provider.dart';
import 'package:safe_drive_monitor/core/services/security_environment_service.dart';

/// Settings screen for managing application language, inspecting device security status,
/// and reviewing privacy principles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SecurityEnvironmentAssessment? _assessment;

  @override
  void initState() {
    super.initState();
    _loadSecurityAssessment();
  }

  Future<void> _loadSecurityAssessment() async {
    final assessment = await SecurityEnvironmentService.evaluateEnvironment();
    if (mounted) {
      setState(() => _assessment = assessment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          loc.translate('settings_title'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Language Selection Section
          Container(
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
                    const Icon(
                      Icons.language_rounded,
                      color: AppColors.primaryCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.translate('language_section_title'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  loc.translate('language_section_desc'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Language Choices List
                ...AppLanguage.values.map((lang) {
                  final isSelected = localeProvider.currentLanguage == lang;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryCyan.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryCyan
                            : AppColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Text(
                        lang.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        lang.nativeName,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryCyan
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        lang.englishName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryCyan,
                              size: 22,
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                      onTap: () => localeProvider.setLanguage(lang),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Device Security Status Section
          Container(
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
                    const Icon(
                      Icons.security_rounded,
                      color: AppColors.primaryCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.translate('device_security_title'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      (_assessment?.isHighRisk ?? false)
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: (_assessment?.isHighRisk ?? false)
                          ? AppColors.alarmRed
                          : AppColors.normalGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_assessment?.isHighRisk ?? false)
                            ? loc.translate('security_status_warning')
                            : loc.translate('security_status_safe'),
                        style: TextStyle(
                          color: (_assessment?.isHighRisk ?? false)
                              ? AppColors.alarmRed
                              : AppColors.normalGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Privacy Policy & Zero Cloud Footprint Card
          Container(
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
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.primaryCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.translate('privacy_policy_title'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.translate('privacy_policy_desc'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. About App Card
          Container(
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
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.translate('about_app_title'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${loc.translate('version')} ${AppConstants.appVersion}',
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.translate('about_app_body'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
