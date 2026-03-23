import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/widgets/responsive_scaffold.dart';
import 'package:homegenie_app/features/dashboard/views/dashboard_view.dart';
import 'package:homegenie_app/features/alerts/views/alerts_view.dart';
import 'package:homegenie_app/features/rules/views/rules_view.dart';
import 'package:homegenie_app/features/energy/views/energy_view.dart';
import 'package:homegenie_app/features/logs/views/logs_view.dart';
import 'package:homegenie_app/features/dashboard/views/iot_devices_view.dart';
import 'package:homegenie_app/features/simulation/views/simulation_view.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/screens/server_settings.dart';
import 'package:homegenie_app/shared/widgets/chatbot_orb.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
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
    _log.shout('NAV_TAP: from $_currentIndex to $index');
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    _log.shout('ROOT_BUILD: index=$_currentIndex');

    final List<Widget> pages = [
      DashboardPage(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        navIndex: 0,
        onNavTap: _onNavTap,
      ),
      IoTDevicesPage(isDark: widget.isDark),
      RulesPage(isDark: widget.isDark),
      SimulationPage(
        isDark: widget.isDark,
        navIndex: 3,
        onNavTap: _onNavTap,
      ),
      EnergyPage(isDark: widget.isDark),
      AlertsPage(isDark: widget.isDark),
      LogsPage(isDark: widget.isDark),
      const ServerSettingsScreen(),
    ];

    // Handle Android back button: go to dashboard first, then exit
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
            body: IndexedStack(
              index: _currentIndex,
              children: pages,
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
              padding: EdgeInsets.only(
                bottom: Breakpoints.of(context).isMobile ? 80 : 0,
              ),
              child: ChatbotOrb(isDark: widget.isDark),
            ),
          ),
        ],
      ),
    );
  }
}
