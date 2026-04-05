import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:logging/logging.dart';

final Logger _mqttLogWeb = Logger('MqttServiceWeb');
const _kMqttOverrideKey = 'mqtt_override_host';

class MqttService {
  dynamic _client;
  final _connected = StreamController<bool>.broadcast();

  Stream<bool> get connectedStream => _connected.stream;
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get messagesStream =>
      _client?.updates;

  void subscribe(String topic) {
    if (isConnected) {
      _client?.subscribe(topic, MqttQos.atLeastOnce);
      _mqttLogWeb.info('Subscribed to $topic');
    }
  }

  Future<void> connect(
      {String? host, int tcpPort = 1883, int wsPort = 9003}) async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_kMqttOverrideKey);

    String? chosenHost = host ?? override;
    if (chosenHost == null) {
      try {
        final base = await ApiLocator.getBaseUrl();
        if (base.isNotEmpty) {
          try {
            final uri = Uri.parse(base);
            if (uri.host.isNotEmpty) chosenHost = uri.host;
          } catch (_) {}
        }
      } catch (_) {}
    }

    var cleanHost = 'localhost';
    if (chosenHost != null && chosenHost.isNotEmpty) {
      try {
        if (!chosenHost.contains('://')) {
          final uri = Uri.parse('http://$chosenHost');
          cleanHost = uri.host.isNotEmpty ? uri.host : chosenHost.split(':')[0];
        } else {
          final uri = Uri.parse(chosenHost);
          cleanHost = uri.host.isNotEmpty ? uri.host : 'localhost';
        }
      } catch (_) {
        cleanHost = chosenHost.split(':')[0];
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 10000).toString().padLeft(4, '0');
    final clientId = 'hgWeb${now.toRadixString(36)}$randomSuffix';

    // Unified Proxy Path: If on ngrok or external, use /ws through Nginx
    // Strip port for proxy path if it's not localhost
    final isLocal = cleanHost == 'localhost' || cleanHost == '127.0.0.1';
    final serverUri = isLocal
        ? 'ws://$cleanHost:$wsPort/'
        : 'wss://$cleanHost/';
    
    _mqttLogWeb.info('Configured MQTT WebSocket URI: $serverUri');
    try {
      final bc = MqttBrowserClient(serverUri, clientId);
      bc.port = isLocal ? wsPort : 443;
      bc.websocketProtocols = ['mqtt'];
      bc.setProtocolV311();
      bc.logging(on: false);
      try {
        bc.autoReconnect = true;
        bc.resubscribeOnAutoReconnect = true;
      } catch (_) {}
      final connMess =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();
      bc.connectionMessage = connMess;
      _client = bc as dynamic;
      _mqttLogWeb.info('attempting WebSocket (browser) connect to $serverUri');
      await bc.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      if (bc.connectionStatus?.state == MqttConnectionState.connected) {
        _connected.add(true);
      } else {
        _connected.add(false);
      }
    } catch (e) {
      _mqttLogWeb.warning('browser WS connect failed: $e');
      try {
        (_client as MqttBrowserClient?)?.disconnect();
      } catch (_) {}
      _connected.add(false);
    }
  }

  Future<bool> publish(String topic, String payload,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    try {
      if (!isConnected) return false;
      final builder = MqttClientPayloadBuilder();
      builder.addUTF8String(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
          retain: false);
      _mqttLogWeb.fine('published to $topic -> $payload');
      return true;
    } catch (e) {
      _mqttLogWeb.warning('publish error for $topic -> $e');
      return false;
    }
  }

  Future<bool> testConnection(
      {String? overrideHost, int tcpPort = 1883, int wsPort = 9003}) async {
    String? chosenHost = overrideHost;
    try {
      final prefs = await SharedPreferences.getInstance();
      chosenHost = chosenHost ?? prefs.getString(_kMqttOverrideKey);
    } catch (_) {}

    if (chosenHost == null) {
      try {
        final base = await ApiLocator.getBaseUrl();
        if (base.isNotEmpty) {
          try {
            final uri = Uri.parse(base);
            if (uri.host.isNotEmpty) chosenHost = uri.host;
          } catch (_) {}
        }
      } catch (_) {}
    }

    var cleanHost = 'localhost';
    if (chosenHost != null && chosenHost.isNotEmpty) {
      try {
        if (!chosenHost.contains('://')) {
          final uri = Uri.parse('http://$chosenHost');
          cleanHost = uri.host.isNotEmpty ? uri.host : chosenHost.split(':')[0];
        } else {
          final uri = Uri.parse(chosenHost);
          cleanHost = uri.host.isNotEmpty ? uri.host : 'localhost';
        }
      } catch (_) {
        cleanHost = chosenHost.split(':')[0];
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 10000).toString().padLeft(4, '0');
    final clientId = 'hgTest${now.toRadixString(36)}$randomSuffix';
    final serverUri = 'ws://$cleanHost:$wsPort/';
    const diagTopic = 'home/system/diagnostic';
    const diagPayload = '{"test":"mqtt_ping"}';

    try {
      final bc = MqttBrowserClient(serverUri, clientId);
      bc.port = wsPort;
      bc.websocketProtocols = ['mqtt'];
      bc.setProtocolV311();
      bc.logging(on: false);
      final connMess =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();
      bc.connectionMessage = connMess;
      await bc.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      if (bc.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addUTF8String(diagPayload);
        bc.publishMessage(diagTopic, MqttQos.atLeastOnce, builder.payload!,
            retain: false);
        await Future.delayed(const Duration(milliseconds: 200));
        bc.disconnect();
        return true;
      }
    } catch (e) {
      _mqttLogWeb.warning('testConnection failed (web): $e');
      try {
        // best-effort disconnect
      } catch (_) {}
    }
    return false;
  }

  void dispose() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _connected.close();
  }
}
