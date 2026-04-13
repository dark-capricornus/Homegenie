import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

/// Central bottom navigation bar — 4-tab design with "More" overflow menu.
/// Import path: `package:homegenie_app/core/navigation/app_bottom_nav.dart`
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isDemoMode;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    this.isDemoMode = true,
  });

  /// Indices reachable only via the "More" sheet.
  static const _moreIndices = {3, 4, 5, 6, 7};

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final moreActive = _moreIndices.contains(currentIndex);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              BottomNavItem(
                  icon: isDemoMode ? Icons.insights_outlined : Icons.cell_tower_outlined,
                  activeIcon: isDemoMode ? Icons.insights : Icons.cell_tower,
                  label: isDemoMode ? 'Dashboard' : 'Live Hub',
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  isDark: isDark),
              BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  isDark: isDark),
              BottomNavItem(
                  icon: Icons.bolt_outlined,
                  activeIcon: Icons.bolt,
                  label: 'Energy',
                  index: 4,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  isDark: isDark),
              // "More" tab — opens bottom sheet with remaining pages.
              Expanded(
                child: GestureDetector(
                  onTap: () => _showMoreSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        moreActive ? Icons.menu : Icons.menu_outlined,
                        color: moreActive
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'More',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: moreActive ? FontWeight.w700 : FontWeight.w500,
                          color: moreActive
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final sheetBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final items = <_MoreItem>[
          _MoreItem(Icons.account_tree_outlined, 'AI Rules', 2),
          if (isDemoMode) _MoreItem(Icons.psychology_outlined, 'AI Insights', 3),
          _MoreItem(Icons.notifications_none_outlined, 'Alerts', 5),
          _MoreItem(Icons.article_outlined, 'System Logs', 6),
          _MoreItem(Icons.settings_outlined, 'Settings', 7),
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              for (final item in items)
                ListTile(
                  leading: Icon(item.icon,
                      color: currentIndex == item.index
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  title: Text(item.label,
                      style: TextStyle(
                        fontWeight: currentIndex == item.index ? FontWeight.w700 : FontWeight.w500,
                        color: currentIndex == item.index
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      )),
                  onTap: () {
                    Navigator.pop(context);
                    onTap(item.index);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final int index;
  const _MoreItem(this.icon, this.label, this.index);
}

/// Individual tab item — public class so DDC can resolve AppColors correctly.
class BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const BottomNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    const activeColor = AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
