import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/shared/widgets/shared_widgets.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:provider/provider.dart';

class IoTDevicesPage extends StatelessWidget {
  final bool isDark;
  const IoTDevicesPage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Container(
      color: bg,
      child: ctrl.isLoading && ctrl.devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _RoomsOverview(ctrl: ctrl, isDark: isDark),
    );
  }
}

// =============================================================================
// ROOMS OVERVIEW — grid of room cards
// =============================================================================
class _RoomsOverview extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _RoomsOverview({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final rooms = ctrl.devicesByRoom;

    final roomColors = [
      AppColors.primary,
      AppColors.teal,
      AppColors.orange,
      AppColors.purple,
      AppColors.green,
      AppColors.error,
      Colors.cyan,
      Colors.amber,
    ];

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 20, 24, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Our Home',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    )),
                const SizedBox(height: 6),
                Text(
                  '${rooms.length} room${rooms.length != 1 ? 's' : ''} \u2022 ${ctrl.devices.length} device${ctrl.devices.length != 1 ? 's' : ''}',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // Frequently used
        if (ctrl.frequentlyAccessedDevices.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: SectionLabel(
                label: 'FREQUENTLY USED',
                isDark: isDark,
                icon: Icons.star_rounded,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                itemCount: ctrl.frequentlyAccessedDevices.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _FrequentDeviceCard(
                    device: ctrl.frequentlyAccessedDevices[i],
                    isDark: isDark,
                    controller: ctrl,
                  ),
                ),
              ),
            ),
          ),
        ],

        // Section title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: SectionLabel(
              label: 'ROOMS',
              isDark: isDark,
              icon: Icons.meeting_room_rounded,
            ),
          ),
        ),

        // Room cards grid
        if (rooms.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off_outlined,
                      size: 64,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                  const SizedBox(height: 16),
                  Text('No devices found',
                      style: TextStyle(color: textSecondary, fontSize: 15)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.isMobile ? 2 : (size.isWeb ? 3 : 4),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final entry = rooms.entries.elementAt(i);
                  final color = roomColors[i % roomColors.length];
                  return _RoomCard(
                    roomKey: entry.key,
                    devices: entry.value,
                    accentColor: color,
                    isDark: isDark,
                    controller: ctrl,
                  );
                },
                childCount: rooms.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// =============================================================================
// ROOM CARD
// =============================================================================
class _RoomCard extends StatelessWidget {
  final String roomKey;
  final List<DeviceInfo> devices;
  final Color accentColor;
  final bool isDark;
  final DashboardController controller;

  const _RoomCard({
    required this.roomKey,
    required this.devices,
    required this.accentColor,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final activeCount = devices.where((d) {
      final toggle = controller.deviceToggles[d.key];
      return toggle ?? d.isActive;
    }).length;
    final label = _formatRoomName(roomKey);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, __, ___) => _RoomDetailPage(
              roomKey: roomKey,
              roomName: label,
              accentColor: accentColor,
              isDark: isDark,
            ),
            transitionsBuilder: (_, anim, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_getRoomIcon(roomKey), color: accentColor, size: 22),
            ),
            const Spacer(),
            // Room name
            Text(label,
                style: TextStyle(
                  color: textPri,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // Device count
            Text(
              '${devices.length} device${devices.length != 1 ? 's' : ''}',
              style: TextStyle(color: textSec, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Active indicator bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: devices.isNotEmpty ? activeCount / devices.length : 0,
                      minHeight: 4,
                      backgroundColor: border,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$activeCount active',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRoomName(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static IconData _getRoomIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('living')) return Icons.weekend_rounded;
    if (n.contains('kitchen')) return Icons.kitchen_rounded;
    if (n.contains('bedroom') || n.contains('bed')) return Icons.bed_rounded;
    if (n.contains('garage')) return Icons.garage_rounded;
    if (n.contains('bathroom') || n.contains('bath')) {
      return Icons.bathtub_rounded;
    }
    if (n.contains('office')) return Icons.computer_rounded;
    if (n.contains('garden') || n.contains('outdoor')) return Icons.yard_rounded;
    if (n.contains('hall')) return Icons.meeting_room_rounded;
    return Icons.room_rounded;
  }
}

// =============================================================================
// ROOM DETAIL PAGE — shows devices in the selected room
// =============================================================================
class _RoomDetailPage extends StatelessWidget {
  final String roomKey;
  final String roomName;
  final Color accentColor;
  final bool isDark;

  const _RoomDetailPage({
    required this.roomKey,
    required this.roomName,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final devices = ctrl.devicesByRoom[roomKey] ?? [];
    final activeCount = devices.where((d) {
      final toggle = ctrl.deviceToggles[d.key];
      return toggle ?? d.isOn;
    }).length;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_rounded, color: textPri),
            ),
            title: Text(roomName,
                style: TextStyle(
                  color: textPri,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                )),
            centerTitle: false,
          ),

          // Room summary card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_RoomCard._getRoomIcon(roomKey),
                          color: accentColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(roomName,
                              style: TextStyle(
                                color: textPri,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            '$activeCount of ${devices.length} device${devices.length != 1 ? 's' : ''} active',
                            style: TextStyle(color: textSec, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Power info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.bolt_rounded, color: accentColor, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${_roomPower(devices, ctrl).toStringAsFixed(1)}W',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  Icon(Icons.devices_rounded,
                      color: accentColor, size: 14),
                  const SizedBox(width: 6),
                  Text('DEVICES',
                      style: TextStyle(
                        color: textSec,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      )),
                ],
              ),
            ),
          ),

          // Device list
          if (devices.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No devices in this room',
                      style: TextStyle(color: textSec, fontSize: 13)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _DeviceListTile(
                    device: devices[i],
                    isDark: isDark,
                    controller: ctrl,
                    accentColor: accentColor,
                  ),
                  childCount: devices.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  double _roomPower(List<DeviceInfo> devices, DashboardController ctrl) {
    double total = 0;
    for (final d in devices) {
      final isOn = ctrl.deviceToggles[d.key] ?? d.isOn;
      if (isOn) {
        total += (d.data['power_consumption'] ?? 0.0).toDouble();
      }
    }
    return total;
  }
}

// =============================================================================
// DEVICE LIST TILE (within room detail)
// =============================================================================
class _DeviceListTile extends StatelessWidget {
  final DeviceInfo device;
  final bool isDark;
  final DashboardController controller;
  final Color accentColor;

  const _DeviceListTile({
    required this.device,
    required this.isDark,
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = controller.deviceToggles[device.key] ?? device.isActive;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn
              ? accentColor.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isOn
                ? accentColor.withValues(alpha: 0.12)
                : AppColors.primaryDim,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconForType(device.type),
            color: isOn ? accentColor : AppColors.darkTextTertiary,
            size: 22,
          ),
        ),
        title: Text(device.name,
            style: TextStyle(
                color: textPri,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        subtitle: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? AppColors.success : AppColors.darkTextTertiary,
              ),
            ),
            Text(
              isOn ? (device.type == 'lock' ? 'Locked' : 'Active') : (device.type == 'lock' ? 'Unlocked' : 'Off'),
              style: TextStyle(
                color: isOn ? AppColors.success : textSec,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: controller.isToggleLoading[device.key] == true
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: isOn,
                onChanged: (_) => controller.toggleDevice(device),
                activeTrackColor: accentColor.withValues(alpha: 0.5),
                activeThumbColor: accentColor,
              ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'light':
        return Icons.lightbulb_rounded;
      case 'switch':
        return Icons.toggle_on_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'media':
        return Icons.speaker_rounded;
      case 'sensor':
        return Icons.sensors_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}

// =============================================================================
// FREQUENTLY USED CARD
// =============================================================================
class _FrequentDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isDark;
  final DashboardController controller;

  const _FrequentDeviceCard({
    required this.device,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = controller.deviceToggles[device.key] ?? device.isActive;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: () => controller.toggleDevice(device),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOn ? AppColors.primary.withValues(alpha: 0.12) : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOn ? AppColors.primary.withValues(alpha: 0.35) : border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getIconForType(device.type),
              color: isOn ? AppColors.primary : AppColors.darkTextTertiary,
              size: 26,
            ),
            const Spacer(),
            Text(
              device.name,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              isOn ? (device.type == 'lock' ? 'LOCKED' : 'ON') : (device.type == 'lock' ? 'UNLOCKED' : 'OFF'),
              style: TextStyle(
                color: isOn ? AppColors.primary : AppColors.darkTextTertiary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'light':
        return Icons.lightbulb_rounded;
      case 'switch':
        return Icons.toggle_on_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'media':
        return Icons.speaker_rounded;
      case 'sensor':
        return Icons.sensors_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}
