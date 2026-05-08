import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/widgets/responsive_scaffold.dart';
import 'package:homegenie_app/features/dashboard/views/dashboard_view.dart';
import 'package:homegenie_app/features/alerts/views/alerts_view.dart';
import 'package:homegenie_app/features/rules/views/rules_view.dart';
import 'package:homegenie_app/features/energy/views/energy_view.dart';
import 'package:homegenie_app/features/logs/views/logs_view.dart';
import 'package:homegenie_app/features/dashboard/views/home.dart';
import 'package:homegenie_app/features/automation/views/automation_selection_view.dart';
import 'package:homegenie_app/features/live/views/live_hub_view.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/screens/server_settings.dart';
import 'package:homegenie_app/shared/widgets/chatbot_orb.dart';
import 'package:logging/logging.dart';

final _log = Logger('RootPage');

class RootPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const RootPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log.info('App resumed — refreshing data');
      final ctrl = context.read<DashboardController>();
      ctrl.fetchDevices();
      ctrl.fetchInsights();
    }
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    _log.fine('NAV_TAP: from $_currentIndex to $index');
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    _log.fine('ROOT_BUILD: index=$_currentIndex');

    final isDemo = context.select<DashboardController, bool>((c) => c.isDemoMode);

    Widget pageFor(int i) {
      switch (i) {
        case 0:
          return isDemo
              ? DashboardPage(
                  isDark: widget.isDark,
                  onToggleTheme: widget.onToggleTheme,
                  navIndex: 0,
                  onNavTap: _onNavTap,
                )
              : LiveHubView(
                  isDark: widget.isDark,
                  currentIndex: 0,
                  onToggleTheme: widget.onToggleTheme,
                  onNavTap: _onNavTap,
                );
        case 1:
          return IoTDevicesPage(
            isDark: widget.isDark,
            currentIndex: 1,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        case 2:
          return RulesPage(
            isDark: widget.isDark,
            currentIndex: 2,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        case 3:
          return const AutomationSelectionView();
        case 4:
          return EnergyPage(
            isDark: widget.isDark,
            currentIndex: 4,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        case 5:
          return AlertsPage(
            isDark: widget.isDark,
            currentIndex: 5,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        case 6:
          return LogsPage(
            isDark: widget.isDark,
            currentIndex: 6,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        case 7:
          return ServerSettingsScreen(
            isDark: widget.isDark,
            currentIndex: 7,
            onToggleTheme: widget.onToggleTheme,
            onNavTap: _onNavTap,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Stack(
        children: [
          ResponsiveScaffold(
            body: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: RepaintBoundary(child: pageFor(_currentIndex)),
            ),
            currentIndex: _currentIndex,
            onNavTap: _onNavTap,
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, right: 8),
              child: ChatbotOrb(isDark: widget.isDark),
            ),
          ),
        ],
      ),
    );
  }
}
