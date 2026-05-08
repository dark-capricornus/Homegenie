import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/core/responsive/breakpoints.dart';
import 'package:homegenie_app/features/live/widgets/live_mode_placeholder.dart';
import 'package:homegenie_app/features/dashboard/widgets/dashboard_widgets.dart';
import 'package:homegenie_app/core/widgets/page_header.dart';
import 'package:provider/provider.dart';

class IoTDevicesPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;
  final int currentIndex;
  const IoTDevicesPage({
    super.key,
    required this.isDark,
    required this.currentIndex,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();

    if (!ctrl.isDemoMode && ctrl.devices.isEmpty && !ctrl.isLoading) {
      return LiveModePlaceholder(
        title: 'Connect Your Devices',
        description:
            'Configure a platform integration in the Live Hub to see your real IoT devices here.',
        icon: Icons.router_rounded,
        isDark: isDark,
      );
    }

    return ctrl.isLoading && ctrl.devices.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _HomeView(
            ctrl: ctrl,
            isDark: isDark,
            currentIndex: currentIndex,
            onToggleTheme: onToggleTheme,
            onNavTap: onNavTap,
          );
  }
}

class _HomeView extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;

  final int currentIndex;

  const _HomeView({
    required this.ctrl,
    required this.isDark,
    required this.currentIndex,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final padding = size.isMobile ? 16.0 : 32.0;
    final rooms = ctrl.devicesByRoom;
    final keys = rooms.keys.toList()..sort();

    final columnCount = size.isMobile ? 1 : (size.isTablet ? 2 : 3);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Column(
        children: [
          PageHeader(
            title: 'IoT Devices',
            subtitle: 'Rooms & Devices',
            isDark: isDark,
            currentIndex: currentIndex,
            onToggleTheme: onToggleTheme,
            onNavTap: onNavTap,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
            child: _TopStatusBar(ctrl: ctrl, isDark: isDark),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: padding),
              physics: const BouncingScrollPhysics(),
              child: _MasonryRooms(
                keys: keys,
                rooms: rooms,
                columnCount: columnCount,
                isDark: isDark,
                ctrl: ctrl,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// =============================================================================
// TOP STATUS BAR — avg temp, avg humidity, presence
// =============================================================================
class _TopStatusBar extends StatelessWidget {
  final DashboardController ctrl;
  final bool isDark;

  const _TopStatusBar({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final temp = _avg(ctrl.devices, _readTemperature);
    final hum = _avg(ctrl.devices, _readHumidity);
    final present = _detectPresence(ctrl.devices);

    final chips = <Widget>[
      if (temp != null)
        TopStatusChip(
          icon: Icons.thermostat_rounded,
          label: temp.toStringAsFixed(1),
          isDark: isDark,
          color: AppColors.orange,
        ),
      if (hum != null)
        TopStatusChip(
          icon: Icons.water_drop_rounded,
          label: hum.toStringAsFixed(1),
          isDark: isDark,
          color: AppColors.primary,
        ),
      TopStatusChip(
        icon: present
            ? Icons.directions_walk_rounded
            : Icons.directions_car_rounded,
        label: present ? 'Home' : 'Away',
        isDark: isDark,
        color: present ? AppColors.success : Colors.grey,
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: chips,
    );
  }
}

// =============================================================================
// MASONRY GRID — N variable-height columns
// =============================================================================
// =============================================================================
// MASONRY LAYOUT — Space-efficient vertical columns
// =============================================================================
class _MasonryRooms extends StatelessWidget {
  final List<String> keys;
  final Map<String, List<DeviceInfo>> rooms;
  final int columnCount;
  final bool isDark;
  final DashboardController ctrl;

  const _MasonryRooms({
    required this.keys,
    required this.rooms,
    required this.columnCount,
    required this.isDark,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const SizedBox.shrink();

    final size = Breakpoints.of(context);

    // 1. Sort all keys first (fallback logic)
    final sortedKeys = List<String>.from(keys)..sort((a, b) {
      final countA = rooms[a]!.length;
      final countB = rooms[b]!.length;
      if (countA > 1 && countB <= 1) return -1;
      if (countB > 1 && countA <= 1) return 1;
      if (countA != countB) return countB.compareTo(countA);
      return a.compareTo(b);
    });

    // 2. Custom Row Grouping Logic
    final rows = <List<dynamic>>[];
    
    if (size.isMobile) {
      // Simple 1-column layout for mobile
      for (var i = 0; i < sortedKeys.length; i++) {
        rows.add([sortedKeys[i]]);
      }
    } else if (size.isTablet) {
      // TABLET: 2-column specialized layout
      final remainingKeys = List<String>.from(sortedKeys);
      const cols = 2;
      
      // Row 1: [Front Entry, [Back Entry + Backyard]]
      final row1 = <dynamic>[];
      if (remainingKeys.contains('front_entry')) {
        row1.add('front_entry');
        remainingKeys.remove('front_entry');
      }
      final split1 = <String>[];
      if (remainingKeys.contains('back_entry')) split1.add('back_entry');
      if (remainingKeys.contains('backyard')) split1.add('backyard');
      if (split1.isNotEmpty) {
        remainingKeys.remove('back_entry');
        remainingKeys.remove('backyard');
        row1.add(split1);
      }
      if (row1.isNotEmpty) rows.add(row1);
      
      // Row 2: [[Hallway + Bathroom], Living Room]
      final row2 = <dynamic>[];
      final split2 = <String>[];
      if (remainingKeys.contains('hallway')) split2.add('hallway');
      if (remainingKeys.contains('bathroom')) split2.add('bathroom');
      if (split2.isNotEmpty) {
        remainingKeys.remove('hallway');
        remainingKeys.remove('bathroom');
        row2.add(split2);
      }
      if (remainingKeys.contains('living_room')) {
        row2.add('living_room');
        remainingKeys.remove('living_room');
      }
      if (row2.isNotEmpty) rows.add(row2);
      
      // Row 3: [Bedroom, Kitchen]
      final row3 = <dynamic>[];
      if (remainingKeys.contains('bedroom')) {
        row3.add('bedroom');
        remainingKeys.remove('bedroom');
      }
      if (remainingKeys.contains('kitchen')) {
        row3.add('kitchen');
        remainingKeys.remove('kitchen');
      }
      if (row3.isNotEmpty) rows.add(row3);
      
      // Row 4: [Main Thermostat, [Garage + Front Porch]]
      final row4 = <dynamic>[];
      final thermoKey = remainingKeys.firstWhere(
        (k) => k.toLowerCase().contains('thermostat') || k.toLowerCase().contains('climate'), 
        orElse: () => ''
      );
      if (thermoKey.isNotEmpty) {
        row4.add(thermoKey);
        remainingKeys.remove(thermoKey);
      }
      final split3 = <String>[];
      if (remainingKeys.contains('garage')) split3.add('garage');
      if (remainingKeys.contains('front_porch')) split3.add('front_porch');
      if (split3.isNotEmpty) {
        remainingKeys.remove('garage');
        remainingKeys.remove('front_porch');
        row4.add(split3);
      }
      if (row4.isNotEmpty) rows.add(row4);

      // Remaining
      for (var i = 0; i < remainingKeys.length; i += cols) {
        rows.add(remainingKeys.sublist(i, (i + cols) < remainingKeys.length ? (i + cols) : remainingKeys.length));
      }
    } else {
      // DESKTOP: 3-column specialized layout (Current)
      final remainingKeys = List<String>.from(sortedKeys);
      
      // Row 1: [Front Entry, [Back Entry + Backyard], [Hallway + Bathroom]]
      final row1 = <dynamic>[];
      if (remainingKeys.contains('front_entry')) {
        row1.add('front_entry');
        remainingKeys.remove('front_entry');
      }
      
      final splitCol1 = <String>[];
      if (remainingKeys.contains('back_entry')) {
        splitCol1.add('back_entry');
        remainingKeys.remove('back_entry');
      }
      if (remainingKeys.contains('backyard')) {
        splitCol1.add('backyard');
        remainingKeys.remove('backyard');
      }
      if (splitCol1.isNotEmpty) {
        row1.add(splitCol1.length == 1 ? splitCol1[0] : splitCol1);
      }
      
      final splitCol2 = <String>[];
      if (remainingKeys.contains('hallway')) {
        splitCol2.add('hallway');
        remainingKeys.remove('hallway');
      }
      if (remainingKeys.contains('bathroom')) {
        splitCol2.add('bathroom');
        remainingKeys.remove('bathroom');
      }
      if (splitCol2.isNotEmpty) {
        row1.add(splitCol2.length == 1 ? splitCol2[0] : splitCol2);
      }
      if (row1.isNotEmpty) rows.add(row1);
      
      // Row 2: [Living Room, Bedroom, Kitchen]
      final row2 = <String>[];
      if (remainingKeys.contains('living_room')) {
        row2.add('living_room');
        remainingKeys.remove('living_room');
      }
      if (remainingKeys.contains('bedroom')) {
        row2.add('bedroom');
        remainingKeys.remove('bedroom');
      }
      if (remainingKeys.contains('kitchen')) {
        row2.add('kitchen');
        remainingKeys.remove('kitchen');
      }
      if (row2.isNotEmpty) rows.add(row2);
      
      // Row 3: [Main Thermostat, [Garage + Front Porch], ...remaining...]
      final row3 = <dynamic>[];
      final thermoKey = remainingKeys.firstWhere(
        (k) => k.toLowerCase().contains('thermostat') || k.toLowerCase().contains('climate'), 
        orElse: () => ''
      );
      if (thermoKey.isNotEmpty) {
        row3.add(thermoKey);
        remainingKeys.remove(thermoKey);
      }
      
      final splitCol3 = <String>[];
      if (remainingKeys.contains('garage')) {
        splitCol3.add('garage');
        remainingKeys.remove('garage');
      }
      if (remainingKeys.contains('front_porch')) {
        splitCol3.add('front_porch');
        remainingKeys.remove('front_porch');
      }
      if (splitCol3.isNotEmpty) {
        row3.add(splitCol3.length == 1 ? splitCol3[0] : splitCol3);
      }
      
      while (row3.length < columnCount && remainingKeys.isNotEmpty) {
        row3.add(remainingKeys.removeAt(0));
      }
      if (row3.isNotEmpty) rows.add(row3);
      
      // Group remaining into standard rows (using current columnCount)
      for (var i = 0; i < remainingKeys.length; i += columnCount) {
        rows.add(remainingKeys.sublist(i, (i + columnCount) < remainingKeys.length ? (i + columnCount) : remainingKeys.length));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        ...rows.map((rowItems) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columnCount; i++) ...[
                Expanded(
                  child: i < rowItems.length
                      ? (rowItems[i] is String
                          ? _buildRoomSection(rowItems[i] as String)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var j = 0; j < (rowItems[i] as List<String>).length; j++) ...[
                                  Expanded(
                                    child: _buildRoomSection(rowItems[i][j]),
                                  ),
                                  if (j < (rowItems[i] as List<String>).length - 1)
                                    const SizedBox(width: 12),
                                ],
                              ],
                            ))
                      : const SizedBox.shrink(),
                ),
                if (i < columnCount - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      }).toList(),
      ],
    );
  }

  Widget _buildRoomSection(String roomKey) {
    return RoomSection(
      key: ValueKey('room_$roomKey'),
      title: _formatRoomName(roomKey),
      icon: _getRoomIcon(roomKey),
      isDark: isDark,
      subtitle: _buildRoomSubtitle(rooms[roomKey]!),
      children: rooms[roomKey]!.map((d) {
        if (d.type == 'thermostat') {
          return ThermalDeviceCard(
            key: ValueKey('device_${d.key}'),
            device: d,
            isDark: isDark,
            controller: ctrl,
          );
        }
        return UnifiedDeviceCard(
          key: ValueKey('device_${d.key}'),
          device: d,
          roomName: roomKey,
          isDark: isDark,
          controller: ctrl,
        );
      }).toList(),
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================
String _formatRoomName(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

IconData _getRoomIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('living')) return Icons.weekend_rounded;
  if (n.contains('kitchen')) return Icons.kitchen_rounded;
  if (n.contains('bedroom') || n.contains('bed')) return Icons.bed_rounded;
  if (n.contains('garage')) return Icons.garage_rounded;
  if (n.contains('bathroom') || n.contains('bath')) return Icons.bathtub_rounded;
  if (n.contains('office')) return Icons.computer_rounded;
  if (n.contains('garden') || n.contains('outdoor')) return Icons.yard_rounded;
  if (n.contains('hall')) return Icons.meeting_room_rounded;
  if (n.contains('study')) return Icons.menu_book_rounded;
  if (n.contains('climate')) return Icons.thermostat_rounded;
  return Icons.room_rounded;
}

double? _readTemperature(DeviceInfo d) {
  if (d.temperature != null) return d.temperature;
  final s = d.state;
  final raw = s['temperature'] ?? s['temp'];
  if (raw is num) return raw.toDouble();
  if (d.type == 'sensor' && d.key.contains('temperature')) {
    final v = s['state'] ?? s['value'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
  }
  return null;
}

double? _readHumidity(DeviceInfo d) {
  final s = d.state;
  final raw = s['humidity'] ?? d.data['humidity'];
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  if (d.type == 'sensor' && d.key.contains('humidity')) {
    final v = s['state'] ?? s['value'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
  }
  return null;
}

double? _avg(List<DeviceInfo> devices, double? Function(DeviceInfo) read) {
  double sum = 0;
  int count = 0;
  for (final d in devices) {
    final v = read(d);
    if (v != null) {
      sum += v;
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

bool _detectPresence(List<DeviceInfo> devices) {
  for (final d in devices) {
    final s = d.state;
    if (s['occupancy'] == true || s['motion'] == true) return true;
    final st = s['state']?.toString().toLowerCase();
    if (d.key.contains('presence') || d.key.contains('motion')) {
      if (st == 'home' || st == 'on' || st == 'detected') return true;
    }
  }
  return false;
}

String? _buildRoomSubtitle(List<DeviceInfo> devices) {
  final t = _avg(devices, _readTemperature);
  final h = _avg(devices, _readHumidity);
  if (t == null && h == null) return null;
  final parts = <String>[];
  if (t != null) parts.add('${t.toStringAsFixed(1)}°');
  if (h != null) parts.add('${h.toStringAsFixed(0)}%');
  return parts.join(' · ');
}
