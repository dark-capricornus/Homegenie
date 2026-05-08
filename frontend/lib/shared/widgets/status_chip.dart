import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';

/// Compact status chip with label, value, optional icon, and tinted background.
///
/// Replaces the many inline chip patterns across simulation, dashboard, and
/// energy views (SimStatusChip, SimAgentChip, _StatChip, etc.).
class StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final bool isDark;

  const StatusChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: textSec,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
              Text(value,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Minimal agent/status indicator with colored dot and tinted background.
///
/// Used for small inline status indicators (e.g. PLANNING: Active).
class AgentChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isNarrow;

  const AgentChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 6 : 8, vertical: isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: isNarrow ? 7 : 8,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: isNarrow ? 4 : 5,
              height: isNarrow ? 4 : 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: isNarrow ? 3 : 4),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color,
                      fontSize: isNarrow ? 9 : 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    );
  }
}
