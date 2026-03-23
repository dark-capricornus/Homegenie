import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';

/// Unified surface container (card-like) used across all views.
///
/// Provides consistent border radius, border, and background color.
/// Replaces the many inline Container+BoxDecoration patterns.
class AppSurface extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const AppSurface({
    super.key,
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
