import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('BackendDiscoveryService');

class BackendDiscoveryService {
  static const String _kCachedKey = 'cached_server_url';
  static const String _kOverrideKey = 'server_override_url';
  /// Key for user-configured LAN IP (stored in SharedPreferences).
  static const String _kLanIpKey = 'backend_lan_ip';
  static const List<int> _kCandidatePorts = [8080, 8081, 8000];
  static const Duration _kProbeTimeout = Duration(seconds: 8);
  static const int _kMaxRetries = 3;

  final Map<String, int> _retryCounts = {};
  Completer<String?>? _discoveryCompleter;

  /// Discover the backend URL based on priority.
  Future<String?> discover() async {
    // Deduplicate concurrent discovery calls
    if (_discoveryCompleter != null) {
      _log.info('Discovery already in progress, awaiting existing completer.');
      return _discoveryCompleter!.future;
    }

    _discoveryCompleter = Completer<String?>();
    try {
      final result = await _performDiscovery();
      _discoveryCompleter!.complete(result);
      return result;
    } catch (e) {
      _discoveryCompleter!.complete(null);
      return null;
    } finally {
      _discoveryCompleter = null;
    }
  }

  Future<String?> _performDiscovery() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Manual Override
    final override = prefs.getString(_kOverrideKey);
    if (override != null) {
      if (await _testConnectionWithRetry(override)) {
        _log.info('Backend detected at override: $override');
        return override;
      } else {
        _log.warning('Manual override $override failed validation after $_kMaxRetries attempts. Removing.');
        await prefs.remove(_kOverrideKey);
      }
    }

    // 2. Cached URL
    final cached = prefs.getString(_kCachedKey);
    if (cached != null) {
      if (await _testConnectionWithRetry(cached)) {
        _log.info('Backend detected at cached URL: $cached');
        return cached;
      } else {
        _log.warning('Cached URL $cached failed after $_kMaxRetries attempts.');
        await prefs.remove(_kCachedKey);
      }
    }

    // 3. Platform Specific & LAN Scan
    final lanIp = prefs.getString(_kLanIpKey);
    final candidates = _generateCandidates(lanIp: lanIp);
    _log.info(
        'Starting parallel discovery for ${candidates.length} candidates...');

    final found = await _probeParallel(candidates);
    if (found != null) {
      _log.info('Backend detected at discovered URL: $found');
      await prefs.setString(_kCachedKey, found);
      return found;
    }

    _log.severe('Discovery failed. No reachable backend found.');
    return null;
  }

  /// Test connection to a specific base URL.
  Future<bool> testConnection(String baseUrl) async {
    final cleanUrl = baseUrl.replaceAll(RegExp(r'/*$'), '');
    final probeUrl = '$cleanUrl/health';
    final isEmulator = cleanUrl.contains('10.0.2.2');
    if (isEmulator) {
      _log.shout('CRITICAL PROBE: $probeUrl (Emulator Bridge)');
    } else {
      _log.info('Probing $probeUrl');
    }
    try {
      final response = await http.get(
        Uri.parse(probeUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(_kProbeTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'ok') {
          _log.info('SUCCESS: $probeUrl responded correctly.');
          return true;
        } else {
          _log.warning('FAILURE: $probeUrl returned 200 but invalid schema.');
        }
      } else {
        _log.warning(
            'FAILURE: $probeUrl returned status ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _log.severe('Probe failed for $probeUrl: $e', e, stackTrace);
    }
    return false;
  }

  /// Internal helper to test connection with retry logic.
  Future<bool> _testConnectionWithRetry(String url) async {
    int attempts = 0;
    while (attempts < _kMaxRetries) {
      if (await testConnection(url)) {
        _retryCounts[url] = 0;
        return true;
      }
      attempts++;
      _log.warning('Retry attempt $attempts/$_kMaxRetries for $url');
      if (attempts < _kMaxRetries) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  /// Set manual override.
  Future<void> setManualOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_kOverrideKey);
    } else {
      await prefs.setString(_kOverrideKey, url);
      await prefs.setString(_kCachedKey, url);
    }
  }

  /// Get manual override.
  Future<String?> getManualOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOverrideKey);
  }

  /// Store a user-configured LAN IP for backend discovery.
  Future<void> setLanIp(String? ip) async {
    final prefs = await SharedPreferences.getInstance();
    if (ip == null || ip.isEmpty) {
      await prefs.remove(_kLanIpKey);
    } else {
      await prefs.setString(_kLanIpKey, ip);
    }
  }

  /// Generate candidates based on platform and user-configured LAN IP.
  /// No hardcoded developer IPs or tunnels — all configurable via SharedPreferences.
  List<String> _generateCandidates({String? lanIp}) {
    final hosts = <String>[];

    bool isDev = !kReleaseMode;

    if (kIsWeb) {
      if (isDev) {
        // In dev mode on web, prioritize the standard port and skip scanning to reduce noise
        return ['http://localhost:8081'];
      }
      hosts.add('localhost');
      hosts.add('127.0.0.1');
    } else {
      // Add user-configured LAN IP first (highest priority after cached/override)
      if (lanIp != null && lanIp.isNotEmpty) {
        hosts.add(lanIp);
      }
      hosts.add('localhost');
      hosts.add('127.0.0.1');
      hosts.add('10.0.2.2'); // Standard Android Emulator
      hosts.add('10.0.3.2'); // Genymotion
      hosts.add('169.254.2.2'); // Alternative bridge
    }

    final candidates = <String>[];
    for (var host in hosts) {
      for (var port in _kCandidatePorts) {
        candidates.add('http://$host:$port');
      }
    }

    return candidates.toSet().toList();
  }

  /// Probe candidates in parallel, returning the first one that succeeds.
  Future<String?> _probeParallel(List<String> candidates) async {
    if (candidates.isEmpty) return null;

    // Sort to prioritize bridge addresses (10.0.2.2, etc.) then port 8080/8081
    candidates.sort((a, b) {
      final isBridgeA = a.contains('10.0.2.2') || a.contains('10.0.3.2') || a.contains('169.254.2.2');
      final isBridgeB = b.contains('10.0.2.2') || b.contains('10.0.3.2') || b.contains('169.254.2.2');
      
      if (isBridgeA && !isBridgeB) return -1;
      if (!isBridgeA && isBridgeB) return 1;

      // Secondary: Sort by port (8081 then 8080)
      if (a.contains(':8081') && !b.contains(':8081')) return -1;
      if (!a.contains(':8081') && b.contains(':8081')) return 1;
      if (a.contains(':8080') && !b.contains(':8080')) return -1;
      if (!a.contains(':8080') && b.contains(':8080')) return 1;
      
      return 0;
    });

    final completer = Completer<String?>();
    int pending = candidates.length;
    bool found = false;

    for (final url in candidates) {
      testConnection(url).then((ok) {
        if (found) return;
        if (ok) {
          found = true;
          completer.complete(url);
        } else {
          pending--;
          if (pending == 0 && !found) {
            completer.complete(null);
          }
        }
      }).catchError((e, stackTrace) { // Added stackTrace
        _log.severe('Probe parallel candidate failed for $url: $e', e, stackTrace); // Added stackTrace logging
        if (found) return;
        pending--;
        if (pending == 0 && !found) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }
}
