import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/core/localization/app_localizations.dart';

/// Screen presenting comprehensive driving safety guidelines, app operation principles,
/// and complete legal liability disclaimers.
class SafetyGuidelinesScreen extends StatelessWidget {
  const SafetyGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          loc.translate('safety_title'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Legal Disclaimer Alert Box (Top Priority)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.alarmRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.alarmRed.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: AppColors.alarmRed, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.translate('safety_disclaimer_title'),
                        style: const TextStyle(
                          color: AppColors.alarmRed,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  loc.translate('safety_disclaimer_body'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. How the App Works & Privacy Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        color: AppColors.primaryCyan, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.translate('safety_how_it_works_title'),
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  loc.translate('safety_how_it_works_body'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Title: Safe Driving Rules
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.primaryCyan, size: 22),
              const SizedBox(width: 8),
              Text(
                loc.translate('safety_rules_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rule 1: Sleep
          _buildTipCard(
            icon: Icons.bedtime_rounded,
            iconColor: Colors.indigoAccent,
            title: loc.translate('safety_rule_1_title'),
            body: loc.translate('safety_rule_1_body'),
          ),
          const SizedBox(height: 10),

          // Rule 2: 2-Hour Breaks
          _buildTipCard(
            icon: Icons.coffee_rounded,
            iconColor: Colors.amber,
            title: loc.translate('safety_rule_2_title'),
            body: loc.translate('safety_rule_2_body'),
          ),
          const SizedBox(height: 10),

          // Rule 3: Biological Clock
          _buildTipCard(
            icon: Icons.schedule_rounded,
            iconColor: Colors.deepOrangeAccent,
            title: loc.translate('safety_rule_3_title'),
            body: loc.translate('safety_rule_3_body'),
          ),
          const SizedBox(height: 10),

          // Rule 4: Warning signs
          _buildTipCard(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.alarmRed,
            title: loc.translate('safety_rule_4_title'),
            body: loc.translate('safety_rule_4_body'),
          ),
          const SizedBox(height: 10),

          // Rule 5: Distractions & Speed
          _buildTipCard(
            icon: Icons.phonelink_erase_rounded,
            iconColor: AppColors.primaryCyan,
            title: loc.translate('safety_rule_5_title'),
            body: loc.translate('safety_rule_5_body'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
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
    );
  }
}
