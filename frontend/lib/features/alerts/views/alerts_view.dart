import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:homegenie_app/core/widgets/page_header.dart';

// ── MODEL ─────────────────────────────────────────────────────────
enum AlertType { critical, routine, update, camera }

class AlertItem {
  final String title;
  final String description;
  final AlertType type;
  final String time;
  final String location;
  final IconData icon;
  bool isRead;

  AlertItem({
    required this.title,
    required this.description,
    required this.type,
    required this.time,
    required this.location,
    required this.icon,
    this.isRead = false,
  });
}

// ── MOCK DATA ─────────────────────────────────────────────────────
List<AlertItem> mockAlerts() => _mockAlerts();

List<AlertItem> _mockAlerts() => [
      AlertItem(
        title: 'Gas Leak Detected!',
        type: AlertType.critical,
        description:
            'Kitchen sensor triggered high methane levels. Emergency valves closed.',
        time: '2 mins ago',
        location: 'KITCHEN',
        icon: Icons.warning_rounded,
      ),
      AlertItem(
        title: 'Front Door Unlocked',
        type: AlertType.routine,
        description:
            "The front door was unlocked using John's Phone digital key.",
        time: '16 mins ago',
        location: 'ENTRANCE',
        icon: Icons.lock_open,
      ),
      AlertItem(
        title: 'Energy Report Ready',
        type: AlertType.update,
        description:
            'Your weekly energy consumption decreased by 12% compared to last week.',
        time: 'Yesterday',
        location: 'SYSTEM',
        icon: Icons.bolt,
      ),
      AlertItem(
        title: 'Package Delivered',
        type: AlertType.camera,
        description:
            'Front porch camera detected a delivery person leaving a package.',
        time: 'Yesterday',
        location: 'PORCH',
        icon: Icons.inventory_2_outlined,
      ),
    ];

// ── TOP-LEVEL helpers (always in scope for DDC) ───────────────────
Color alertBadgeBg(AlertType t) {
  switch (t) {
    case AlertType.critical:
      return AppColors.badgeCriticalBg;
    case AlertType.routine:
      return AppColors.badgeRoutineBg;
    case AlertType.update:
      return AppColors.badgeUpdateBg;
    case AlertType.camera:
      return AppColors.badgeCameraBg;
  }
}

Color alertBadgeText(AlertType t) {
  switch (t) {
    case AlertType.critical:
      return AppColors.badgeCriticalText;
    case AlertType.routine:
      return AppColors.badgeRoutineText;
    case AlertType.update:
      return AppColors.badgeUpdateText;
    case AlertType.camera:
      return AppColors.badgeCameraText;
  }
}

String alertBadgeLabel(AlertType t) {
  switch (t) {
    case AlertType.critical:
      return 'CRITICAL';
    case AlertType.routine:
      return 'ROUTINE';
    case AlertType.update:
      return 'UPDATE';
    case AlertType.camera:
      return 'CAMERA';
  }
}

Color alertIconBg(AlertType t) {
  switch (t) {
    case AlertType.critical:
      return AppColors.errorDim;
    case AlertType.routine:
      return AppColors.primaryDim;
    case AlertType.update:
      return AppColors.badgeUpdateBg;
    case AlertType.camera:
      return AppColors.purpleDim;
  }
}

Color alertIconColor(AlertType t) {
  switch (t) {
    case AlertType.critical:
      return AppColors.error;
    case AlertType.routine:
      return AppColors.primary;
    case AlertType.update:
      return AppColors.badgeUpdateText;
    case AlertType.camera:
      return AppColors.purple;
  }
}

// ── PAGE ─────────────────────────────────────────────────────────
class AlertsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;

  final int currentIndex;

  const AlertsPage({
    super.key,
    required this.isDark,
    required this.currentIndex,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<AlertItem> _alerts = _mockAlerts();

  Color get _surface =>
      widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get _textSecondary => widget.isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<AlertItem> _filtered(List<AlertItem> all, int tab) {
    if (tab == 0) {
      return all;
    }
    if (tab == 1) {
      return all.where((a) => a.type == AlertType.critical).toList();
    }
    return all.where((a) => a.type == AlertType.routine).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PageHeader(
        title: 'Alerts',
        subtitle: 'Notification Center',
        isDark: widget.isDark,
        currentIndex: widget.currentIndex,
        onToggleTheme: widget.onToggleTheme,
        onNavTap: widget.onNavTap,
      ),
      Container(
        color: _surface,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: _textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Critical'),
            Tab(text: 'Routine')
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [0, 1, 2].map((tab) {
            return AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) {
                final items = _filtered(_alerts, tab);
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48,
                              color: widget.isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary),
                          const SizedBox(height: 12),
                          Text('No alerts',
                              style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('All clear — nothing to report here.',
                              style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _alerts = _mockAlerts();
                    });
                  },
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      AlertDateGroup(
                        label: 'Today',
                        isDark: widget.isDark,
                        trailing: TextButton(
                          onPressed: () => setState(() {
                            for (var a in _alerts) {
                              a.isRead = true;
                            }
                          }),
                          child: const Text('Mark all as read',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 12)),
                        ),
                        children:
                            items.where((a) => a.time.contains('ago')).toList(),
                        onDismiss: (a) => setState(() => _alerts.remove(a)),
                      ),
                      AlertDateGroup(
                        label: 'Yesterday',
                        isDark: widget.isDark,
                        children:
                            items.where((a) => a.time == 'Yesterday').toList(),
                        onDismiss: (a) => setState(() => _alerts.remove(a)),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    ]);
  }

}

// ── Public-named helpers (DDC can resolve their static references) ─
class AlertDateGroup extends StatelessWidget {
  final String label;
  final List<AlertItem> children;
  final Widget? trailing;
  final ValueChanged<AlertItem> onDismiss;
  final bool isDark;

  const AlertDateGroup({
    super.key,
    required this.label,
    required this.children,
    required this.onDismiss,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Row(children: [
        Text(label,
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 8),
      ...children.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AlertCard(
                item: a, isDark: isDark, onDismiss: () => onDismiss(a)),
          )),
    ]);
  }
}

class AlertCard extends StatelessWidget {
  final AlertItem item;
  final bool isDark;
  final VoidCallback onDismiss;

  const AlertCard(
      {super.key,
      required this.item,
      required this.isDark,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Use top-level functions — always in scope for DDC
    final badgeBg = alertBadgeBg(item.type);
    final badgeText = alertBadgeText(item.type);
    final badgeLabel = alertBadgeLabel(item.type);
    final iconColor = alertIconColor(item.type);

    return Dismissible(
      key: Key(item.title + item.time),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.errorDim,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: AppSurface(
        isDark: isDark,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBox(icon: item.icon, color: iconColor, size: 42),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(item.title,
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  AppBadge(
                    label: badgeLabel,
                    backgroundColor: badgeBg,
                    textColor: badgeText,
                  ),
                ]),
                const SizedBox(height: 4),
                Text(item.description,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('${item.time} · ${item.location}',
                    style: TextStyle(color: textSecondary, fontSize: 10)),
              ])),
        ]),
      ),
    );
  }
}
