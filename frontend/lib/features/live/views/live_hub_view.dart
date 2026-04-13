import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/models/integration.dart';
import 'package:homegenie_app/features/live/views/platform_setup_view.dart';

class LiveHubView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const LiveHubView({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final isConnected = ctrl.connectionStatus == ConnectionStatus.connected || ctrl.wsConnected;
    final configuredCount = ctrl.integrations.where((p) => p.isConfigured).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Hub',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect and manage real IoT devices',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Connection Status Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _ConnectionBanner(
                isConnected: isConnected,
                serverUrl: ctrl.baseUrl,
                statusMessage: ctrl.statusMessage,
                isDark: isDark,
              ),
            ),
          ),

          // Stats Row — show configured platforms count, no fake device data
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Platforms',
                    value: '$configuredCount / ${ctrl.integrations.isEmpty ? 5 : ctrl.integrations.length}',
                    icon: Icons.extension_rounded,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Devices',
                    value: '--',
                    icon: Icons.devices_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Status',
                    value: isConnected ? 'OK' : '--',
                    icon: Icons.monitor_heart_rounded,
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // Platform Integrations Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Text(
                    'Connect To',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (ctrl.isIntegrationsLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),

          // Platform Cards Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final platforms = ctrl.integrations.isNotEmpty
                      ? ctrl.integrations
                      : PlatformIntegration.defaults();
                  if (index >= platforms.length) return null;
                  final p = platforms[index];
                  return _PlatformCard(
                    integration: p,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlatformSetupView(
                            integration: p,
                            isDark: isDark,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: (ctrl.integrations.isNotEmpty
                        ? ctrl.integrations
                        : PlatformIntegration.defaults())
                    .length,
              ),
            ),
          ),

          // "Your Devices" placeholder section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Text(
                'Your Devices',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

          // Device category placeholder cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ConnectPlaceholderTile(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Lights',
                  hint: 'Connect via Google Home, Alexa, or Zigbee',
                  color: const Color(0xFFFBBF24),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _ConnectPlaceholderTile(
                  icon: Icons.thermostat_outlined,
                  label: 'Thermostats',
                  hint: 'Connect via Google Home or Matter',
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _ConnectPlaceholderTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Locks & Security',
                  hint: 'Connect via Zigbee or Matter',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _ConnectPlaceholderTile(
                  icon: Icons.sensors_rounded,
                  label: 'Sensors',
                  hint: 'Connect via Zigbee or Custom MQTT',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _ConnectPlaceholderTile(
                  icon: Icons.speaker_rounded,
                  label: 'Media & Speakers',
                  hint: 'Connect via Alexa or Google Home',
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _ConnectPlaceholderTile(
                  icon: Icons.power_settings_new_rounded,
                  label: 'Switches & Outlets',
                  hint: 'Connect via Custom MQTT or Zigbee',
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                ),
              ]),
            ),
          ),

          // Bottom info box
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Configure a platform above to discover and control your real smart home devices.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connection Banner
// ---------------------------------------------------------------------------
class _ConnectionBanner extends StatelessWidget {
  final bool isConnected;
  final String serverUrl;
  final String statusMessage;
  final bool isDark;

  const _ConnectionBanner({
    required this.isConnected,
    required this.serverUrl,
    required this.statusMessage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Server Connected' : 'Server Disconnected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (serverUrl.isNotEmpty)
                  Text(
                    serverUrl,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            statusMessage,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Chip
// ---------------------------------------------------------------------------
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform Card
// ---------------------------------------------------------------------------
class _PlatformCard extends StatelessWidget {
  final PlatformIntegration integration;
  final bool isDark;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.integration,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: integration.isConfigured
                ? integration.color.withOpacity(0.4)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black12),
            width: 1.5,
          ),
          boxShadow: [
            if (integration.isConfigured)
              BoxShadow(
                color: integration.color.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: integration.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(integration.icon, color: integration.color, size: 20),
                ),
                const Spacer(),
                if (integration.isConfigured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${integration.deviceCount} devices',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              integration.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              integration.isConfigured ? 'Connected' : 'Tap to connect',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: integration.isConfigured
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connect Placeholder Tile — ghost device row prompting user to connect
// ---------------------------------------------------------------------------
class _ConnectPlaceholderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final bool isDark;

  const _ConnectPlaceholderTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color.withOpacity(0.4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.35) : Colors.black38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black12,
              ),
            ),
            child: Text(
              'Connect',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
