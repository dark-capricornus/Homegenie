import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:homegenie_app/network/backend_discovery_service.dart';

/// ApiLocator - finds a reachable backend URL using a prioritized strategy.
/// Now delegates to BackendDiscoveryService for modern refactored logic.
class ApiLocator {
  static final _log = Logger('ApiLocator');
  static final _discoveryService = BackendDiscoveryService();

  /// Return a usable base URL.
  static Future<String> getBaseUrl() async {
    final found = await _discoveryService.discover();
    if (found != null) return found;

    // Fallback if discovery fails: Try to use the last successful host on port 8081
    final prefs = await SharedPreferences.getInstance();
    final lastHost = prefs.getString('last_successful_host');
    if (lastHost != null && lastHost.isNotEmpty) {
      _log.warning('Discovery failed. Using smarter fallback to last known host: $lastHost');
      return 'http://$lastHost:8081';
    }

    // Ultima fallback if everything fails
    _log.shout('CRITICAL: No backend found. Defaulting to localhost (likely to fail on device).');
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
