import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.onToggle,
    this.isCollapsed = false,
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
          _buildHeader(isDark, isCollapsed),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              child: Column(
                crossAxisAlignment:
                    isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  if (!isCollapsed) _SectionLabel('MAIN MENU', isDark),
                  _SidebarItem(
                    icon: Icons.insights_outlined,
                    activeIcon: Icons.insights,
                    label: 'Dashboard',
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
          _buildUserProfile(isDark, isCollapsed, context),
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

    return InkWell(
      onTap: () {
        // Show a menu or navigate to profile
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  onTap(7); // Index 7 is currently ServerSettingsScreen in RootPage
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          mainAxisAlignment:
              collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryDim,
              child:
                  Icon(Icons.person_outline, color: AppColors.primary, size: 18),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Alex Richards',
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Home Administrator',
                      style: TextStyle(color: textSecondary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, color: textSecondary, size: 16),
            ],
          ],
        ),
      ),
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
