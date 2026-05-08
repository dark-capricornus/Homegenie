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
    final p = s['power'] ?? data['power'];
    final st = s['state'] ?? data['state'];
    
    return p?.toString().toLowerCase() == 'on' ||
        st?.toString().toLowerCase() == 'on' ||
        p == true ||
        st == true ||
        s['enabled'] == true ||
        s['playing'] == true ||
        data['enabled'] == true;
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
    final b = state['brightness'] ?? data['brightness'];
    if (b == null) return null;
    return (b as num).toInt();
  }

  int? get position {
    final p = state['position'] ?? data['position'];
    if (p == null) return null;
    return (p as num).toInt();
  }

  double get powerConsumption {
    // 1. Try nested state first (standard for HomeGenie)
    final s = state;
    final pState = s['power_consumption'] ?? s['power_usage'] ?? s['energy'];
    if (pState != null) {
      final v = pState is num
          ? pState.toDouble()
          : (pState is String ? double.tryParse(pState) ?? 0.0 : 0.0);
      if (v > 0) return v;
    }

    // 2. Try top-level data (sometimes produced by normalization)
    final pData = data['power_consumption'] ?? data['power_usage'] ?? data['energy'];
    if (pData != null) {
      final v = pData is num
          ? pData.toDouble()
          : (pData is String ? double.tryParse(pData) ?? 0.0 : 0.0);
      if (v > 0) return v;
    }

    // 3. Estimate based on device type when device is on but no power data
    if (isOn) {
      switch (type) {
        case 'light':
          final b = brightness ?? 50;
          return b * 0.15; // ~15W at full brightness
        case 'switch':
          return 10.0;
        case 'thermostat':
          return 25.0;
        default:
          return 5.0;
      }
    }

    return 0.0;
  }
}
