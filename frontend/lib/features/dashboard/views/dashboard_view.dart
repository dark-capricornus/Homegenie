import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:logging/logging.dart';

final _log = Logger('DashboardPage');

class DashboardPage extends StatefulWidget {
  final bool isDark;
  final int navIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onToggleTheme;

  const DashboardPage({
    super.key,
    required this.isDark,
    required this.navIndex,
    required this.onNavTap,
    required this.onToggleTheme,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardController _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl = context.read<DashboardController>();
      _ctrl.addListener(_handleControllerChanges);
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleControllerChanges);
    super.dispose();
  }

  void _handleControllerChanges() {
    if (_ctrl.lastGoalResult != null) {
      final msg = _ctrl.lastGoalResult!;
      _ctrl.lastGoalResult = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    _log.fine(
        'DASHBOARD_BUILD: loading=${ctrl.isLoading}, devCount=${ctrl.devices.length}');

    Widget content;
    if (ctrl.isLoading && ctrl.devices.isEmpty) {
      content = _buildLoadingState('Synchronizing home state...');
    } else if (!ctrl.isLoading && ctrl.devices.isEmpty && ctrl.connectionStatus == ConnectionStatus.disconnected) {
      content = _buildErrorState(ctrl);
    } else if (!ctrl.wsConnected && ctrl.devices.isEmpty) {
      content = _buildLoadingState('Connecting to HomeGenie stream...');
    } else {
      content = ResponsiveBuilder(
        builder: (context, size) {
          if (size.isMobile) {
            return _MobileDashboard(
              ctrl: ctrl,
              isDark: widget.isDark,
              onToggleTheme: widget.onToggleTheme,
            );
          }
          return _DesktopDashboard(
            ctrl: ctrl,
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          );
        },
      );
    }

    return Container(
      color:
          widget.isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: content,
    );
  }

  Widget _buildLoadingState(String message) {
    final textSecondary = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _showConnectionDialog,
            icon: const Icon(Icons.settings_input_component_rounded, size: 16),
            label: const Text('Manual Connection Settings',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(DashboardController ctrl) {
    final textPrimary = widget.isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('Unable to reach server',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 8),
            Text(
                'Make sure the HomeGenie backend is running and accessible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ctrl.fetchDevices();
                ctrl.fetchInsights();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showConnectionDialog,
              icon: const Icon(Icons.settings_input_component_rounded, size: 16),
              label: const Text('Connection Settings',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.darkSurface : Colors.white,
        title: Text('Connect to Server',
            style: TextStyle(
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your computer\'s LAN IP address (e.g. 192.168.1.50) to connect your mobile device.',
                style: TextStyle(
                    color: widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
              decoration: InputDecoration(
                hintText: '192.168.1.XX',
                hintStyle: TextStyle(
                    color: widget.isDark
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.5)),
                prefixText: 'http://',
                suffixText: ':8081',
                filled: true,
                fillColor: widget.isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                final url = 'http://$ip:8081';
                Navigator.pop(context);
                final ctrl = context.read<DashboardController>();
                await ctrl.setManualServerUrl(url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MOBILE DASHBOARD
// =============================================================================
class _MobileDashboard extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const _MobileDashboard({
    required this.ctrl,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await ctrl.fetchDevices();
        await ctrl.fetchInsights();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildQuickStats()),
          ),
          SliverToBoxAdapter(child: _sectionTitle('DEVICE STATUS', Icons.donut_large_rounded)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _DeviceStatusRing(ctrl: ctrl, isDark: isDark)),
          ),
          SliverToBoxAdapter(child: _sectionTitle('POWER BY ROOM', Icons.bolt_rounded)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _RoomPowerChart(ctrl: ctrl, isDark: isDark)),
          ),
          SliverToBoxAdapter(child: _sectionTitle('HOMEGENIE INSIGHTS', Icons.auto_awesome_rounded)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _buildInsightsList(),
          ),
          SliverToBoxAdapter(child: _sectionTitle('SUGGESTIONS', Icons.lightbulb_rounded)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _buildSuggestionsList(),
          ),
          SliverToBoxAdapter(child: _sectionTitle('ACTIVITY OVERVIEW', Icons.analytics_rounded)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildActivityOverview()),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HomeGenie',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ],
          ),
          Row(
            children: [
              _ConnectionDot(status: ctrl.connectionStatus, isDark: isDark),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onToggleTheme,
                icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final deviceCount = ctrl.devices.length;
    final activeCount = ctrl.devices.where((d) => d.isOn).length;
    final power = ctrl.totalPowerConsumption;
    final roomCount = ctrl.devicesByRoom.length;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Row(
        children: [
          _StatChip(
              label: 'Devices',
              value: '$deviceCount',
              icon: Icons.devices_rounded,
              isDark: isDark),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Active',
              value: '$activeCount',
              icon: Icons.power_rounded,
              isDark: isDark),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Rooms',
              value: '$roomCount',
              icon: Icons.room_rounded,
              isDark: isDark),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Power',
              value: '${power.toStringAsFixed(1)}W',
              icon: Icons.bolt_rounded,
              isDark: isDark),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: SectionLabel(label: title, isDark: isDark, icon: icon),
    );
  }

  Widget _buildInsightsList() {
    final items = ctrl.insights;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyPlaceholder(
            message: 'No HomeGenie insights yet. Use your home to generate data.',
            isDark: isDark),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _InsightCard(insight: items[i], isDark: isDark),
        ),
        childCount: items.length,
      ),
    );
  }

  Widget _buildSuggestionsList() {
    final items = ctrl.suggestions;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyPlaceholder(
            message: 'No suggestions available right now.', isDark: isDark),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SuggestionCard(suggestion: items[i], isDark: isDark),
        ),
        childCount: items.length,
      ),
    );
  }

