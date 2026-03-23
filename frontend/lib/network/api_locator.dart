import 'dart:async';
import 'package:homegenie_app/network/backend_discovery_service.dart';

/// ApiLocator - finds a reachable backend URL using a prioritized strategy.
/// Now delegates to BackendDiscoveryService for modern refactored logic.
class ApiLocator {
  static final _discoveryService = BackendDiscoveryService();

  /// Return a usable base URL.
  static Future<String> getBaseUrl(
      {Duration perIpTimeout = const Duration(seconds: 3)}) async {
    final found = await _discoveryService.discover();
    if (found != null) return found;

    // Fallback if discovery fails (backward compatibility)
    return 'http://localhost:8081';
  }

  /// Test a URL by calling GET /state and expecting valid JSON.
  static Future<bool> testUrl(String url,
      {Duration timeout = const Duration(seconds: 3)}) async {
    return _discoveryService.testConnection(url);
  }

  /// Persist manual override (or clear by passing null)
  static Future<void> setManualOverride(String? url) async {
    await _discoveryService.setManualOverride(url);
  }

  static Future<String?> getManualOverride() async {
    return _discoveryService.getManualOverride();
  }
}
