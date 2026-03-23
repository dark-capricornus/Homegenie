import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

/// Unified page header used across all views.
///
/// Provides a consistent title row with optional leading/trailing widgets.
/// Automatically handles surface color based on dark/light mode.
class PageHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  /// Optional widget shown before the title (e.g. back button, menu icon).
  final Widget? leading;

  /// Optional widgets shown after the title (e.g. action buttons).
  final List<Widget> actions;

  /// Optional widget below the title row (e.g. toggle bar, subtitle).
  final Widget? bottom;

  const PageHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.leading,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            ...actions,
          ]),
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}