  Widget _buildActivityOverview() {
    final a = ctrl.analytics;
    final totalInteractions = a['total_interactions'] ?? 0;
    final mostUsed = (a['most_used_devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final timeDist = (a['time_distribution'] as Map?)?.cast<String, dynamic>() ?? {};

    return Column(
      children: [
        _AnalyticsTile(
            label: 'Total Interactions',
            value: '$totalInteractions',
            icon: Icons.touch_app_rounded,
            isDark: isDark),
        const SizedBox(height: 12),
        if (mostUsed.isNotEmpty)
          _AnalyticsTile(
              label: 'Most Used',
              value: '${mostUsed.first['device'] ?? 'N/A'}',
              icon: Icons.star_rounded,
              isDark: isDark),
        if (mostUsed.isNotEmpty) const SizedBox(height: 12),
        if (timeDist.isNotEmpty)
          _AnalyticsTile(
              label: 'Peak Time',
              value: _peakTime(timeDist),
              icon: Icons.schedule_rounded,
              isDark: isDark),
      ],
    );
  }

  String _peakTime(Map<String, dynamic> dist) {
    if (dist.isEmpty) return 'N/A';
    String peak = dist.keys.first;
    num peakVal = dist.values.first as num;
    for (final e in dist.entries) {
      if ((e.value as num) > peakVal) {
        peak = e.key;
        peakVal = e.value as num;
      }
    }
    // All zeros means no data yet
    if (peakVal <= 0) return 'N/A';
    return peak;
  }
}

// =============================================================================
// DESKTOP DASHBOARD
// =============================================================================
class _DesktopDashboard extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const _DesktopDashboard({
    required this.ctrl,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main content — insights & suggestions
        Expanded(
          flex: 7,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: SliverToBoxAdapter(child: _buildStatRow()),
              ),
              SliverToBoxAdapter(child: _sectionTitle('DEVICE STATUS')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _DeviceStatusRing(ctrl: ctrl, isDark: isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _RoomPowerChart(ctrl: ctrl, isDark: isDark)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _sectionTitle('HOMEGENIE INSIGHTS')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: _buildInsightsGrid(),
              ),
              SliverToBoxAdapter(child: _sectionTitle('SUGGESTIONS')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: _buildSuggestionsGrid(),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
        // Side panel — activity analytics
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder)),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            ),
            child: _buildSidePanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Home Dashboard',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('HomeGenie',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8)),
            ],
          ),
          Row(
            children: [
              _ConnectionDot(status: ctrl.connectionStatus, isDark: isDark),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onToggleTheme,
                icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    final deviceCount = ctrl.devices.length;
    final activeCount = ctrl.devices.where((d) => d.isOn).length;
    final power = ctrl.totalPowerConsumption;
    final roomCount = ctrl.devicesByRoom.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _StatChip(
              label: 'Total Devices',
              value: '$deviceCount',
              icon: Icons.devices_rounded,
              isDark: isDark),
          const SizedBox(width: 16),
          _StatChip(
              label: 'Active Now',
              value: '$activeCount',
              icon: Icons.power_rounded,
              isDark: isDark),
          const SizedBox(width: 16),
          _StatChip(
              label: 'Rooms',
              value: '$roomCount',
              icon: Icons.room_rounded,
              isDark: isDark),
          const SizedBox(width: 16),
          _StatChip(
              label: 'Power Draw',
              value: '${power.toStringAsFixed(1)}W',
              icon: Icons.bolt_rounded,
              isDark: isDark),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      child: SectionLabel(label: title, isDark: isDark),
    );
  }

