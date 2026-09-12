import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';
import 'package:safe_drive_monitor/features/onboarding/domain/models/onboarding_page_data.dart';

/// Reusable page widget displaying the animated illustration, title, description, and optional custom content.
class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPageData data;
  final Widget illustration;
  final Widget? customBottomWidget;

  const OnboardingPageWidget({
    super.key,
    required this.data,
    required this.illustration,
    this.customBottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    final title = data.title(context);
    final description = data.description(context);
    final footnote = data.footnote(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Animated Illustration
                SizedBox(
                  height: 220,
                  child: Center(child: illustration),
                ),
                const SizedBox(height: 24),

                // 2. Page Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Page Description
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),

                // 4. Optional Footnote (Smaller guidance note)
                if (footnote != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: const Color(0xFF30363D),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      footnote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8B949E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // 5. Custom Bottom Widget (e.g. Checkbox on Page 4)
                if (customBottomWidget != null) ...[
                  const SizedBox(height: 16),
                  customBottomWidget!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
