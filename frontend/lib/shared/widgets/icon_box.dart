import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';

/// Unified icon container with a tinted background.
///
/// Replaces the many inline Container+BoxDecoration patterns for
/// icon placeholders in alert cards, device rows, event tiles, etc.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
