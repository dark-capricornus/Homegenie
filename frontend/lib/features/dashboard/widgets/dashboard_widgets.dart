import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/shared/widgets/status_chip.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';

// =============================================================================
// TOP STATUS CHIP
// =============================================================================
class TopStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;

  const TopStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// ENTITY TILE
// =============================================================================
// =============================================================================
// UNIFIED DEVICE CARD
// =============================================================================
class UnifiedDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final String? roomName;
  final bool isDark;
  final DashboardController controller;

  const UnifiedDeviceCard({
    super.key,
    required this.device,
    this.roomName,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = controller.deviceToggles[device.key] ?? device.isActive;
    final accentColor = _getDeviceColor();
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      height: 100,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleMainTap(context),
            splashColor: accentColor.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildCardContent(isOn, textPri, textSec, accentColor, context),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMainTap(BuildContext context) {
    debugPrint('UnifiedDeviceCard: Card tapped for ${device.name}');
    _showDeviceDetail(context);
  }

  void _showDeviceDetail(BuildContext context) {
    try {
      showDialog(
        context: context,
        useRootNavigator: true, // Ensures the dialog appears above all layers
        builder: (context) => DeviceDetailDialog(
          device: device,
          roomName: roomName,
          isDark: isDark,
          controller: controller,
        ),
      );
    } catch (e, stack) {
      debugPrint('Error showing DeviceDetailDialog: $e');
      debugPrint(stack.toString());
    }
  }

  Widget _buildCardContent(bool isOn, Color textPri, Color textSec, Color accentColor, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                debugPrint('UnifiedDeviceCard: Icon toggle for ${device.name}');
                controller.toggleDevice(device);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOn ? accentColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isOn ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] : [],
                ),
                child: Icon(
                  _getDeviceIcon(isOn),
                  color: isOn ? accentColor : textSec.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getNumericStatus(isOn),
                    style: TextStyle(
                      color: isOn ? accentColor : textSec.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (device.type == 'thermostat') ...[
              _CompactControlButton(
                icon: Icons.remove,
                onTap: () => controller.sendGoal('Lower temperature in ${device.name}'),
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              Text(
                '${device.targetTemperature?.toInt() ?? 21}',
                style: TextStyle(color: textPri, fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(width: 4),
              _CompactControlButton(
                icon: Icons.add,
                onTap: () => controller.sendGoal('Increase temperature in ${device.name}'),
                isDark: isDark,
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _getNumericStatus(bool isOn) {
    if (device.type == 'lock') {
      final pos = device.position ?? (isOn ? 100 : 0);
      return '$pos% Locked';
    }
    if (device.type == 'gate' || device.type == 'cover') {
      final pos = device.position ?? (isOn ? 100 : 0);
      return '$pos% Open';
    }
    if (!isOn) return 'Off';
    if (device.type == 'light' && device.brightness != null) return '${device.brightness}%';
    if (device.type == 'thermostat' && device.targetTemperature != null) return '${device.targetTemperature}\u00B0';
    return 'On';
  }

  Widget _buildDeviceSpecificControls(bool isOn, Color textPri, Color textSec, Color accentColor) {
    switch (device.type) {
      case 'thermostat':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ControlButton(
              icon: Icons.remove_rounded,
              color: accentColor,
              onTap: () => controller.sendGoal('Lower temperature in ${device.name}'),
              isDark: isDark,
            ),
            Text(
              '${device.targetTemperature ?? 21}\u00B0',
              style: TextStyle(color: textPri, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            _ControlButton(
              icon: Icons.add_rounded,
              color: accentColor,
              onTap: () => controller.sendGoal('Increase temperature in ${device.name}'),
              isDark: isDark,
            ),
          ],
        );
      
      case 'lock':
        return Container(
          width: double.infinity,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: !isOn ? [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: ElevatedButton(
            onPressed: () => controller.toggleDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOn ? accentColor.withValues(alpha: 0.05) : accentColor,
              foregroundColor: isOn ? accentColor : Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: accentColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isOn ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${device.position ?? (isOn ? 100 : 0)}% LOCKED',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        );

      case 'gate':
      case 'cover':
        return Container(
          width: double.infinity,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: isOn ? [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: ElevatedButton(
            onPressed: () => controller.toggleDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOn ? accentColor : accentColor.withValues(alpha: 0.05),
              foregroundColor: isOn ? Colors.white : accentColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: accentColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isOn ? Icons.door_sliding_rounded : Icons.sensor_door_rounded, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${device.position ?? (isOn ? 100 : 0)}% OPEN',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        );

      case 'sensor':
        if (device.key.contains('temperature')) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${device.data['state'] ?? 'N/A'}',
                style: TextStyle(color: textPri, fontSize: 20, fontWeight: FontWeight.w300),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('\u00B0C', style: TextStyle(color: textSec, fontSize: 10)),
              ),
            ],
          );
        }
        return const SizedBox.shrink();

      case 'cover':
      case 'gate':
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Position', style: TextStyle(color: textSec, fontSize: 10)),
                Text('${device.data['position'] ?? 0}%', style: TextStyle(color: textPri, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: textSec.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((device.data['position'] ?? 0) as num) / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Color _getDeviceColor() {
    switch (device.type) {
      case 'light': return Colors.amber;
      case 'thermostat': return Colors.deepOrange;
      case 'lock': return Colors.indigo;
      case 'switch': return Colors.blue;
      case 'sensor': return Colors.teal;
      case 'media': return Colors.purple;
      case 'gate': return Colors.green;
      case 'cover': return Colors.cyan;
      default: return AppColors.primary;
    }
  }

  IconData _getDeviceIcon(bool isOn) {
    switch (device.type) {
      case 'light': return Icons.wb_incandescent_rounded;
      case 'thermostat': return Icons.thermostat_rounded;
      case 'lock': return isOn ? Icons.lock_rounded : Icons.lock_open_rounded;
      case 'switch': return Icons.power_rounded;
      case 'sensor': return Icons.sensors_rounded;
      case 'media': return Icons.speaker_group_rounded;
      case 'gate': return Icons.garage_rounded;
      case 'cover': return Icons.blinds_rounded;
      default: return Icons.devices_other_rounded;
    }
  }

  String _getStatusText(bool isOn) {
    if (device.type == 'lock') return isOn ? 'SECURED' : 'UNLOCKED';
    if (device.type == 'thermostat') return 'TARGET';
    return isOn ? 'ACTIVE' : 'INACTIVE';
  }
}

// =============================================================================
// THERMAL DEVICE CARD (HIGH FIDELITY)
// =============================================================================
class ThermalDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isDark;
  final DashboardController controller;

  const ThermalDeviceCard({
    super.key,
    required this.device,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentColor = AppColors.orange;
    final controlBg = isDark ? AppColors.darkSurface2 : const Color(0xFFF2F2F2);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDeviceDetail(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon Stack
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.home_rounded, color: accentColor, size: 24),
                                  Positioned(
                                    top: 11,
                                    child: Text(
                                      "1",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: surface, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1.5),
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.waves_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: TextStyle(
                                color: textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Comfort · ${device.temperature?.toStringAsFixed(1) ?? "21.7"} \u00B0C',
                              style: TextStyle(
                                color: textSec,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: controlBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _ThermalControlButton(
                          icon: Icons.remove,
                          onTap: () {
                            final current = device.targetTemperature ?? 21.0;
                            controller.updateDeviceValue(
                                device, 'target_temperature', current - 0.5);
                          },
                          isDark: isDark,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${device.targetTemperature?.toStringAsFixed(1) ?? "21.0"} \u00B0C',
                              style: TextStyle(
                                color: textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        _ThermalControlButton(
                          icon: Icons.add,
                          onTap: () {
                            final current = device.targetTemperature ?? 21.0;
                            controller.updateDeviceValue(
                                device, 'target_temperature', current + 0.5);
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeviceDetail(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => DeviceDetailDialog(
        device: device,
        isDark: isDark,
        controller: controller,
      ),
    );
  }
}

class _ThermalControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _ThermalControlButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}


// =============================================================================
// ROOM SECTION
// =============================================================================
class RoomSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isDark;
  final String? subtitle;

  const RoomSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: textPri.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: TextStyle(
                    color: textPri,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(width: 12),
              Expanded(child: Divider(color: textPri.withValues(alpha: 0.1), thickness: 1)),
              if (subtitle != null) ...[
                const SizedBox(width: 12),
                Text(subtitle!, style: TextStyle(color: textSec.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            // More dynamic column counting:
            // < 280: 1 col
            // 280 - 520: 2 cols
            // > 520: 3 cols
            final crossAxisCount = constraints.maxWidth < 280 
                ? 1 
                : (constraints.maxWidth < 520 ? 2 : 3);
                
            final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: children.map((child) => SizedBox(
                width: itemWidth,
                child: child,
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}
// =============================================================================
// SMART SUGGESTION BANNER
// =============================================================================
class SmartSuggestionBanner extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const SmartSuggestionBanner({
    super.key,
    required this.ctrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = ctrl.suggestions;
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (items.isEmpty) return const SizedBox.shrink();

    final s = items.first;
    final confidence = (s['confidence'] ?? 0.0) as num;
    final pct = (confidence * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s['title'] ?? 'Smart Suggestion',
                      style: TextStyle(color: textPri, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pct% confidence',
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s['description'] ?? '',
                  style: TextStyle(color: textSec, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPACT ENERGY TILE
// =============================================================================
class CompactEnergyTile extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const CompactEnergyTile({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final cur = ctrl.totalPowerConsumption;

    return RepaintBoundary(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 12, color: textSec.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('ENERGY',
                  style: TextStyle(
                    color: textSec.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          const SizedBox(height: 8), 
          Text(
            '${cur.toStringAsFixed(1)} W',
            style: TextStyle(
                color: textPri,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Text('Demand', style: TextStyle(color: textSec, fontSize: 10)),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 60,
            child: RepaintBoundary(
              child: ValueListenableBuilder<List<double>>(
                valueListenable: ctrl.powerSpotsNotifier,
                builder: (_, spots, __) => CustomPaint(
                  painter: _SparklinePainter(
                    values: spots,
                    color: AppColors.primary,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

// Reuse the sparkline painter from dashboard_view or define it here if needed.
// Since it's private in dashboard_view.dart, I'll add a simplified version here.
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
      final y = size.height - (norm * size.height * 0.8) - size.height * 0.1;
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
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) {
    if (old.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (old.values[i] != values[i]) return true;
    }
    return old.color != color;
  }
}

// =============================================================================
// AI ENGINE STATUS TILE
// =============================================================================
// AI MODEL CARD
// =============================================================================
// AI MODEL CARD (Compact Version)
// =============================================================================
class AiModelCard extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final bool isCompact;

  const AiModelCard({
    super.key, 
    required this.ctrl, 
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final active = ctrl.aiEngineActive;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, 
                  size: isCompact ? 12 : 14, 
                  color: textSec.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('ACTIVE MODEL',
                  style: TextStyle(
                    color: textSec.withValues(alpha: 0.5),
                    fontSize: isCompact ? 8 : 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          SizedBox(height: isCompact ? 4 : 16),
          Text(
            active ? 'Qwen 2.5' : 'Offline',
            style: TextStyle(
                color: textPri,
                fontSize: isCompact ? 20 : 26,
                fontWeight: FontWeight.w700),
          ),
          if (!isCompact) const SizedBox(height: 4),
          Text(
            active ? '7B Parameters' : 'System idle',
            style: TextStyle(
                color: active ? AppColors.primary : textSec.withValues(alpha: 0.6),
                fontSize: isCompact ? 10 : 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// MERGED AI CONTROL CARD (Toggle + Agents)
// =============================================================================
class MergedAiControlCard extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final bool isCompact;

  const MergedAiControlCard({
    super.key, 
    required this.ctrl, 
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final active = ctrl.aiEngineActive;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, 
                  size: isCompact ? 12 : 14, 
                  color: textSec.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('AI ENGINE',
                  style: TextStyle(
                    color: textSec.withValues(alpha: 0.5),
                    fontSize: isCompact ? 8 : 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
              const Spacer(),
              _buildToggle(active, textSec, isCompact),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                active ? 'ACTIVE' : 'OFF',
                style: TextStyle(
                    color: active ? AppColors.success : textPri.withValues(alpha: 0.3),
                    fontSize: isCompact ? 16 : 20,
                    fontWeight: FontWeight.w900),
              ),
              if (active)
                Wrap(
                  spacing: 4,
                  children: [
                    _MiniAgentChip(label: 'P', color: AppColors.success),
                    _MiniAgentChip(label: 'M', color: AppColors.primary),
                    _MiniAgentChip(label: 'E', color: AppColors.success),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(bool active, Color textSec, bool isCompact) {
    return GestureDetector(
      onTap: () => ctrl.toggleAiEngine(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: isCompact ? 32 : 44,
        height: isCompact ? 16 : 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? AppColors.primary : textSec.withValues(alpha: 0.15),
          border: Border.all(
            color: active ? AppColors.primary : textSec.withValues(alpha: 0.1),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: isCompact ? 12 : 18,
            height: isCompact ? 12 : 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAgentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniAgentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK ACTIONS PANEL
// =============================================================================
// CONTEXT EVENTS PANEL
// =============================================================================
class ContextEventsPanel extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const ContextEventsPanel({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTEXT EVENTS',
            style: TextStyle(
              color: textPri.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ContextEventTile(
                  label: 'Simulate Evening',
                  icon: Icons.nights_stay_rounded,
                  color: AppColors.purple,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Simulate evening: dim lights'),
                ),
                const SizedBox(height: 10),
                _ContextEventTile(
                  label: 'Simulate Occupancy',
                  icon: Icons.people_rounded,
                  color: AppColors.success,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Simulate occupancy in living room'),
                ),
                const SizedBox(height: 10),
                _ContextEventTile(
                  label: 'Simulate Temperature',
                  icon: Icons.thermostat_rounded,
                  color: AppColors.orange,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Simulate temperature rise'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// MANUAL OVERRIDES PANEL
// =============================================================================
class ManualOverridesPanel extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const ManualOverridesPanel({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MANUAL OVERRIDES',
            style: TextStyle(
              color: textPri.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ContextEventTile(
                  label: 'Simulate Motion',
                  icon: Icons.directions_run_rounded,
                  color: AppColors.warning,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Simulate motion in the hallway'),
                ),
                const SizedBox(height: 10),
                _ContextEventTile(
                  label: 'Open Front Door',
                  icon: Icons.door_sliding_outlined,
                  color: AppColors.primary,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Simulate front door opening'),
                ),
                const SizedBox(height: 10),
                _ContextEventTile(
                  label: 'Lock All Doors',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.error,
                  isDark: isDark,
                  onTap: () => ctrl.sendGoal('Secure all entry points'),
                ),
                const SizedBox(height: 12),
                // Add New Override Option
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: textPri.withValues(alpha: 0.1),
                        style: BorderStyle.solid, // Using solid for simplicity, can use CustomPaint for dotted
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 16, color: textSec),
                        const SizedBox(width: 8),
                        Text('Add New Override', style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextEventTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ContextEventTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSec.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DEVICE DETAIL DIALOG (Home Assistant Style)
// =============================================================================
class DeviceDetailDialog extends StatefulWidget {
  final DeviceInfo device;
  final String? roomName;
  final bool isDark;
  final DashboardController controller;

  const DeviceDetailDialog({
    super.key,
    required this.device,
    this.roomName,
    required this.isDark,
    required this.controller,
  });

  @override
  State<DeviceDetailDialog> createState() => _DeviceDetailDialogState();
}

class _DeviceDetailDialogState extends State<DeviceDetailDialog> {
  late double _currentValue;
  late bool _isOn;
  bool _showColorPicker = false;
  late String _currentMode;
  late String _currentPreset;

  @override
  void initState() {
    super.initState();
    _isOn = widget.controller.deviceToggles[widget.device.key] ?? widget.device.isActive;
    _currentValue = widget.device.brightness?.toDouble() ?? 
                   widget.device.targetTemperature ?? 
                   widget.device.temperature ?? 0.0;
    
    _currentMode = widget.device.state['hvac_mode'] ?? 'Heat';
    _currentPreset = widget.device.state['preset_mode'] ?? 'Comfort';
    
    // Listen for external updates (WebSocket/Fetch) to keep dialog in sync
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    if (!mounted) return;
    
    // Find the latest device data from controller
    final updatedDevice = widget.controller.devices.firstWhere(
      (d) => d.key == widget.device.key,
      orElse: () => widget.device,
    );

    setState(() {
      _isOn = widget.controller.deviceToggles[updatedDevice.key] ?? updatedDevice.isActive;
      // Only sync value if not currently interacting
      _currentValue = updatedDevice.brightness?.toDouble() ?? 
                     updatedDevice.targetTemperature ?? 
                     updatedDevice.temperature ?? _currentValue;
      
      _currentMode = updatedDevice.state['hvac_mode'] ?? 'Heat';
      _currentPreset = updatedDevice.state['preset_mode'] ?? 'Comfort';
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? AppColors.darkSurface : Colors.white;
    final textPri = widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Close & Info
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HeaderAction(
                    icon: Icons.close_rounded, 
                    onTap: () => Navigator.pop(context),
                    isDark: widget.isDark,
                  ),
                  Text(
                    widget.device.name,
                    style: TextStyle(
                      color: textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _HeaderAction(
                    icon: Icons.show_chart_rounded, 
                    onTap: () {},
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),            // Large Value Display (Hidden for thermostats as it's redundant)
            if (widget.device.type != 'thermostat') ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  Text(
                    _getValueString(),
                    style: TextStyle(
                      color: textPri,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    _getSubLabel(),
                    style: TextStyle(
                      color: textSec,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ] else 
              const SizedBox(height: 8),


            // Device-Specific Main Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildMainControl(),
            ),

            // Footer Action Row (Hidden for thermostats as modes are integrated)
            if (widget.device.type != 'thermostat')
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _buildActionRow(),
              )
            else
              const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControl() {
    switch (widget.device.type) {
      case 'light': return _buildVerticalSlider(Colors.orange);
      case 'thermostat': return _buildCircularDial(AppColors.orange);
      case 'cover':
      case 'gate':
      case 'lock':
        return _buildSemicircleSlider(_getAccentColor());
      case 'media': return _buildMediaControls();
      default: return _buildLargeToggle();
    }
  }

  Widget _buildVerticalSlider(Color color) {
    final room = widget.roomName?.toLowerCase() ?? '';
    // Be less aggressive with outdoor check - only block if it's explicitly a yard/exterior type
    final isOutdoor = room == 'yard' || room == 'exterior' || room == 'garden';
    final showColors = widget.device.type == 'light' && !isOutdoor && _showColorPicker;

    return Column(
      children: [
        Container(
          height: 280, // Reduced from 320 to fit color dots on screen
          width: 140,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(50),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        final delta = details.primaryDelta! / constraints.maxHeight;
                        _currentValue = (_currentValue - delta * 100).clamp(0.0, 100.0);
                      });
                    },
                    onVerticalDragEnd: (_) {
                      widget.controller.updateDeviceValue(widget.device, 'brightness', _currentValue.toInt());
                    },
                    child: FractionallySizedBox(
                      heightFactor: _currentValue / 100,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: (constraints.maxHeight * (_currentValue / 100)).clamp(10.0, constraints.maxHeight - 10.0),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (showColors) ...[
          const SizedBox(height: 24),
          _GradientColorPicker(
            isDark: widget.isDark,
            onColorChanged: (color) {
              // Convert color to a simple name or hex for the backend
              final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
              widget.controller.updateDeviceValue(widget.device, 'color', hex);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCircularDial(Color color) {
    final textPri = widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      children: [
        // Current temperature display - subtle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Currently ',
              style: TextStyle(color: textSec.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${widget.device.temperature?.toStringAsFixed(1) ?? "21.7"}\u00B0C',
              style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          width: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _SemicircleSlider(
                value: (_currentValue - 15) / 15,
                color: color,
                isDark: widget.isDark,
                onChanged: (val) {
                  setState(() => _currentValue = 15 + (val * 15));
                  widget.controller.updateDeviceValue(widget.device, 'target_temperature', _currentValue);
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isOn ? 'Heating' : 'Off',
                    style: TextStyle(
                      color: _isOn ? color : textSec.withOpacity(0.3),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentValue.toInt()}',
                        style: TextStyle(
                          color: textPri,
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          '.${(_currentValue % 1 * 10).toInt()}',
                          style: TextStyle(
                            color: textPri.withOpacity(0.8),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 4),
                        child: Text(
                          '\u00B0',
                          style: TextStyle(
                            color: textSec.withOpacity(0.4),
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Plus/Minus Buttons - Downscaled for cleaner UI
              Positioned(
                bottom: 12,
                child: Row(
                  children: [
                    _DialButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        setState(() => _currentValue = (_currentValue - 0.5).clamp(15.0, 30.0));
                        widget.controller.updateDeviceValue(widget.device, 'target_temperature', _currentValue);
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(width: 24),
                    _DialButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        setState(() => _currentValue = (_currentValue + 0.5).clamp(15.0, 30.0));
                        widget.controller.updateDeviceValue(widget.device, 'target_temperature', _currentValue);
                      },
                      isDark: widget.isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SelectionChip(
              label: 'Mode',
              value: _currentMode,
              icon: Icons.fireplace_rounded,
              isDark: widget.isDark,
              onTapDown: (details) => _showModePicker(details.globalPosition),
            ),
            const SizedBox(width: 16),
            _SelectionChip(
              label: 'Preset',
              value: _currentPreset,
              icon: Icons.weekend_rounded,
              isDark: widget.isDark,
              onTapDown: (details) => _showPresetPicker(details.globalPosition),
            ),
          ],
        ),
      ],
    );
  }

  void _showModePicker(Offset position) {
    final modes = ['Auto', 'Heat', 'Off'];
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: modes.map((m) => PopupMenuItem(
        value: m,
        child: Row(
          children: [
            Icon(_getModeIcon(m), size: 18, color: _currentMode == m ? AppColors.primary : null),
            const SizedBox(width: 12),
            Text(m, style: TextStyle(fontWeight: _currentMode == m ? FontWeight.bold : null)),
          ],
        ),
      )).toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).then((val) {
      if (val != null) {
        setState(() => _currentMode = val);
        widget.controller.updateDeviceValue(widget.device, 'hvac_mode', val);
      }
    });
  }

  void _showPresetPicker(Offset position) {
    final presets = ['Comfort', 'Away', 'Eco', 'Frost Protection', 'Home'];
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: presets.map((p) => PopupMenuItem(
        value: p,
        child: Row(
          children: [
            Icon(_getPresetIcon(p), size: 18, color: _currentPreset == p ? AppColors.orange : null),
            const SizedBox(width: 12),
            Text(p, style: TextStyle(fontWeight: _currentPreset == p ? FontWeight.bold : null)),
          ],
        ),
      )).toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).then((val) {
      if (val != null) {
        setState(() => _currentPreset = val);
        widget.controller.updateDeviceValue(widget.device, 'preset_mode', val);
      }
    });
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'auto': return Icons.autorenew_rounded;
      case 'heat': return Icons.fireplace_rounded;
      default: return Icons.power_settings_new_rounded;
    }
  }

  IconData _getPresetIcon(String preset) {
    switch (preset.toLowerCase()) {
      case 'comfort': return Icons.weekend_rounded;
      case 'away': return Icons.directions_walk_rounded;
      case 'eco': return Icons.eco_rounded;
      case 'frost protection': return Icons.ac_unit_rounded;
      case 'home': return Icons.home_rounded;
      default: return Icons.settings_rounded;
    }
  }

  Widget _buildMediaControls() {
    return Column(
      children: [
        Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=200&h=200&fit=crop'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MediaButton(icon: Icons.skip_previous_rounded, isDark: widget.isDark),
            const SizedBox(width: 24),
            _MediaButton(icon: Icons.play_arrow_rounded, isDark: widget.isDark, isLarge: true),
            const SizedBox(width: 24),
            _MediaButton(icon: Icons.skip_next_rounded, isDark: widget.isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildLargeToggle() {
    final color = _getAccentColor();
    return GestureDetector(
      onTap: () {
        setState(() => _isOn = !_isOn);
        widget.controller.toggleDevice(widget.device);
      },
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: _isOn ? color.withOpacity(0.1) : (widget.isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
          shape: BoxShape.circle,
          boxShadow: _isOn ? [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
          ] : [],
        ),
        child: Icon(
          _getToggleIcon(),
          size: 80,
          color: _isOn ? color : (widget.isDark ? Colors.white24 : Colors.black26),
        ),
      ),
    );
  }

  IconData _getToggleIcon() {
    if (widget.device.type == 'lock') {
      return _isOn ? Icons.lock_rounded : Icons.lock_open_rounded;
    }
    if (widget.device.type == 'gate' || widget.device.type == 'cover') {
      return _isOn ? Icons.door_sliding_rounded : Icons.sensor_door_rounded;
    }
    return Icons.power_settings_new_rounded;
  }

  String _getSubLabel() {
    switch (widget.device.type) {
      case 'light': return 'Brightness';
      case 'thermostat': return 'Target Temperature';
      case 'lock': return 'Security Status';
      case 'cover':
      case 'gate': return 'Current Position';
      default: return 'Device Status';
    }
  }

  Widget _buildSemicircleSlider(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _SemicircleSlider(
          value: _currentValue / 100.0,
          color: color,
          isDark: widget.isDark,
          onChanged: (val) {
            setState(() => _currentValue = val * 100);
            widget.controller.updateDeviceValue(widget.device, 'position', (val * 100).toInt());
          },
        ),
        // Central interaction icon
        GestureDetector(
          onTap: () {
            setState(() {
              _isOn = !_isOn;
              _currentValue = _isOn ? 100.0 : 0.0;
            });
            widget.controller.toggleDevice(widget.device);
            widget.controller.updateDeviceValue(widget.device, 'position', _currentValue.toInt());
          },
          child: Icon(
            _getToggleIcon(),
            size: 64,
            color: _isOn ? color : (widget.isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ],
    );
  }

  String _getValueString() {
    if (widget.device.type == 'light') return '${_currentValue.toInt()}%';
    if (widget.device.type == 'thermostat') return '${_currentValue.toStringAsFixed(1)}\u00B0';
    if (widget.device.type == 'lock') return '${_currentValue.toInt()}% Locked';
    if (widget.device.type == 'gate' || widget.device.type == 'cover') {
      return '${_currentValue.toInt()}% Open';
    }
    return widget.device.statusLabel;
  }

  Color _getAccentColor() {
    switch (widget.device.type) {
      case 'light': return Colors.orange;
      case 'thermostat': return AppColors.orange;
      case 'lock': return _isOn ? AppColors.primary : Colors.redAccent;
      case 'gate':
      case 'cover': return Colors.greenAccent;
      default: return AppColors.primary;
    }
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionCircle(
          icon: _getToggleIcon(),
          isActive: _isOn,
          onTap: () {
            setState(() {
              _isOn = !_isOn;
              _currentValue = _isOn ? 100.0 : 0.0;
            });
            widget.controller.toggleDevice(widget.device);
            widget.controller.updateDeviceValue(widget.device, 'position', _currentValue.toInt());
          },
          isDark: widget.isDark,
        ),
        if (widget.device.type == 'light') ...[
          const SizedBox(width: 16),
          _ActionCircle(
            icon: Icons.palette_rounded,
            isActive: _showColorPicker,
            onTap: () => setState(() => _showColorPicker = !_showColorPicker),
            isDark: widget.isDark,
            activeColor: Colors.amber,
          ),
          const SizedBox(width: 16),
          _ActionCircle(
            icon: Icons.wb_sunny_rounded,
            isActive: !_showColorPicker,
            onTap: () {
              setState(() => _showColorPicker = false);
              widget.controller.updateDeviceValue(widget.device, 'color', 'Daylight');
            },
            isDark: widget.isDark,
            activeColor: Colors.orange,
          ),
        ],
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderAction({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool isLarge;

  const _MediaButton({required this.icon, required this.isDark, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 12),
      decoration: BoxDecoration(
        color: isLarge ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: isLarge ? Colors.white : (isDark ? Colors.white70 : Colors.black87), size: isLarge ? 32 : 24),
    );
  }
}

class _WideSlider extends StatelessWidget {
  final double value;
  final Color color;
  final ValueChanged<double>? onChanged;

  const _WideSlider({required this.value, required this.color, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final Color? activeColor;

  const _ActionCircle({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive 
        ? (activeColor ?? AppColors.primary).withOpacity(0.2) 
        : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2);
    final color = isActive ? (activeColor ?? AppColors.primary) : (isDark ? Colors.white38 : Colors.black38);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _GradientColorPicker extends StatelessWidget {
  final Function(Color) onColorChanged;
  final bool isDark;

  const _GradientColorPicker({required this.onColorChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Colors.red, Colors.orange, Colors.yellow, 
            Colors.green, Colors.cyan, Colors.blue, 
            Colors.purple, Colors.pink, Colors.red
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTapDown: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final x = details.localPosition.dx;
            final width = box.size.width;
            final percent = (x / width).clamp(0.0, 1.0);
            final hue = percent * 360;
            onColorChanged(HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor());
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SemicircleSlider extends StatefulWidget {
  final double value;
  final Color color;
  final bool isDark;
  final Function(double) onChanged;

  const _SemicircleSlider({
    required this.value,
    required this.color,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_SemicircleSlider> createState() => _SemicircleSliderState();
}

class _SemicircleSliderState extends State<_SemicircleSlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_SemicircleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  void _handlePan(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    double angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    
    // Normalize to our arc range
    double startAngle = math.pi * 0.75;
    double sweepAngle = math.pi * 1.5;
    
    double normalizedAngle = angle - startAngle;
    if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;
    
    double newValue = (normalizedAngle / sweepAngle).clamp(0.0, 1.0);
    
    setState(() => _localValue = newValue);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (details) => _handlePan(details.localPosition, size),
          onPanStart: (details) => _handlePan(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SemicircleSliderPainter(
              value: _localValue,
              color: widget.color,
              trackColor: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              isDark: widget.isDark,
            ),
          ),
        );
      }
    );
  }
}

class _SemicircleSliderPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final bool isDark;

  _SemicircleSliderPainter({
    required this.value, 
    required this.color, 
    required this.trackColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 20; // Leave room for stroke and shadow
    final strokeWidth = 28.0;

    final startAngle = math.pi * 0.75;
    final sweepAngle = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background track
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // Draw active track
    canvas.drawArc(rect, startAngle, sweepAngle * value, false, valuePaint);

    // Draw rounded structure (knob) at the end of the active track
    final knobAngle = startAngle + (sweepAngle * value);
    final knobCenter = Offset(
      center.dx + radius * math.cos(knobAngle),
      center.dy + radius * math.sin(knobAngle),
    );

    // Knob Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(knobCenter, 14, shadowPaint);

    // Knob White Outer
    final knobOuterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 13, knobOuterPaint);

    // Small indicator in the middle of the knob
    final knobInnerPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 4, knobInnerPaint);
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _DialButton({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);
    final color = isDark ? Colors.white : Colors.black;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.06), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _CompactControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _CompactControlButton({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 16),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
class _SelectionChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Function(TapDownDetails) onTapDown;

  const _SelectionChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final textPri = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textSec),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: textSec, fontSize: 10, fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(color: textPri, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
