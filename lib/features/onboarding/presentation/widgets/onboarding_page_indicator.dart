import 'package:flutter/material.dart';
import 'package:safe_drive_monitor/app/theme/app_colors.dart';

/// Animated page indicator with smooth expanding active pill.
class OnboardingPageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;

  const OnboardingPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 6.0,
          width: isActive ? 22.0 : 6.0,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryCyan
                : const Color(0xFF30363D),
            borderRadius: BorderRadius.circular(3.0),
          ),
        );
      }),
    );
  }
}
