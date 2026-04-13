import 'dart:convert';
import 'package:http/http.dart' as http;
class DeviceService {

  String getDeviceType(String key) {
    if (key.contains('light') && !key.contains('sensor')) return 'light';
    if (key.contains('thermostat')) return 'thermostat';
    if (key.contains('lock')) return 'lock';
    if (key.contains('media')) return 'media';
    if (key.contains('fan') || key.contains('outlet') || key.contains('switch')) {
      return 'switch';
    }
    if (key.contains('temperature') ||
        key.contains('motion') ||
        key.contains('sensor') ||
        key.contains('humidity') ||
        key.contains('door') ||
        key.contains('window') ||
        key.contains('air_quality')) {
      return 'sensor';
    }
    return 'unknown';
  }

  String formatDeviceName(String key) {
    try {
      return key
          .split('.')
          .reversed
          .map((p) => p
              .split('_')
              .where((w) => w.isNotEmpty)
              .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' '))
          .join(' ');
    } catch (e) {
      return key;
    }
  }

  Map<String, dynamic> normalizeDeviceData(dynamic value) {
    if (value is Map<String, dynamic>) {
      final rawState = value['state'];
      if (rawState is Map<String, dynamic>) return value;
      if (rawState is Map) {
        return {...value, 'state': Map<String, dynamic>.from(rawState)};
      }
      if (rawState != null) {
        return {
          ...value,
          'state': {'state': rawState, 'value': rawState, 'power': rawState}
        };
      }
      return {...value, 'state': <String, dynamic>{}};
    }
    if (value is Map) return normalizeDeviceData(Map<String, dynamic>.from(value));
    if (value is String || value is bool || value is num) {
      return {
        'state': {'state': value, 'value': value, 'power': value}
      };
    }
    return {'state': <String, dynamic>{}};
  }

  Future<http.Response> fetchDevices(String baseUrl, String? etag, {String token = ''}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (etag != null) 'If-None-Match': etag,
      if (token.isNotEmpty) 'X-HomeGenie-Token': token,
    };
    return await http
        .get(Uri.parse('$baseUrl/devices'), headers: headers)
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> toggleDevice(String baseUrl, String deviceKey, String action, {String token = ''}) async {
    return await http
        .post(
          Uri.parse('$baseUrl/devices/control'),
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'X-HomeGenie-Token': token,
          },
          body: json.encode({
            'device_id': deviceKey,
            'action': action,
          }),
        )
        .timeout(const Duration(seconds: 5));
  }

  Future<http.Response> fetchEnergyHistory(String baseUrl, {String? deviceId, int days = 1, String token = ''}) async {
    final uri = Uri.parse('$baseUrl/history/energy').replace(
      queryParameters: {
        if (deviceId != null) 'device_id': deviceId,
        'days': days.toString(),
      },
    );
    return await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-HomeGenie-Token': token,
    }).timeout(const Duration(seconds: 5));
  }

  Future<http.Response> fetchDeviceBreakdown(String baseUrl, {int days = 1, String token = ''}) async {
    final uri = Uri.parse('$baseUrl/history/devices').replace(
      queryParameters: {'days': days.toString()},
    );
    return await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-HomeGenie-Token': token,
    }).timeout(const Duration(seconds: 5));
  }
}
