import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';

/// Unified badge/chip used for status labels, categories, and tags.
///
/// Provides consistent padding, border radius, and typography
/// across alerts, rules, logs, and energy views.
class AppBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const AppBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm / 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
