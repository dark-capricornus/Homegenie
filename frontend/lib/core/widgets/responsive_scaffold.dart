import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/core/navigation/app_bottom_nav.dart';
import 'package:homegenie_app/core/navigation/app_sidebar.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:logging/logging.dart';

final _log = Logger('ResponsiveScaffold');

class ResponsiveScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final FloatingActionButton? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onNavTap,
    required this.isDark,
    required this.onToggleTheme,
    this.floatingActionButton,
  });

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  bool _isCollapsed = true;

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
       _log.fine('SCAFFOLD_BUILD: isCollapsed=$_isCollapsed, index=${widget.currentIndex}');
    }
    final isDemoMode = context.select<DashboardController, bool>((c) => c.isDemoMode);

    return ResponsiveBuilder(
      builder: (context, size) {
        if (size.isMobile) {
          return Scaffold(
            backgroundColor:
                widget.isDark ? AppColors.darkBackground : AppColors.lightBackground,
            body: SafeArea(child: widget.body),
            bottomNavigationBar: AppBottomNav(
              currentIndex: widget.currentIndex,
              onTap: widget.onNavTap,
              isDark: widget.isDark,
              isDemoMode: isDemoMode,
            ),
            floatingActionButton: widget.floatingActionButton,
          );
        }

        // Desktop / Web Layout
        return Scaffold(
          backgroundColor:
              widget.isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: Stack(
            children: [
              // Main Content (Background)
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gap for collapsed sidebar
                    const SizedBox(width: 80),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isCollapsed) {
                            setState(() => _isCollapsed = true);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox.expand(child: widget.body),
                      ),
                    ),
                  ],
                ),
              ),

              // Sidebar (Foreground)
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: AppSidebar(
                  currentIndex: widget.currentIndex,
                  onToggle: _toggleSidebar,
                  onTap: (idx) {
                    widget.onNavTap(idx);
                    if (!_isCollapsed) setState(() => _isCollapsed = true);
                  },
                  isDark: widget.isDark,
                  isCollapsed: _isCollapsed,
                  isDemoMode: isDemoMode,
                ),
              ),

              if (widget.floatingActionButton != null)
                Positioned(
                  right: 32,
                  bottom: 32,
                  child: widget.floatingActionButton!,
                ),

              // DEBUG OVERLAY
              if (kDebugMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.red.withValues(alpha: 0.7),
                    child: Text(
                      'Width: ${MediaQuery.sizeOf(context).width.toInt()} | Size: ${size.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
