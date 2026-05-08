import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homegenie_app/network/api_locator.dart';

final _log = Logger('WebSocketService');

class WebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  bool _isManuallyStopped = false; // Add manual stop flag
  Timer? _reconnectTimer;
  int _retryDelaySeconds = 2;
  static const int _maxRetryDelay = 60;
  
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Key for persisted API token in SharedPreferences.
  static const String _kTokenKey = 'homegenie_auth_token';

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _isConnected;

  /// Store the API token for authenticated WebSocket connections.
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  /// Pre-resolved base URL to avoid re-running discovery on every connect.
  String? _baseUrlOverride;

  Future<void> connect({String? baseUrl}) async {
    _isManuallyStopped = false; // Reset on manual connect
    
    // If a specific baseUrl is provided and it differs from our current connection,
    // we must disconnect first to ensure we target the right backend.
    if (baseUrl != null && _baseUrlOverride != null && baseUrl != _baseUrlOverride) {
      _log.info('WebSocket: URL changed from $_baseUrlOverride to $baseUrl. Reconnecting...');
      disconnect();
    }

    if (_isConnected) {
      _log.fine('WebSocket: Already connected to $_baseUrlOverride');
      return;
    }

    // Use provided baseUrl, or the previously resolved one, or discover fresh.
    var resolved = baseUrl ?? _baseUrlOverride ?? await ApiLocator.getBaseUrl();
    
    // If we're stuck on localhost but it's failing, try to rediscover fresh 
    // to see if the network/server is back.
    if (resolved.contains('localhost') && baseUrl == null) {
      try {
        final String fresh = await ApiLocator.getBaseUrl();
        // Use a more resilient check to avoid DDC/JS prototype issues
        if (fresh.toLowerCase().contains('localhost') == false) {
          _log.info('WebSocket: Redirecting from localhost to discovered URL: $fresh');
          resolved = fresh;
        }
      } catch (e) {
        _log.warning('WebSocket: Discovery fallback failed: $e');
      }
    }
    
    _baseUrlOverride = resolved;
    final String effectiveBaseUrl = resolved;

    // Read token from SharedPreferences instead of hardcoding
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey) ?? '';
    final queryParams = token.isNotEmpty ? '?token=$token' : '';
    final wsUrl = '${effectiveBaseUrl.replaceFirst('http', 'ws')}/ws$queryParams';
    
    _log.info('Connecting to WebSocket: $wsUrl (ReleaseMode: $kReleaseMode)');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _retryDelaySeconds = 2; // Reset on success
      _connectionStateController.add(true);
      _log.info('WebSocket connected successfully to $wsUrl');

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message) as Map<String, dynamic>;
            _controller.add(data);
          } catch (e) {
            _log.warning('Error decoding WebSocket message from $wsUrl: $e');
          }
        },
        onDone: () {
          _log.info('WebSocket connection closed for $wsUrl');
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
        onError: (error) {
          _log.warning(
              'WebSocket error for $wsUrl: $error. Ensure backend is running and CORS allows this IP.');
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _log.warning('Failed to connect to WebSocket at $wsUrl: $e');
      _isConnected = false;
      _connectionStateController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isManuallyStopped) return; // Prevent automatic reconnect if manually stopped
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryDelaySeconds), () {
      _log.info('Attempting to reconnect to WebSocket in $_retryDelaySeconds seconds (exponential backoff)...');
      _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(2, _maxRetryDelay);
      connect();
    });
  }

  void disconnect() {
    _isManuallyStopped = true; // Set manual stop flag
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
