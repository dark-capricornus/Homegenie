import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/core/navigation/app_bottom_nav.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:logging/logging.dart';

final _log = Logger('ResponsiveScaffold');

/// Bottom clearance applied to page content so the floating nav dock and
/// chatbot orb do not occlude the last items in scrollable views.
const double kFloatingUiClearance = 48;

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
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      _log.fine('SCAFFOLD_BUILD: index=${widget.currentIndex}');
    }
    final isDemoMode =
        context.select<DashboardController, bool>((c) => c.isDemoMode);

    final bg = widget.isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return ResponsiveBuilder(
      builder: (context, size) {
        final paddedBody = _PaddedBody(child: widget.body);

        if (size.isMobile) {
          return Scaffold(
            backgroundColor: bg,
            body: SafeArea(child: paddedBody),
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
          backgroundColor: bg,
          body: paddedBody,
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }
}

/// Injects bottom padding into MediaQuery so any descendant scrollable that
/// honors viewPadding (CustomScrollView, ListView, etc.) clears the floating
/// nav dock and chatbot orb without per-page tweaks.
class _PaddedBody extends StatelessWidget {
  final Widget child;
  const _PaddedBody({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(
          bottom: mq.padding.bottom + kFloatingUiClearance,
        ),
      ),
      child: child,
    );
  }
}
