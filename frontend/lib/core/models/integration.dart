import 'package:flutter/material.dart';

class PlatformIntegration {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isConfigured;
  final int deviceCount;
  final Map<String, dynamic> config;

  const PlatformIntegration({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isConfigured = false,
    this.deviceCount = 0,
    this.config = const {},
  });

  factory PlatformIntegration.fromJson(Map<String, dynamic> json) {
    final meta = _platformMeta[json['platform'] ?? json['id']] ?? _platformMeta['custom_mqtt']!;
    return PlatformIntegration(
      id: json['platform'] ?? json['id'] ?? '',
      name: json['name'] ?? meta['name'] as String,
      description: meta['description'] as String,
      icon: meta['icon'] as IconData,
      color: meta['color'] as Color,
      isConfigured: json['is_configured'] ?? false,
      deviceCount: json['device_count'] ?? 0,
      config: Map<String, dynamic>.from(json['config'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'is_configured': isConfigured,
    'device_count': deviceCount,
    'config': config,
  };

  PlatformIntegration copyWith({
    bool? isConfigured,
    int? deviceCount,
    Map<String, dynamic>? config,
  }) {
    return PlatformIntegration(
      id: id,
      name: name,
      description: description,
      icon: icon,
      color: color,
      isConfigured: isConfigured ?? this.isConfigured,
      deviceCount: deviceCount ?? this.deviceCount,
      config: config ?? this.config,
    );
  }

  static const Map<String, Map<String, dynamic>> _platformMeta = {
    'google_home': {
      'name': 'Google Home',
      'description': 'Control Nest & Google Home devices via Device Access API',
      'icon': Icons.home_rounded,
      'color': Color(0xFF4285F4),
    },
    'alexa': {
      'name': 'Amazon Alexa',
      'description': 'Integrate Echo & Alexa-compatible smart devices',
      'icon': Icons.record_voice_over_rounded,
      'color': Color(0xFF00CAFF),
    },
    'zigbee': {
      'name': 'Zigbee',
      'description': 'Low-power mesh network for sensors & switches',
      'icon': Icons.settings_input_antenna_rounded,
      'color': Color(0xFF10B981),
    },
    'matter': {
      'name': 'Matter',
      'description': 'Universal smart home standard across all ecosystems',
      'icon': Icons.hub_rounded,
      'color': const Color(0xFF137FEC),
    },
    'custom_mqtt': {
      'name': 'Custom MQTT',
      'description': 'Connect any MQTT-compatible device or broker',
      'icon': Icons.developer_board_rounded,
      'color': Color(0xFFFF9800),
    },
  };

  static List<PlatformIntegration> defaults() {
    return _platformMeta.entries.map((e) => PlatformIntegration(
      id: e.key,
      name: e.value['name'] as String,
      description: e.value['description'] as String,
      icon: e.value['icon'] as IconData,
      color: e.value['color'] as Color,
    )).toList();
  }
}
