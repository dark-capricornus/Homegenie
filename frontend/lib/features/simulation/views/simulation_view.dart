import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:provider/provider.dart';

class SimulationPage extends StatefulWidget {
  final bool isDark;
  final int navIndex;
  final ValueChanged<int> onNavTap;

  const SimulationPage({
    super.key,
    required this.isDark,
    required this.navIndex,
    required this.onNavTap,
  });

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  bool _engineActive = true;
  final List<String> _activity = [
    'AI Planner Initiated · Queuing evening routine • 5m ago',
    'Environment Updated · Temp sensor recalibrated • 4m ago',
    'Rule Triggered · Hallway Welcome Rule fired • 2m ago',
  ];

  Color get _bg =>
      widget.isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get _surface =>
      widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get _border =>
      widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get _textPrimary =>
      widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

  void _triggerEvent(String event, DashboardController ctrl) {
    setState(() => _activity.insert(0, '$event triggered • just now'));
    if (event.contains('Evening')) {
      ctrl.sendGoal('Simulate evening: dim lights and secure doors');
    } else if (event.contains('Motion')) {
      ctrl.sendGoal('Simulate motion in the hallway');
    } else if (event.contains('Occupancy')) {
      ctrl.sendGoal('Simulate home occupancy');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Engine State card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: _border),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI ENGINE STATUS',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            SizedBox(height: 4),
                            Text('Adaptive Logic Active',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _engineActive
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _engineActive
                              ? 'Active Simulation'
                              : 'Engine Stopped',
                          style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        const Spacer(),
                        Switch(
                          value: _engineActive,
                          onChanged: (v) => setState(() => _engineActive = v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: SimStatusChip(
                          label: 'FRONT ENTRY',
                          value: 'Closed & Secure',
                          icon: Icons.door_front_door_outlined,
                          isDark: widget.isDark,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: SimStatusChip(
                          label: 'ENVIRONMENT',
                          value: '72°F Sunny',
                          icon: Icons.wb_sunny_outlined,
                          isDark: widget.isDark,
                        )),
                      ]),
                    ]),
              ),
              const SizedBox(height: 14),
              // AI AGENT STATUS card (always dark background)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.psychology,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 8),
                        Text('Neural Processing: ON',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: SimAgentChip(
                                label: 'PLANNING',
                                value: 'Active',
                                color: AppColors.success)),
                        SizedBox(width: 8),
                        Expanded(
                            child: SimAgentChip(
                                label: 'MEMORY',
                                value: 'Learning',
                                color: AppColors.primary)),
                        SizedBox(width: 8),
                        Expanded(
                            child: SimAgentChip(
                                label: 'SCHEDULER',
                                value: 'Running',
                                color: AppColors.success)),
                      ]),
                    ]),
              ),
              const SizedBox(height: 14),
              SectionLabel(label: 'CONTEXT EVENTS', isDark: widget.isDark),
              const SizedBox(height: 8),
              SimEventTile(
                  label: 'Simulate Evening',
                  icon: Icons.nightlight_round,
                  color: AppColors.purple,
                  onTap: () => _triggerEvent('Evening Simulation', ctrl),
                  isDark: widget.isDark),
              SimEventTile(
                  label: 'Simulate Occupancy',
                  icon: Icons.groups,
                  color: AppColors.success,
                  onTap: () => _triggerEvent('Occupancy Simulation', ctrl),
                  isDark: widget.isDark),
              SimEventTile(
                  label: 'Simulate Temperature Rise',
                  icon: Icons.thermostat,
                  color: Colors.orange,
                  onTap: () => _triggerEvent('Temperature Simulation', ctrl),
                  isDark: widget.isDark),
              const SizedBox(height: 14),
              SectionLabel(label: 'MANUAL OVERRIDES', isDark: widget.isDark),
              const SizedBox(height: 8),
              SimEventTile(
                  label: 'Simulate Motion',
                  icon: Icons.directions_run,
                  color: AppColors.warning,
                  onTap: () => _triggerEvent('Motion Simulation', ctrl),
                  isDark: widget.isDark),
              SimEventTile(
                  label: 'Open Front Door',
                  icon: Icons.door_sliding_outlined,
                  color: AppColors.primary,
                  onTap: () => _triggerEvent('Front Door Opened', ctrl),
                  isDark: widget.isDark),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: widget.isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  title: Text('Add Custom Event',
                      style: TextStyle(
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 13)),
                  onTap: null,
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                SectionLabel(
                    label: 'RECENT ACTIVITY', isDark: widget.isDark),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _activity.clear()),
                  child: const Text('Clear',
                      style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 6),
              ..._activity.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5, right: 10),
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                          ),
                          Expanded(
                              child: Text(a,
                                  style: TextStyle(
                                      color: widget.isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 12))),
                        ]),
                  )),
            ],
          ),
        ),
      ]),
      // Navigation handled by root_page's ResponsiveScaffold
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PageHeader(
      title: 'Simulation & AI Sandbox',
      isDark: widget.isDark,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => widget.onNavTap(0)),
      actions: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.help_outline, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

// ── Public-named helper widgets (no leading underscore; DDC resolves them fine) ──
class SimStatusChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool isDark;
  const SimStatusChip(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 14),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: textSec, fontSize: 9, fontWeight: FontWeight.w700)),
          Text(value,
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

class SimAgentChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const SimAgentChip(
      {super.key,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}



class SimEventTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  const SimEventTile(
      {super.key,
      required this.label,
      required this.icon,
      required this.color,
      required this.onTap,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: IconBox(icon: icon, color: color, size: 36, iconSize: 18),
        title: Text(label,
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: Icon(Icons.chevron_right, color: tertiary),
        onTap: onTap,
      ),
    );
  }
}
