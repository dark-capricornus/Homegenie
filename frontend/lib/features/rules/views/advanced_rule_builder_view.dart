import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

class AdvancedRuleBuilderView extends StatelessWidget {
  const AdvancedRuleBuilderView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Advanced Rule Builder'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRuleHeader(context),
            const SizedBox(height: 32),
            _buildComponentCard(
              context,
              icon: Icons.access_time,
              title: 'Time of Day',
              value: '07:00 AM, Weekdays',
              color: Colors.orange,
            ),
            _buildConnector(),
            _buildComponentCard(
              context,
              icon: Icons.sensor_door_outlined,
              title: 'Bedroom Door',
              value: 'When Door Opens',
              color: Colors.blue,
            ),
            _buildConnector(),
            _buildComponentCard(
              context,
              icon: Icons.light_mode_outlined,
              title: 'Master Lights',
              value: 'Set to 80%, Warm White',
              color: Colors.amber,
            ),
            _buildConnector(),
            _buildComponentCard(
              context,
              icon: Icons.coffee_outlined,
              title: 'Smart Coffee',
              value: 'Turn ON (Pre-heat)',
              color: Colors.brown,
            ),
            const SizedBox(height: 32),
            Center(
              child: Tooltip(
                message: 'Custom component builder coming soon',
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Components'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    disabledForegroundColor: AppColors.primary.withValues(alpha: 0.4),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Morning Routine',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Smart Automation',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(left: 32),
      child: VerticalDivider(
        color: AppColors.primary.withValues(alpha: 0.3),
        thickness: 2,
      ),
    );
  }
}
