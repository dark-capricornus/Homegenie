import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDark;
  final int currentIndex;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;
  final List<Widget>? actions;

  const PageHeader({
    super.key,
    required this.title,
    required this.isDark,
    required this.currentIndex,
    this.subtitle,
    this.onToggleTheme,
    this.onNavTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final connectionStatus = context.select<DashboardController, ConnectionStatus>(
        (c) => c.connectionStatus);

    final padding = size.isMobile
        ? const EdgeInsets.fromLTRB(20, 20, 20, 12)
        : const EdgeInsets.fromLTRB(40, 28, 40, 12);
    
    // Brand section width (to help center navigation)
    final double sideWidth = size.isMobile ? 120 : 200;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── BRAND / TITLE ──
          SizedBox(
            width: sideWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HOMEGENIE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: size.isMobile ? 14 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                if (!size.isMobile && subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (size.isMobile)
                   Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),

          // ── NAVIGATION (CENTER) ──
          if (!size.isMobile)
            Expanded(
              child: Center(
                child: _HeaderNav(
                  currentIndex: currentIndex,
                  onTap: onNavTap,
                  isDark: isDark,
                ),
              ),
            )
          else
            const Spacer(),

          // ── ACTIONS ──
          SizedBox(
            width: sideWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (actions != null) ...[
                  ...actions!,
                  const SizedBox(width: 8),
                ],
                _ConnectionDot(status: connectionStatus),
                const SizedBox(width: 12),
                if (onToggleTheme != null)
                  IconButton(
                    onPressed: onToggleTheme,
                    splashRadius: 20,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: textPrimary,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 8),
                _ProfileHeaderButton(isDark: isDark, onNavTap: onNavTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final bool isDark;

  const _HeaderNav({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_rounded, 'Dashboard', 0),
      (Icons.home_rounded, 'Home', 1),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = currentIndex == item.$3;
          return _HeaderNavItem(
            icon: item.$1,
            label: item.$2,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onTap?.call(item.$3),
          );
        }).toList(),
      ),
    );
  }
}

class _HeaderNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeaderNavItem> createState() => _HeaderNavItemState();
}

class _HeaderNavItemState extends State<_HeaderNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? AppColors.primary 
                : (_isHovered ? (widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)) : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected ? Colors.white : (widget.isSelected || _isHovered ? textPrimary : textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: widget.isSelected ? Colors.white : (widget.isSelected || _isHovered ? textPrimary : textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderButton extends StatelessWidget {
  final bool isDark;
  final ValueChanged<int>? onNavTap;
  const _ProfileHeaderButton({required this.isDark, this.onNavTap});

  void _openProfile(BuildContext context) {
    final controller = context.read<DashboardController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<DashboardController>(
        builder: (ctx, ctrl, _) {
          final user = ctrl.currentUser;
          final textPrimary =
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
          final textSecondary =
              isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
          final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

          return SafeArea(
            child: Column(
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
                ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: ctrl.isLoggedIn
                        ? AppColors.primary
                        : AppColors.primaryDim,
                    child: Icon(
                      ctrl.isLoggedIn ? Icons.person : Icons.person_outline,
                      color: ctrl.isLoggedIn ? Colors.white : AppColors.primary,
                    ),
                  ),
                  title: Text(user?.username ?? 'Guest User',
                      style: TextStyle(
                          color: textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: Text(user != null ? 'Authenticated User' : 'Guest',
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.bug_report_outlined,
                      color: ctrl.isDemoMode ? AppColors.primary : textSecondary),
                  title: const Text('Demo Mode'),
                  subtitle: Text(ctrl.isDemoMode
                      ? 'Running in simulation mode'
                      : 'Connected to real hardware'),
                  trailing: Switch.adaptive(
                    value: ctrl.isDemoMode,
                    onChanged: (val) => ctrl.setMode(val),
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                if (onNavTap != null) ...[
                  ListTile(
                    leading: const Icon(Icons.rule_folder_outlined),
                    title: const Text('AI Rules'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onNavTap!(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Server Settings'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onNavTap!(7);
                    },
                  ),
                ],
                if (ctrl.isLoggedIn)
                  ListTile(
                    leading: Icon(Icons.logout, color: AppColors.error),
                    title:
                        Text('Log out', style: TextStyle(color: AppColors.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmLogout(context, controller);
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _confirmLogout(
      BuildContext context, DashboardController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, ctrl, _) {
        return IconButton(
          onPressed: () => _openProfile(context),
          splashRadius: 20,
          icon: CircleAvatar(
            radius: 14,
            backgroundColor:
                ctrl.isLoggedIn ? AppColors.primary : AppColors.primaryDim,
            child: Icon(
              ctrl.isLoggedIn ? Icons.person : Icons.person_outline,
              color: ctrl.isLoggedIn ? Colors.white : AppColors.primary,
              size: 16,
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  final ConnectionStatus status;
  const _ConnectionDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.disconnected => Colors.red,
      ConnectionStatus.unknown => Colors.orange,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