  Widget _buildInsightsGrid() {
    final items = ctrl.insights;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyPlaceholder(
            message: 'No HomeGenie insights yet. Use your home to generate data.',
            isDark: isDark),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _InsightCard(insight: items[i], isDark: isDark),
        childCount: items.length,
      ),
    );
  }

  Widget _buildSuggestionsGrid() {
    final items = ctrl.suggestions;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyPlaceholder(
            message: 'No suggestions available right now.', isDark: isDark),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _SuggestionCard(suggestion: items[i], isDark: isDark),
        childCount: items.length,
      ),
    );
  }

  Widget _buildSidePanel() {
    final a = ctrl.analytics;
    final totalInteractions = a['total_interactions'] ?? 0;
    final mostUsed =
        (a['most_used_devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final timeDist =
        (a['time_distribution'] as Map?)?.cast<String, dynamic>() ?? {};

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Activity',
            style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 24),
        _AnalyticsTile(
            label: 'Total Interactions',
            value: '$totalInteractions',
            icon: Icons.touch_app_rounded,
            isDark: isDark),
        const SizedBox(height: 12),
        for (final device in mostUsed.take(5)) ...[
          _AnalyticsTile(
              label: '${device['device'] ?? 'Unknown'}',
              value: '${device['total_uses'] ?? 0} uses',
              icon: Icons.devices_rounded,
              isDark: isDark),
          const SizedBox(height: 12),
        ],
        if (timeDist.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('TIME DISTRIBUTION',
              style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          for (final entry in timeDist.entries)
            _TimeBar(
                label: entry.key,
                value: (entry.value as num).toInt(),
                maxValue: timeDist.values
                    .fold<num>(1, (a, b) => (b as num) > a ? b : a)
                    .toInt(),
                isDark: isDark),
        ],
        const SizedBox(height: 24),
        _buildEnergyCard(),
      ],
    );
  }

  Widget _buildEnergyCard() {
    final power = ctrl.totalPowerConsumption;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENERGY SUMMARY',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text('${power.toStringAsFixed(1)}W Active',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          const SizedBox(height: 6),
          Text(
              '${ctrl.devices.where((d) => d.isOn).length} of ${ctrl.devices.length} devices are currently drawing power.',
              style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  fontSize: 11)),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _ConnectionDot extends StatelessWidget {
  final ConnectionStatus status;
  final bool isDark;

  const _ConnectionDot({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.disconnected => Colors.red,
      ConnectionStatus.unknown => Colors.orange,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: textPri,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text(label,
                style: TextStyle(color: textSec, fontSize: 9),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  final bool isDark;

  const _InsightCard({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final type = insight['type'] ?? '';
    final icon = switch (type) {
      'device_usage' => Icons.devices_rounded,
      'time_pattern' => Icons.schedule_rounded,
      'behavior_pattern' => Icons.psychology_rounded,
      _ => Icons.auto_awesome_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: AppColors.primaryDim, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(insight['title'] ?? 'Insight',
                    style: TextStyle(
                        color: textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(insight['description'] ?? '',
              style: TextStyle(color: textSec, fontSize: 12, height: 1.4)),
          if (insight['recommendation'] != null) ...[
            const SizedBox(height: 8),
            Text(insight['recommendation'],
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final bool isDark;

  const _SuggestionCard({required this.suggestion, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final confidence = (suggestion['confidence'] ?? 0.0) as num;
    final pct = (confidence * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(suggestion['title'] ?? 'Suggestion',
                    style: TextStyle(
                        color: textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$pct%',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(suggestion['description'] ?? '',
              style: TextStyle(color: textSec, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _AnalyticsTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _TimeBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final bool isDark;

  const _TimeBar(
      {required this.label,
      required this.value,
      required this.maxValue,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child:
                  Text(label, style: TextStyle(color: textSec, fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 24,
              child: Text('$value',
                  style: TextStyle(
                      color: textSec,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  final bool isDark;

  const _EmptyPlaceholder({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: textSec.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: textSec, fontSize: 12))),
        ],
      ),
    );
  }
}

// =============================================================================
// VISUALIZATION WIDGETS
// =============================================================================

/// Donut ring showing active vs inactive device ratio
class _DeviceStatusRing extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _DeviceStatusRing({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = ctrl.devices.length;
    final active = ctrl.devices.where((d) => d.isOn).length;
    final inactive = total - active;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: CustomPaint(
              painter: _DonutPainter(
                activeRatio: total > 0 ? active / total : 0,
                activeColor: AppColors.primary,
                inactiveColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$active',
                        style: TextStyle(
                            color: textPri,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    Text('active',
                        style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.primary, label: 'Active ($active)', isDark: isDark),
              const SizedBox(width: 16),
              _LegendDot(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  label: 'Inactive ($inactive)',
                  isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendDot(
      {required this.color, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textSec, fontSize: 11)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double activeRatio;
  final Color activeColor;
  final Color inactiveColor;

  _DonutPainter({
    required this.activeRatio,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw full background ring
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    // Draw active arc
    if (activeRatio > 0) {
      final sweep = 2 * math.pi * activeRatio;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.activeRatio != activeRatio;
}

/// Horizontal bar chart showing power consumption per room
class _RoomPowerChart extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _RoomPowerChart({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Compute power per room
    final roomPower = <String, double>{};
    for (final entry in ctrl.devicesByRoom.entries) {
      double power = 0;
      for (final d in entry.value) {
        if (d.isOn) {
          power += d.powerConsumption;
        }
      }
      roomPower[entry.key] = power;
    }

    final maxPower = roomPower.values.fold<double>(1, (a, b) => b > a ? b : a);
    final sortedRooms = roomPower.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppColors.primary,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: sortedRooms.isEmpty
          ? Center(
              child: Text('No room data available',
                  style: TextStyle(color: textSec, fontSize: 12)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Power Consumption',
                    style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${ctrl.totalPowerConsumption.toStringAsFixed(1)}W total',
                    style: TextStyle(color: textSec, fontSize: 11)),
                const SizedBox(height: 16),
                for (var i = 0; i < sortedRooms.length; i++) ...[
                  _PowerBar(
                    label: _formatRoomName(sortedRooms[i].key),
                    value: sortedRooms[i].value,
                    maxValue: maxPower,
                    color: colors[i % colors.length],
                    isDark: isDark,
                  ),
                  if (i < sortedRooms.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  String _formatRoomName(String key) {
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _PowerBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final bool isDark;

  const _PowerBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: textSec, fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${value.toStringAsFixed(1)}W',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
