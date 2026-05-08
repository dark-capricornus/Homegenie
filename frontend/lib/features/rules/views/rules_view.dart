import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/rules/views/advanced_rule_builder_view.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/core/widgets/page_header.dart';
// ── MODEL ──────────────────────────────────────────────────────────
class AutomationRule {
  final String id;
  final String name;
  final String category;
  final String triggerLabel;
  final String actionLabel;
  bool isActive;
  final IconData triggerIcon;
  final IconData actionIcon;
  final Color triggerColor;
  final Color actionColor;

  AutomationRule({
    required this.id,
    required this.name,
    required this.category,
    required this.triggerLabel,
    required this.actionLabel,
    required this.isActive,
    required this.triggerIcon,
    required this.actionIcon,
    required this.triggerColor,
    required this.actionColor,
  });
}

List<AutomationRule> _mockRules() => [
      AutomationRule(
        id: '1',
        name: 'Hallway Welcome Rule',
        category: 'SECURITY',
        triggerLabel: 'Motion is detected in Hallway',
        actionLabel: 'Turn on Hallway Lights to 80%',
        isActive: true,
        triggerIcon: Icons.sensors,
        triggerColor: AppColors.primary,
        actionIcon: Icons.lightbulb,
        actionColor: AppColors.success,
      ),
      AutomationRule(
        id: '2',
        name: 'Morning Routine',
        category: 'COMFORT',
        triggerLabel: 'Time of Day: 07:00 AM, Weekdays',
        actionLabel: 'Master Lights: Set to 80%, Warm White',
        isActive: true,
        triggerIcon: Icons.schedule,
        triggerColor: Colors.orange,
        actionIcon: Icons.lightbulb_outline,
        actionColor: Colors.amber,
      ),
      AutomationRule(
        id: '3',
        name: 'Energy Saver',
        category: 'ENERGY',
        triggerLabel: 'No motion for 30 minutes',
        actionLabel: 'Turn off all lights & lower thermostat to 18°C',
        isActive: false,
        triggerIcon: Icons.sensors_off,
        triggerColor: AppColors.warning,
        actionIcon: Icons.eco,
        actionColor: AppColors.success,
      ),
    ];

// ── RULES PAGE ──────────────────────────────────────────────────────
class RulesPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;

  final int currentIndex;

  const RulesPage({
    super.key,
    required this.isDark,
    required this.currentIndex,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final List<AutomationRule> _rules = _mockRules();

  Color get _textPrimary =>
      widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        PageHeader(
          title: 'Automation Rules',
          subtitle: 'Triggers & Actions',
          isDark: widget.isDark,
          currentIndex: widget.currentIndex,
          onToggleTheme: widget.onToggleTheme,
          onNavTap: widget.onNavTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            children: [
              Row(children: [
                Text('Active Insights',
                    style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdvancedRuleBuilderView()),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Rule'),
                ),
              ]),
              const SizedBox(height: 8),
              ..._rules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RuleCard(
                      rule: rule,
                      isDark: widget.isDark,
                      onToggle: (v) => setState(() => rule.isActive = v),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdvancedRuleBuilderView()),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

}

class RuleCard extends StatelessWidget {
  final AutomationRule rule;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const RuleCard(
      {super.key,
      required this.rule,
      required this.isDark,
      required this.onToggle,
      required this.onTap});

  Color get _border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get _textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppSurface(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Room image placeholder
        Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius)),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.6)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
              child: Icon(Icons.home_outlined,
                  color: Colors.white.withValues(alpha: 0.5), size: 40)),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppBadge(
                label: rule.category,
                backgroundColor: AppColors.badgeSecurityBg,
                textColor: AppColors.badgeSecurityText,
              ),
              const Spacer(),
              Switch(
                value: rule.isActive,
                onChanged: onToggle,
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
            const SizedBox(height: 6),
            Text(rule.name,
                style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 12),
            // IF block
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: rule.triggerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: rule.triggerColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                IconBox(
                  icon: rule.triggerIcon,
                  color: rule.triggerColor,
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('IF',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      Text(rule.triggerLabel,
                          style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ])),
              ]),
            ),
            // Connector
            Center(
                child: Container(
              width: 2,
              height: 16,
              color: _border,
            )),
            // THEN block
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: rule.actionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: rule.actionColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                IconBox(
                  icon: rule.actionIcon,
                  color: rule.actionColor,
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('THEN',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      Text(rule.actionLabel,
                          style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ])),
              ]),
            ),
            const SizedBox(height: 10),
            // AI Insight expander
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.purpleDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.auto_awesome, color: AppColors.purple, size: 14),
                SizedBox(width: 6),
                Text('Why this automation ran',
                    style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Spacer(),
                Icon(Icons.keyboard_arrow_down,
                    color: AppColors.purple, size: 16),
              ]),
            ),
          ]),
        ),
      ]),
    ),
    );
  }
}
