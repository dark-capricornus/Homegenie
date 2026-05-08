import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';

/// Live energy analytics module embedded in the dashboard on desktop/web.
/// Replaces the dedicated EnergyPage on those layouts by streaming a sliding
/// window of total power consumption and listing the top live consumers.
class LiveEnergyAnalyticsSection extends StatefulWidget {
  final bool isDark;
  final bool stacked;

  const LiveEnergyAnalyticsSection({
    super.key,
    required this.isDark,
    this.stacked = false,
  });

  @override
  State<LiveEnergyAnalyticsSection> createState() =>
      _LiveEnergyAnalyticsSectionState();
}

class _LiveEnergyAnalyticsSectionState extends State<LiveEnergyAnalyticsSection>
    with WidgetsBindingObserver {
  static const int _maxSpots = 30; // 60s @ 2s interval
  static const _deviceColors = [
    AppColors.primary,
    Colors.orange,
    AppColors.purple,
    AppColors.success,
    AppColors.warning,
  ];

  final List<FlSpot> _liveSpots = [];
  Timer? _liveTimer;
  double _t = 0;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _visible;
    _visible = state == AppLifecycleState.resumed;
    if (_visible && !wasVisible) {
      _start();
    } else if (!_visible && wasVisible) {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  void _start() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_visible) {
        timer.cancel();
        return;
      }
      final ctrl = Provider.of<DashboardController>(context, listen: false);
      setState(() {
        _t += 2;
        _liveSpots.add(FlSpot(_t, ctrl.totalPowerConsumption));
        if (_liveSpots.length > _maxSpots) _liveSpots.removeAt(0);
      });
    });
  }

  Color get _border =>
      widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get _textPrimary =>
      widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  static IconData _iconForType(String type) {
    switch (type) {
      case 'light':
        return Icons.lightbulb_outline;
      case 'thermostat':
        return Icons.thermostat;
      case 'switch':
        return Icons.power;
      case 'lock':
        return Icons.lock_outline;
      case 'sensor':
        return Icons.sensors;
      default:
        return Icons.bolt_rounded;
    }
  }

  List<Map<String, dynamic>> _topConsumers(DashboardController ctrl) {
    final total = ctrl.totalPowerConsumption;
    if (total <= 0) return [];
    final active = ctrl.devices
        .where((d) => d.isOn && d.powerConsumption > 0)
        .toList()
      ..sort((a, b) => b.powerConsumption.compareTo(a.powerConsumption));
    return active.asMap().entries.map((e) {
      final d = e.value;
      final pct = d.powerConsumption / total;
      return {
        'name': d.name,
        'kwh': '${d.powerConsumption.toStringAsFixed(1)} W',
        'pct': pct,
        'color': _deviceColors[e.key % _deviceColors.length],
        'icon': _iconForType(d.type),
        'trend': '${(pct * 100).toStringAsFixed(0)}%',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final consumers = _topConsumers(ctrl);
    final spots = _liveSpots.isEmpty ? [const FlSpot(0, 0)] : List<FlSpot>.from(_liveSpots);

    if (widget.stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildChartCard(ctrl, spots),
          const SizedBox(height: 16),
          _buildConsumersCard(consumers),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _buildChartCard(ctrl, spots)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildConsumersCard(consumers)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildEcoTip(),
      ],
    );
  }

  Widget _buildChartCard(DashboardController ctrl, List<FlSpot> spots) {
    return AppSurface(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Live Demand',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              const Spacer(),
              AppBadge(
                label: 'Live',
                backgroundColor: AppColors.successDim,
                textColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ctrl.totalPowerConsumption.toStringAsFixed(1),
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('W active',
                    style: TextStyle(color: _textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              '${ctrl.devices.where((d) => d.isOn).length} of ${ctrl.devices.length} devices drawing power',
              style: TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: _border, strokeWidth: 1),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: _t - (_maxSpots * 2),
              maxX: _t == 0 ? 1 : _t,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.primary.withValues(alpha: 0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumersCard(List<Map<String, dynamic>> consumers) {
    return AppSurface(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Power Consumption by Devices',
                    style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (consumers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No active draw',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: consumers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _ConsumerRow(data: consumers[i], isDark: widget.isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEcoTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDim,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.tips_and_updates,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Eco-Tip',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    'Increasing your AC temperature by just 2°C can save up to 15% on your daily energy bill.',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumerRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _ConsumerRow({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final color = data['color'] as Color;

    return Column(
      children: [
        Row(
          children: [
            IconBox(
              icon: data['icon'] as IconData,
              color: color,
              size: 32,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(data['name'] as String,
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(data['kwh'] as String,
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                Text(data['trend'] as String,
                    style: TextStyle(color: textSecondary, fontSize: 10)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (data['pct'] as double).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
