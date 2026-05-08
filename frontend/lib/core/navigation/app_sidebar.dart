import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

/// Floating bottom navigation dock for desktop/web.
/// Pages: Dashboard (0), Home (1), Rules (2), Automation (3), Profile (sheet).
class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isDemoMode;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    this.isDemoMode = true,
  });

  static const _items = <_DockItem>[
    _DockItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        index: 0),
    _DockItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        index: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.92)
        : AppColors.lightSurface.withValues(alpha: 0.95);
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return RepaintBoundary(
      child: UnconstrainedBox(
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in _items)
                _DockButton(
                  item: item,
                  isActive: currentIndex == item.index,
                  isDark: isDark,
                  onTap: () => onTap(item.index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DockItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  const _DockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

class _DockButton extends StatefulWidget {
  final _DockItem item;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _DockButton({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: widget.isActive ? 1.0 : 0.0,
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _DockButton old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final hoverColor = widget.isDark
        ? AppColors.darkSurface2
        : AppColors.lightSurface2;

    return Tooltip(
      message: widget.item.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final v = _t.value;
                final bg = Color.lerp(
                  _hover && !widget.isActive ? hoverColor : Colors.transparent,
                  AppColors.primary,
                  v,
                )!;
                final fg = Color.lerp(textSecondary, Colors.white, v)!;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          v > 0.5
                              ? widget.item.activeIcon
                              : widget.item.icon,
                          color: fg,
                          size: 20,
                        ),
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: v,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Opacity(
                                opacity: v,
                                child: Text(
                                  widget.item.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

