import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/features/live/widgets/live_mode_placeholder.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class EnergyPage extends StatefulWidget {
  final bool isDark;

  const EnergyPage({super.key, required this.isDark});

  @override
  State<EnergyPage> createState() => _EnergyPageState();
}

class _EnergyPageState extends State<EnergyPage> with WidgetsBindingObserver {
  int _periodIndex = 0; // 0=Day, 1=Week, 2=Month
  final List<FlSpot> _liveSpots = [];
  Timer? _liveTimer;
  double _timeCounter = 0;
  static const int _maxSpots = 30; // 60 seconds at 2s interval
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLiveUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _isVisible;
    _isVisible = state == AppLifecycleState.resumed;
    if (_isVisible && !wasVisible) {
      _startLiveUpdate();
    } else if (!_isVisible && wasVisible) {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  void _startLiveUpdate() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isVisible) {
        timer.cancel();
        return;
      }
      final ctrl = Provider.of<DashboardController>(context, listen: false);
      setState(() {
        _timeCounter += 2;
        _liveSpots.add(FlSpot(_timeCounter, ctrl.totalPowerConsumption));
        if (_liveSpots.length > _maxSpots) {
          _liveSpots.removeAt(0);
        }
      });
    });
  }

  Color get _surface =>
      widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get _border =>
      widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get _textPrimary =>
      widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  // Real chart data from controller or live spots
  List<FlSpot> _getChartSpots(DashboardController ctrl) {
    if (_periodIndex == 0) {
      return _liveSpots.isEmpty ? [const FlSpot(0, 0)] : List.from(_liveSpots);
    }
    
    if (ctrl.energyHistory.isEmpty) return [const FlSpot(0, 0)];
    
    return ctrl.energyHistory.asMap().entries.map((e) {
      final value = (e.value['avg_watts'] ?? 0.0).toDouble();
      return FlSpot(e.key.toDouble(), value);
    }).toList();
  }

  final List<Map<String, dynamic>> _devices = [
    {
      'name': 'Air Conditioner',
      'room': 'Living Room · Always On',
      'kwh': '8.2 kWh',
      'pct': 0.34,
      'color': AppColors.primary,
      'icon': Icons.ac_unit,
      'trend': '+4%'
    },
    {
      'name': 'Refrigerator',
      'room': 'Kitchen · Standby',
      'kwh': '4.1 kWh',
      'pct': 0.17,
      'color': Colors.orange,
      'icon': Icons.kitchen,
      'trend': '-2%'
    },
    {
      'name': 'Entertainment Hub',
      'room': 'Bedroom · Standby',
      'kwh': '2.8 kWh',
      'pct': 0.12,
      'color': AppColors.purple,
      'icon': Icons.tv,
      'trend': 'Same'
    },
  ];

  String _formatKwh(DashboardController ctrl) {
    if (_periodIndex == 0) return ctrl.totalPowerConsumption.toStringAsFixed(1);
    
    // For historical, show the sum of avg watts normalized to the period?
    // For now, use a simplified estimate from history
    if (ctrl.energyHistory.isEmpty) return '0.0';
    double total = 0;
    for (var h in ctrl.energyHistory) {
      total += (h['avg_watts'] ?? 0.0).toDouble();
    }
    // Simple Watts -> kWh conversion (assuming hourly samples)
    return (total / 1000).toStringAsFixed(1);
  }

  String get _trend => ['+10%', '-8%', '+5%'][_periodIndex];
  bool get _isPositiveTrend => [true, false, true][_periodIndex];

  List<Map<String, dynamic>> _getDevicesData(DashboardController ctrl) {
    if (_periodIndex == 0 || ctrl.energyBreakdown.isEmpty) return _devices;
    
    return ctrl.energyBreakdown.map((d) {
      final devId = d['device_id'] as String;
      // Try to find device name from controller
      String name = devId;
      try {
        final devInfo = ctrl.devices.firstWhere((x) => x.key == devId);
        name = devInfo.name;
      } catch (_) {}

      return {
        'name': name,
        'room': 'Sensor Obs.',
        'kwh': '${(d['total_watts'] / 1000).toStringAsFixed(2)} kWh',
        'pct': (d['percentage'] ?? 0.0) / 100.0,
        'color': AppColors.primary,
        'icon': Icons.bolt_rounded,
        'trend': '${d['percentage']}%'
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();

    if (!ctrl.isDemoMode) {
      return LiveModePlaceholder(
        title: 'Energy Analytics',
        description: 'Connect your devices in the Live Hub to monitor real-time power consumption and energy trends.',
        icon: Icons.bolt_rounded,
        isDark: widget.isDark,
      );
    }

    return Column(children: [
      _buildHeader(context),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Period selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                  children: ['Live', 'Week', 'Month'].asMap().entries.map((e) {
                final sel = e.key == _periodIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _periodIndex = e.key);
                      if (e.key == 1) ctrl.fetchEnergyData(days: 7);
                      if (e.key == 2) ctrl.fetchEnergyData(days: 30);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel ? Colors.white : _textSecondary,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          )),
                    ),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 16),
            // Total stat + chart
            AppSurface(
              isDark: widget.isDark,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _periodIndex == 0
                            ? 'Current Demand'
                            : 'Total Consumption',
                        style: TextStyle(color: _textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_formatKwh(ctrl),
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(_periodIndex == 0 ? 'W' : 'kWh',
                            style:
                                TextStyle(color: _textSecondary, fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: AppBadge(
                          label: _trend,
                          backgroundColor: _isPositiveTrend
                              ? AppColors.successDim
                              : AppColors.warningDim,
                          textColor: _isPositiveTrend
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: LineChart(LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: _border, strokeWidth: 1),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: _periodIndex == 0
                            ? (_timeCounter - (_maxSpots * 2))
                            : null,
                        maxX: _periodIndex == 0 ? _timeCounter : null,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _getChartSpots(ctrl),
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
                                  AppColors.primary.withValues(alpha: 0)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      )),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
            // Top Devices
            Row(children: [
              Text('Top Consuming Devices',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('View All',
                    style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            if (ctrl.isHistoryLoading && _periodIndex != 0)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else
              ..._getDevicesData(ctrl).map(
                (d) => _DeviceConsumptionRow(data: d, isDark: widget.isDark)),
            const SizedBox(height: 16),
            // Eco Tip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      const Text('Eco-Tip of the Day',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                          'Increasing your AC temperature by just 2°C can save up to 15% on your daily energy bill.',
                          style:
                              TextStyle(color: _textSecondary, fontSize: 12)),
                    ])),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildHeader(BuildContext context) {
    return PageHeader(
      title: 'Energy Analytics',
      isDark: widget.isDark,
      actions: [
        IconButton(
            icon: Icon(Icons.share_outlined, color: _textSecondary),
            onPressed: () {}),
      ],
    );
  }
}

class _DeviceConsumptionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _DeviceConsumptionRow({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final color = data['color'] as Color;

    return AppSurface(
      isDark: isDark,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          IconBox(
            icon: data['icon'] as IconData,
            color: color,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(data['name'] as String,
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(data['room'] as String,
                    style: TextStyle(color: textSecondary, fontSize: 11)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(data['kwh'] as String,
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text(data['trend'] as String,
                style: TextStyle(
                    color: (data['trend'] as String).startsWith('+')
                        ? AppColors.success
                        : textSecondary,
                    fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (data['pct'] as double),
          backgroundColor: border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(2),
        ),
      ]),
    );
  }
}
