import 'dart:math';
import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/features/alerts/views/alerts_view.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:provider/provider.dart';



class AlertsLogsSection extends StatelessWidget {
  final bool isDark;
  final bool forceStacked;
  const AlertsLogsSection(
      {super.key, required this.isDark, this.forceStacked = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final alerts = mockAlerts();
    final activity = ctrl.recentActivity;
    final isMobile = Breakpoints.of(context).isMobile;
    final stacked = forceStacked || isMobile;

    final alertsCard = _PreviewCard(
      isDark: isDark,
      title: 'Alerts',
      icon: Icons.notifications_active_rounded,
      emptyText: 'No alerts',
      children: alerts
          .map((a) => _AlertRow(
                item: a,
                isDark: isDark,
                onTap: () => _showAlertDetail(context, a),
              ))
          .toList(),
    );

    final activityCard = _PreviewCard(
      isDark: isDark,
      title: 'Recent Activity',
      icon: Icons.history_rounded,
      emptyText: 'No recent activity',
      children: activity
          .map((a) => _ActivityRow(
                message: a,
                isDark: isDark,
              ))
          .toList(),
    );

    if (stacked) {
      if (forceStacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: alertsCard),
            const SizedBox(height: 12),
            Expanded(child: activityCard),
          ],
        );
      }
      return Column(
        children: [
          alertsCard,
          const SizedBox(height: 12),
          activityCard,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: alertsCard),
        const SizedBox(width: 20),
        Expanded(child: activityCard),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final IconData icon;
  final String emptyText;
  final List<Widget> children;

  const _PreviewCard({
    required this.isDark,
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: AppColors.primaryDim, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: textPri,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Text(emptyText,
                style: TextStyle(color: textSec, fontSize: 12))
          else
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => children[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final AlertItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _AlertRow(
      {required this.item, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final iconColor = alertIconColor(item.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textPri,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${item.time} · ${item.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSec, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ActivityRow({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textSec,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// ─── Popups ────────────────────────────────────────────────────────

void _showAlertDetail(BuildContext context, AlertItem a) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final iconColor = alertIconColor(a.type);
  showDialog(
    context: context,
    builder: (_) => _DetailDialog(
      isDark: isDark,
      iconColor: iconColor,
      icon: a.icon,
      title: a.title,
      badge: alertBadgeLabel(a.type),
      badgeColor: iconColor,
      meta: '${a.time} · ${a.location}',
      body: a.description,
    ),
  );
}



class _DetailDialog extends StatelessWidget {
  final bool isDark;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String badge;
  final Color badgeColor;
  final String meta;
  final String body;

  const _DetailDialog({
    required this.isDark,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.meta,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final maxW = min(MediaQuery.of(context).size.width * 0.9, 460.0);

    return Dialog(
      backgroundColor: bg,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            color: textPri,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(meta,
                        style: TextStyle(color: textSec, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(body,
                  style: TextStyle(
                      color: textPri, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
