import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:homegenie_app/core/widgets/page_header.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/features/dashboard/widgets/dashboard_widgets.dart';
import 'package:homegenie_app/features/dashboard/widgets/alerts_logs_section.dart';
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
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize controller directly; context.read is safe in initState
    _ctrl = context.read<DashboardController>();
    _ctrl.addListener(_handleControllerChanges);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleControllerChanges);
    _scrollCtrl.dispose();
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
    } else if (!ctrl.isLoading &&
        ctrl.devices.isEmpty &&
        ctrl.connectionStatus == ConnectionStatus.disconnected) {
      content = _buildErrorState(ctrl);
    } else if (!ctrl.wsConnected && ctrl.devices.isEmpty) {
      content = _buildLoadingState('Connecting to HomeGenie stream...');
    } else {
      return _DashboardBody(
        ctrl: ctrl,
        isDark: widget.isDark,
        currentIndex: widget.navIndex,
        onToggleTheme: widget.onToggleTheme,
        onNavTap: widget.onNavTap,
        scrollCtrl: _scrollCtrl,
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
          Text(message, style: TextStyle(color: textSecondary, fontSize: 13)),
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
            Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('Unable to reach server',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 8),
            Text('Make sure the HomeGenie backend is running and accessible.',
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
            Text(
                'Enter your computer\'s LAN IP address (e.g. 192.168.1.50) to connect your mobile device.',
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
                fillColor: widget.isDark
                    ? AppColors.darkSurface2
                    : AppColors.lightSurface2,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD BODY — single layout, responsive internally
// =============================================================================
class _DashboardBody extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final int currentIndex;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;
  final ScrollController scrollCtrl;

  const _DashboardBody({
    required this.ctrl,
    required this.isDark,
    required this.currentIndex,
    required this.scrollCtrl,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final hPad = size.isMobile ? 20.0 : 32.0;

    return Scrollbar(
      controller: scrollCtrl,
      child: RefreshIndicator(
        onRefresh: () async {
          await ctrl.fetchDevices();
          await ctrl.fetchInsights();
        },
        child: CustomScrollView(
          controller: scrollCtrl,
          primary: false,
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Overview',
                subtitle: 'AI Smart Hub',
                isDark: isDark,
                currentIndex: currentIndex,
                onToggleTheme: onToggleTheme,
                onNavTap: onNavTap,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 16),
              sliver: SliverToBoxAdapter(
                child: _OverviewRow(ctrl: ctrl, isDark: isDark, size: size),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
              sliver: SliverToBoxAdapter(
                child: _EnergyPowerSection(
                    ctrl: ctrl, isDark: isDark, size: size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OVERVIEW ROW — Donut + Most Used + Peak Time + Suggestion
// =============================================================================
class _OverviewRow extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final ScreenSize size;

  const _OverviewRow(
      {required this.ctrl, required this.isDark, required this.size});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _DeviceStatusTile(ctrl: ctrl, isDark: isDark),
      _CombinedInsightTile(ctrl: ctrl, isDark: isDark),
      CompactEnergyTile(ctrl: ctrl, isDark: isDark),
      _CombinedAiTile(ctrl: ctrl, isDark: isDark),
    ];

    if (size.isMobile) {
      // 2x2 grid on mobile with adjusted ratio for height
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85, // Taller cells for mobile to avoid overflow
        shrinkWrap: true,
        primary: false, // Fix: PrimaryScrollController conflict
        physics: const NeverScrollableScrollPhysics(),
        children: tiles,
      );
    }
    // Single row on desktop/tablet
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i < tiles.length - 1) const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// TILES
// =============================================================================
abstract class _Tile extends StatelessWidget {
  final bool isDark;
  final bool isCompact;
  const _Tile({required this.isDark, this.isCompact = false});

  Widget buildContent(BuildContext context);
  String get label;
  IconData get icon;

  @override
  Widget build(BuildContext context) {
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: isCompact ? 12 : 14, color: textSec.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: textSec.withValues(alpha: 0.7),
                    fontSize: isCompact ? 8 : 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Expanded(child: buildContent(context)),
        ],
      ),
    );
  }
}

class _DeviceStatusTile extends _Tile {
  final DashboardController ctrl;
  const _DeviceStatusTile({required this.ctrl, required super.isDark});

  @override
  String get label => 'DEVICE STATUS';
  @override
  IconData get icon => Icons.donut_large_rounded;

  @override
  Widget buildContent(BuildContext context) {
    final total = ctrl.devices.length;
    final active = ctrl.devices.where((d) => d.isOn).length;
    final inactive = total - active;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 92,
            width: 92,
            child: CustomPaint(
              painter: _DonutPainter(
                activeRatio: total > 0 ? active / total : 0,
                activeColor: AppColors.primary,
                inactiveColor:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$active',
                        style: TextStyle(
                            color: textPri,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    Text('active',
                        style: TextStyle(color: textSec, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('$active on · $inactive off',
              style: TextStyle(
                  color: textSec, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TopConsumerTile extends _Tile {
  final DashboardController ctrl;
  const _TopConsumerTile({required this.ctrl, required super.isDark, super.isCompact});

  @override
  String get label => 'TOP CONSUMER';
  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  Widget buildContent(BuildContext context) {
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final active = ctrl.devices
        .where((d) => d.isOn && d.powerConsumption > 0)
        .toList()
      ..sort((a, b) {
        final cmp = b.powerConsumption.compareTo(a.powerConsumption);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    if (active.isEmpty) {
      return Center(
        child: Text('No active devices',
            style: TextStyle(color: textSec, fontSize: isCompact ? 10 : 11)),
      );
    }

    final top = active.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(top.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textPri,
                      fontSize: isCompact ? 13 : 15,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text(top.powerConsumption.toStringAsFixed(1),
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: isCompact ? 16 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(width: 2),
            Text('W',
                style: TextStyle(
                    color: textSec, 
                    fontSize: isCompact ? 10 : 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _PeakTimeTile extends _Tile {
  final DashboardController ctrl;
  const _PeakTimeTile({required this.ctrl, required super.isDark, super.isCompact});

  @override
  String get label => 'PEAK ACTIVITY';
  @override
  IconData get icon => Icons.schedule_rounded;

  @override
  Widget buildContent(BuildContext context) {
    final dist =
        (ctrl.analytics['time_distribution'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    String peak = '—';
    int peakVal = 0;
    int total = 0;
    for (final e in dist.entries) {
      final v = (e.value as num).toInt();
      total += v;
      if (v > peakVal) {
        peakVal = v;
        peak = e.key;
      }
    }
    if (peakVal == 0) {
      return Center(
        child: Text('No data yet',
            style: TextStyle(color: textSec, fontSize: isCompact ? 10 : 11)),
      );
    }

    final pct = total > 0 ? (peakVal * 100 / total).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_capitalize(peak),
            style: TextStyle(
                color: textPri,
                fontSize: isCompact ? 20 : 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        SizedBox(height: isCompact ? 2 : 6),
        Text('$peakVal interactions',
            style: TextStyle(
                color: textSec, fontSize: isCompact ? 10 : 12, fontWeight: FontWeight.w600)),
        if (!isCompact) ...[
          const SizedBox(height: 2),
          Text('$pct% of daily activity',
              style: TextStyle(color: textSec, fontSize: 11)),
        ],
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _CombinedAiTile extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _CombinedAiTile({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: AiModelCard(ctrl: ctrl, isDark: isDark, isCompact: true)),
        const SizedBox(height: 12),
        Expanded(child: MergedAiControlCard(ctrl: ctrl, isDark: isDark, isCompact: true)),
      ],
    );
  }
}

class _CombinedInsightTile extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _CombinedInsightTile({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _TopConsumerTile(ctrl: ctrl, isDark: isDark, isCompact: true)),
        const SizedBox(height: 12),
        Expanded(child: _PeakTimeTile(ctrl: ctrl, isDark: isDark, isCompact: true)),
      ],
    );
  }
}


// =============================================================================
// ENERGY + POWER SECTION — two columns on desktop, stacked on mobile
// =============================================================================
class _EnergyPowerSection extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final ScreenSize size;

  const _EnergyPowerSection(
      {required this.ctrl, required this.isDark, required this.size});

  @override
  Widget build(BuildContext context) {
    final simCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: 'SIMULATION', isDark: isDark),
        const SizedBox(height: 12),
        SizedBox(
          height: 430,
          child: Column(
            children: [
              Expanded(child: ContextEventsPanel(ctrl: ctrl, isDark: isDark)),
              const SizedBox(height: 16),
              Expanded(child: ManualOverridesPanel(ctrl: ctrl, isDark: isDark)),
            ],
          ),
        ),
      ],
    );
    final powerCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: 'POWER CONSUMPTION', isDark: isDark),
        const SizedBox(height: 12),
        Container(
          height: 440,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _LiveDevicePowerList(ctrl: ctrl, isDark: isDark),
        ),
      ],
    );
    final logsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: 'ACTIVITY & LOGS', isDark: isDark),
        const SizedBox(height: 12),
        SizedBox(
          height: 430,
          child: AlertsLogsSection(isDark: isDark, forceStacked: true),
        ),
      ],
    );
    if (size.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          powerCol,
          const SizedBox(height: 24),
          simCol,
          const SizedBox(height: 24),
          logsCol,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 330,
          child: powerCol,
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: simCol,
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: logsCol,
        ),
      ],
    );
  }
}

// =============================================================================
// ENERGY ANALYTICS CARD — current demand, top consumer, live sparkline
// =============================================================================
class _EnergyAnalyticsCard extends StatefulWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _EnergyAnalyticsCard({required this.ctrl, required this.isDark});

  @override
  State<_EnergyAnalyticsCard> createState() => _EnergyAnalyticsCardState();
}

class _EnergyAnalyticsCardState extends State<_EnergyAnalyticsCard> {
  final List<double> _spots = [];
  static const _maxSpots = 40;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final cur = widget.ctrl.totalPowerConsumption;
    for (var i = 0; i < _maxSpots ~/ 2; i++) {
      _spots.add(cur);
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _spots.add(widget.ctrl.totalPowerConsumption);
        if (_spots.length > _maxSpots) _spots.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final ctrl = widget.ctrl;
    final size = Breakpoints.of(context);
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final cur = ctrl.totalPowerConsumption;
    final activeDevices =
        ctrl.devices.where((d) => d.isOn && d.powerConsumption > 0).toList()
          ..sort((a, b) => b.powerConsumption.compareTo(a.powerConsumption));
    final topConsumer = activeDevices.isNotEmpty ? activeDevices.first : null;

    final earlier = _spots.length > 10
        ? _spots.sublist(0, _spots.length - 10).reduce((a, b) => a + b) /
            (_spots.length - 10)
        : cur;
    final delta = earlier > 0 ? ((cur - earlier) / earlier * 100) : 0.0;
    final trendUp = delta >= 0;

    final stats = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Demand',
                  style: TextStyle(color: textSec, fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(cur.toStringAsFixed(1),
                      style: TextStyle(
                          color: textPri,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child:
                        Text('W', style: TextStyle(color: textSec, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (trendUp
                                ? AppColors.warning
                                : AppColors.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              trendUp
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 11,
                              color: trendUp
                                  ? AppColors.warning
                                  : AppColors.success),
                          const SizedBox(width: 2),
                          Text(
                              '${delta.abs().toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: trendUp
                                      ? AppColors.warning
                                      : AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('${activeDevices.length} active devices · live',
                  style: TextStyle(color: textSec, fontSize: 11)),
            ],
          ),
        ),
        if (topConsumer != null && !size.isMobile) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 56, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOP CONSUMER',
                    style: TextStyle(
                        color: textSec.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(topConsumer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${topConsumer.powerConsumption.toStringAsFixed(1)} W',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stats,
          const SizedBox(height: 16),
          SizedBox(
            height: size.isMobile ? 80 : 100,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: _spots,
                color: AppColors.primary,
              ),
              size: Size.infinite,
            ),
          ),
          if (topConsumer != null && size.isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Top: ',
                    style: TextStyle(color: textSec, fontSize: 11)),
                Expanded(
                  child: Text(topConsumer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Text('${topConsumer.powerConsumption.toStringAsFixed(1)} W',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);

    final path = Path();
    final fillPath = Path();
    final dx = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final norm = (values[i] - minV) / range;
      final y = size.height - (norm * size.height * 0.85) - size.height * 0.075;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values;
}

// =============================================================================
// LIVE DEVICE POWER LIST — sorted desc, updates via WebSocket
// =============================================================================
class _LiveDevicePowerList extends StatefulWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _LiveDevicePowerList({required this.ctrl, required this.isDark});

  @override
  State<_LiveDevicePowerList> createState() => _LiveDevicePowerListState();
}

class _LiveDevicePowerListState extends State<_LiveDevicePowerList> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final items = List<DeviceInfo>.from(widget.ctrl.devices)
      ..sort((a, b) {
        final cmp = b.powerConsumption.compareTo(a.powerConsumption);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (items.isEmpty) {
      return Container(
        height: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Center(
          child: Text('No devices to display',
              style: TextStyle(color: textSec, fontSize: 12)),
        ),
      );
    }

    final maxPower = items.fold<double>(
        0, (a, b) => b.powerConsumption > a ? b.powerConsumption : a);

    return Container(
      height: 420,
      padding: const EdgeInsets.all(20), // Added consistent internal padding
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView.separated(
          padding: const EdgeInsets.only(right: 8, bottom: 20),
          itemCount: items.length,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _DevicePowerRow(
            device: items[i],
            maxValue: maxPower > 0 ? maxPower : 1,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _DevicePowerRow extends StatelessWidget {
  final DeviceInfo device;
  final double maxValue;
  final bool isDark;

  const _DevicePowerRow({
    required this.device,
    required this.maxValue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final v = device.powerConsumption;
    final fraction = maxValue > 0 ? v / maxValue : 0.0;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final color = device.isOn ? _accentFor(device.type) : Colors.grey;
    final room = _roomOf(device);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconFor(device.type), size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  if (room != null)
                    Text(room,
                        style: TextStyle(
                            color: textSec.withValues(alpha: 0.6), fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Spacer(),
            Text('${v.toStringAsFixed(1)}W',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'light' => Icons.lightbulb_rounded,
        'switch' => Icons.toggle_on_rounded,
        'thermostat' => Icons.thermostat_rounded,
        'lock' => Icons.lock_rounded,
        'media' => Icons.speaker_rounded,
        'sensor' => Icons.sensors_rounded,
        _ => Icons.devices_rounded,
      };

  Color _accentFor(String type) => switch (type) {
        'light' => Colors.amber,
        'thermostat' => AppColors.orange,
        'lock' => AppColors.error,
        'media' => AppColors.primary,
        'sensor' => AppColors.teal,
        _ => AppColors.primary,
      };

  String? _roomOf(DeviceInfo d) {
    final parts = d.key.split('.');
    if (parts.length < 2) return null;
    return parts[1]
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// =============================================================================
// DONUT PAINTER
// =============================================================================
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
    const strokeWidth = 10.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

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

    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);
    if (activeRatio > 0) {
      final sweep = 2 * math.pi * activeRatio;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.activeRatio != activeRatio ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor;
  }
}
