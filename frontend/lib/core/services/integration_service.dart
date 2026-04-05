import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:homegenie_app/core/models/integration.dart';

class IntegrationService {
  Future<List<PlatformIntegration>> fetchIntegrations(String baseUrl) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/integrations'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final list = data['integrations'] as List<dynamic>? ?? [];
        return list
            .map((e) => PlatformIntegration.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    // Fall back to defaults if backend not available yet
    return PlatformIntegration.defaults();
  }

  Future<bool> setupPlatform(
    String baseUrl,
    String platformId,
    Map<String, dynamic> config,
  ) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/integrations/$platformId/setup'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'config': config}),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlatformDevices(
    String baseUrl,
    String platformId,
  ) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/integrations/$platformId/devices'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return List<Map<String, dynamic>>.from(data['devices'] ?? []);
      }
    } catch (_) {}
    return [];
  }
}
