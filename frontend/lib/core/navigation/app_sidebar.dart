import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isCollapsed;
  final bool isDemoMode;
  final VoidCallback onToggle;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.onToggle,
    this.isCollapsed = false,
    this.isDemoMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 80 : 260,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        children: [
          _buildUserProfile(isDark, isCollapsed, context),
          _buildHeader(isDark, isCollapsed),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              child: Column(
                crossAxisAlignment:
                    isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  if (!isCollapsed) _SectionLabel('MAIN MENU', isDark),
                  _SidebarItem(
                    icon: isDemoMode ? Icons.insights_outlined : Icons.cell_tower_outlined,
                    activeIcon: isDemoMode ? Icons.insights : Icons.cell_tower,
                    label: isDemoMode ? 'Dashboard' : 'Live Hub',
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.bolt_outlined,
                    activeIcon: Icons.bolt,
                    label: 'Automations',
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.psychology_outlined,
                    activeIcon: Icons.psychology,
                    label: 'AI Insights',
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.query_stats_outlined,
                    activeIcon: Icons.query_stats,
                    label: 'Energy Analytics',
                    index: 4,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.notifications_none_outlined,
                    activeIcon: Icons.notifications,
                    label: 'Notifications',
                    index: 5,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
                  _SidebarItem(
                    icon: Icons.article_outlined,
                    activeIcon: Icons.article,
                    label: 'System Logs',
                    index: 6,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    isDark: isDark,
                    isCollapsed: isCollapsed,
                  ),
          const SizedBox(height: 40),
                  if (!isCollapsed) _buildSystemStats(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool collapsed) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.fromLTRB(collapsed ? 0 : 20, 30, collapsed ? 0 : 20, 10),
        child: Row(
          mainAxisAlignment:
              collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HomeGenie',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    const Text(
                      'AI CO-PILOT',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStats(bool isDark) {
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: textSecondary, size: 14),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Uptime: 14d 2h',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.clip),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('Efficiency',
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.clip),
              ),
              const Text('A++',
                  style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.94,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(bool isDark, bool collapsed, BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Consumer<DashboardController>(
      builder: (context, controller, _) {
        final user = controller.currentUser;
        final userLabel = user?.username ?? 'Guest User';
        final userRole = user != null ? 'Authenticated User' : 'Guest';

        return InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => Consumer<DashboardController>(
                builder: (context, controller, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Demo Mode Switch
                    ListTile(
                      leading: Icon(Icons.bug_report_outlined,
                          color: controller.isDemoMode ? AppColors.primary : textSecondary),
                      title: const Text('Demo Mode'),
                      subtitle: Text(controller.isDemoMode
                          ? 'Running in simulation mode'
                          : 'Connected to real hardware'),
                      trailing: Switch.adaptive(
                        value: controller.isDemoMode,
                        onChanged: (val) {
                          controller.setMode(val);
                        },
                        activeTrackColor: AppColors.primary,
                      ),
                    ),
                    const Divider(),
                    if (controller.isLoggedIn) ...[
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('My Profile'),
                        onTap: () => Navigator.pop(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Server Settings'),
                        onTap: () {
                          Navigator.pop(context);
                          onTap(7);
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: controller.isLoggedIn ? AppColors.primary : AppColors.primaryDim,
                  child: Icon(
                    controller.isLoggedIn ? Icons.person : Icons.person_outline,
                    color: controller.isLoggedIn ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userLabel,
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userRole,
                          style: TextStyle(color: textSecondary, fontSize: 10),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  if (!collapsed && controller.isLoggedIn)
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      color: AppColors.error.withOpacity(0.7),
                      onPressed: () => controller.logout(),
                      tooltip: 'Logout',
                    )
                  else if (!collapsed)
                    Icon(Icons.unfold_more, color: textSecondary, size: 16),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel(this.label, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
      child: Text(
        label,
        style: TextStyle(
          color:
              isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isCollapsed;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 0 : 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment:
                  isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? Colors.white
                        : textSecondary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
