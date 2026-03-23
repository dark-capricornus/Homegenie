class DeviceInfo {
  final String key;
  final Map<String, dynamic> data;
  final String name;
  final String type;
  final String? protocol;
  final String? ipAddress;
  final int? signalStrength;
  final int? batteryLevel;

  DeviceInfo({
    required this.key,
    required this.data,
    required this.name,
    required this.type,
    this.protocol,
    this.ipAddress,
    this.signalStrength,
    this.batteryLevel,
  });

  Map<String, dynamic> get state {
    final raw = data['state'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw != null) {
      return {
        'state': raw,
        'value': raw,
        'power': raw,
      };
    }
    return {};
  }

  bool get isOnline {
    // Check top-level 'online' field first (most devices use this)
    if (data['online'] == true) return true;
    if (data['online'] == false) return false;

    final s = state;
    final status = s['status']?.toString().toLowerCase() ??
        s['connectivity']?.toString().toLowerCase() ??
        '';
    if (status == 'offline' ||
        status == 'disconnected' ||
        status == 'timed_out') {
      return false;
    }
    return true;
  }

  bool get isOn {
    final s = state;
    return s['power']?.toString().toLowerCase() == 'on' ||
        s['state']?.toString().toLowerCase() == 'on' ||
        s['enabled'] == true ||
        s['playing'] == true;
  }

  bool get isLocked => data['locked'] == true || state['locked'] == true;

  /// Whether the device is "active" — accounts for device type:
  /// locks → isLocked, everything else → isOn.
  bool get isActive => type == 'lock' ? isLocked : isOn;

  /// Human-friendly status label based on device type.
  String get statusLabel {
    if (type == 'lock') return isLocked ? 'Locked' : 'Unlocked';
    return isOn ? 'Active' : 'Off';
  }

  double? get temperature {
    final t = state['temperature'];
    if (t == null) return null;
    return (t as num).toDouble();
  }

  double? get targetTemperature {
    final t = state['target_temperature'];
    if (t == null) return null;
    return (t as num).toDouble();
  }

  int? get brightness {
    final b = state['brightness'];
    if (b == null) return null;
    return (b as num).toInt();
  }
}
