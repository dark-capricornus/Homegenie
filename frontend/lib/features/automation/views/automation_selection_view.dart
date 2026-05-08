import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'routine_builder_view.dart';

class AutomationSelectionView extends StatelessWidget {
  const AutomationSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Your Home Automation System',
                    style: TextStyle(fontFamily: 'Outfit', 
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a protocol to begin hardware integration',
                    style: TextStyle(fontFamily: 'Inter', 
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                'Create Automations',
                style: TextStyle(fontFamily: 'Outfit', 
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildAutomationHero(
                context,
                'Visual Routine Builder',
                'Create IF-THEN rules for your smart home devices without writing code.',
                Icons.auto_fix_high_rounded,
                AppColors.primary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Hardware Protocols',
                style: TextStyle(fontFamily: 'Outfit', 
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _buildProtocolCard(
                  context,
                  'Zigbee',
                  'Sensors & Switches',
                  Icons.settings_input_antenna_rounded,
                  const Color(0xFF10B981),
                ),
                _buildProtocolCard(
                  context,
                  'Matter',
                  'Universal standard',
                  Icons.hub_rounded,
                  AppColors.primary,
                ),
                _buildProtocolCard(
                  context,
                  'PLC / Industrial',
                  'Modbus & Controllers',
                  Icons.precision_manufacturing_rounded,
                  Colors.orangeAccent,
                ),
                _buildProtocolCard(
                  context,
                  'Add Custom',
                  'MQTT / REST',
                  Icons.add_rounded,
                  Colors.white.withOpacity(0.2),
                  isPlaceholder: true,
                ),
              ]),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Real-world device communication requires a local HomeGenie Gateway or a compatible bridge.',
                            style: TextStyle(fontFamily: 'Inter', 
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color, {
    bool isPlaceholder = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(isPlaceholder ? 0.05 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isPlaceholder ? 0 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Outfit', 
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', 
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationHero(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RoutineBuilderView()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Outfit', 
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontFamily: 'Inter', 
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 32),
          ],
        ),
      ),
    );
  }
}
