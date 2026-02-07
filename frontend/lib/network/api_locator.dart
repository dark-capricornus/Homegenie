import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

final Logger _apiLocatorLog = Logger('ApiLocator');

/// ApiLocator - finds a reachable backend URL using a prioritized strategy.
///
  /// Detection priority:
  /// 1. manual override (server_override_url)
  /// 2. cached_server_url (SharedPreferences)
  /// 3. LAN scan (common private ranges)
  /// 4. Cloud fallback
class ApiLocator {
  static const _kCachedKey = 'cached_server_url';
  static const _kOverrideKey = 'server_override_url';
  static const _kCloudFallback = 'https://homegenie-cloud.example.com';

  /// Return a usable base URL. This method is safe to call repeatedly; it
  /// checks cached and override values first and caches successful discoveries.
  static Future<String> getBaseUrl({Duration perIpTimeout = const Duration(milliseconds: 700)}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. manual override (highest priority)
    final override = prefs.getString(_kOverrideKey);
    if (override != null) {
        if (await testUrl(override, timeout: perIpTimeout)) {
          _apiLocatorLog.info('using manual override: $override');
        await prefs.setString(_kCachedKey, override);
        return override;
      } else {
        // Invalid manual override - remove it
        await prefs.remove(_kOverrideKey);
      }
    }

    // 2. cached URL (if not pointing to dev ports)
    final cached = prefs.getString(_kCachedKey);
    if (cached != null) {
      final lower = cached.toLowerCase();
      if (lower.contains(':8081') || lower.contains(':3000') || lower.contains(':8082')) {
        await prefs.remove(_kCachedKey);
      } else if (await testUrl(cached, timeout: perIpTimeout)) {
          _apiLocatorLog.info('using cached base URL: $cached');
        return cached;
      }
    }

    // (emulator handled earlier as enforced default)

    // 4. LAN scan (conservative list to keep CPU/network usage low)
    final candidates = _generateLanCandidates();
    final found = await _scanCandidates(candidates, perIpTimeout);
    if (found != null && found.isNotEmpty) {
      await prefs.setString(_kCachedKey, found);
      return found;
    }

    // 5. cloud fallback
    if (await testUrl(_kCloudFallback, timeout: perIpTimeout)) {
      await prefs.setString(_kCachedKey, _kCloudFallback);
      return _kCloudFallback;
    }

    // Nothing found: return localhost default (non-blocking caller should handle it)
    return 'http://localhost:8000';
  }

  /// Test a URL by calling GET /state and expecting valid JSON within a timeout.
  static Future<bool> testUrl(String url, {Duration timeout = const Duration(milliseconds: 700)}) async {
    try {
      final uri = Uri.parse(url);
      // normalize: ensure no trailing slash
      final base = uri.toString().replaceAll(RegExp(r'/*$'), '');
      final probe = Uri.parse('$base/state');
        _apiLocatorLog.info('probing $probe');
      final resp = await http.get(probe).timeout(timeout);
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded != null) return true;
      }
    } catch (e) {
        _apiLocatorLog.severe('probe failed for $url -> $e');
    }
    return false;
  }

  /// Persist manual override (or clear by passing null)
  static Future<void> setManualOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_kOverrideKey);
      await prefs.remove(_kCachedKey);
    } else {
      await prefs.setString(_kOverrideKey, url);
      await prefs.setString(_kCachedKey, url);
    }
  }

  static Future<String?> getManualOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOverrideKey);
  }

  /// Generate a conservative set of LAN candidates based on common private ranges
  static List<String> _generateLanCandidates() {
    final ranges = <String>[];
    // common ranges
    ranges.addAll([
      '192.168.1',
      '192.168.0',
      '192.168.43', // android hotspot
      '10.0.2', // common emulator subnet
      '10.0.0',
      '10.132.71',
      '172.16.0',
    ]);

    final commonHosts = [1, 2, 100, 101, 102, 103, 104, 105, 110, 200, 254];
    final List<String> candidates = [];
    for (final r in ranges) {
      for (final h in commonHosts) {
        candidates.add('http://$r.$h:8000');
        candidates.add('http://$r.$h:8080');
      }
    }

    // Add localhost fallbacks
    candidates.addAll(['http://localhost:8000', 'http://localhost:8080']);
    return candidates;
  }

  /// Scan a list of candidate URLs with limited concurrency and return the first working URL.
  static Future<String?> _scanCandidates(List<String> candidates, Duration timeout) async {
    const concurrency = 10;
    // Simpler approach: run in batches with limited parallelism
    for (int i = 0; i < candidates.length; i += concurrency) {
      final batch = candidates.skip(i).take(concurrency).toList();
      final futures = batch.map((c) => testUrl(c, timeout: timeout).then((ok) => ok ? c : null));
      final res = await Future.wait(futures);
      for (final r in res) {
        if (r != null) return r;
      }
      // small delay between batches
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return null;
  }
}
