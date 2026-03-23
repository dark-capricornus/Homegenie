import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

/// Unified section label used across all views.
///
/// Displays an uppercase label with optional leading icon.
class SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  final IconData? icon;

  const SectionLabel({
    super.key,
    required this.label,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
