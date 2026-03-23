import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:logging/logging.dart';

final Logger _mqttLog = Logger('MqttServiceIO');
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
      _mqttLog.info('Subscribed to $topic');
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

    try {
      if (chosenHost == null ||
          chosenHost == 'localhost' ||
          chosenHost == '127.0.0.1') {
        if (!kIsWeb) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            chosenHost = '10.0.2.2';
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            chosenHost = '127.0.0.1';
          }
        } else {
          chosenHost = chosenHost ?? 'localhost';
        }
      }
    } catch (_) {
      chosenHost = chosenHost ?? 'localhost';
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

    final hostStr = cleanHost;
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 10000).toString().padLeft(4, '0');
    final String clientId = 'hgMobile${now.toRadixString(36)}$randomSuffix';

    Future<bool> tryConnect(
        {required bool useWebSocket, required int port}) async {
      try {
        final c = MqttServerClient(hostStr, clientId);
        c.port = port;
        c.keepAlivePeriod = 20;
        c.logging(on: false);
        c.useWebSocket = useWebSocket;
        c.onConnected = () {
          _connected.add(true);
          _mqttLog.info(
              'connected to ${useWebSocket ? 'ws' : 'tcp'}://$hostStr:$port');
        };
        c.onDisconnected = () {
          _connected.add(false);
          _mqttLog.info(
              'disconnected from ${useWebSocket ? 'ws' : 'tcp'}://$hostStr:$port');
        };
        c.onSubscribed = (topic) => _mqttLog.info('subscribed to $topic');
        try {
          c.autoReconnect = true;
          c.resubscribeOnAutoReconnect = true;
        } catch (_) {}

        final connMess = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
        c.connectionMessage = connMess;

        _client = c;
        _mqttLog.info(
            'attempting ${useWebSocket ? 'WebSocket' : 'TCP'} connect to $hostStr:$port');
        try {
          await _client!.connect();
          await Future.delayed(const Duration(milliseconds: 200));
          if (_client!.connectionStatus?.state ==
              MqttConnectionState.connected) {
            return true;
          }
        } catch (e) {
          _mqttLog.fine(
              'connect attempt failed (${useWebSocket ? 'ws' : 'tcp'}): $e');
          try {
            _client?.disconnect();
          } catch (_) {}
        }
      } catch (e) {
        _mqttLog.fine('connect error: $e');
      }
      return false;
    }

    bool connected = await tryConnect(useWebSocket: false, port: tcpPort);
    if (!connected) {
      connected = await tryConnect(useWebSocket: true, port: wsPort);
    }

    _connected.add(connected);
  }

  Future<bool> publish(String topic, String payload,
      {MqttQos qos = MqttQos.atLeastOnce}) async {
    try {
      if (!isConnected) {
        _mqttLog.fine('publish failed, not connected (topic=$topic)');
        return false;
      }
      final builder = MqttClientPayloadBuilder();
      builder.addUTF8String(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
          retain: false);
      _mqttLog.fine('published to $topic -> $payload');
      return true;
    } catch (e) {
      _mqttLog.warning('publish error for $topic -> $e');
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

    try {
      if (chosenHost == null ||
          chosenHost == 'localhost' ||
          chosenHost == '127.0.0.1') {
        if (!kIsWeb) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            chosenHost = '10.0.2.2';
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            chosenHost = '127.0.0.1';
          }
        } else {
          chosenHost = chosenHost ?? 'localhost';
        }
      }
    } catch (_) {
      chosenHost = chosenHost ?? 'localhost';
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

    final hostStr = cleanHost;
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 10000).toString().padLeft(4, '0');
    final String clientId = 'hgTest${now.toRadixString(36)}$randomSuffix';
    const diagTopic = 'home/system/diagnostic';
    const diagPayload = '{"test":"mqtt_ping"}';

    Future<bool> tryAttempt(
        {required bool useWebSocket, required int port}) async {
      try {
        final c = MqttServerClient(hostStr, clientId);
        c.port = port;
        c.keepAlivePeriod = 20;
        c.logging(on: false);
        c.useWebSocket = useWebSocket;
        final connMess =
            MqttConnectMessage().withClientIdentifier(clientId).startClean();
        c.connectionMessage = connMess;
        await c.connect();
        await Future.delayed(const Duration(milliseconds: 200));
        if (c.connectionStatus?.state == MqttConnectionState.connected) {
          final builder = MqttClientPayloadBuilder();
          builder.addUTF8String(diagPayload);
          c.publishMessage(diagTopic, MqttQos.atLeastOnce, builder.payload!,
              retain: false);
          await Future.delayed(const Duration(milliseconds: 200));
          try {
            c.disconnect();
          } catch (_) {}
          return true;
        }
      } catch (e) {
        _mqttLog.fine(
            'testConnection attempt failed (${useWebSocket ? 'ws' : 'tcp'}): $e');
      }
      return false;
    }

    var ok = await tryAttempt(useWebSocket: false, port: tcpPort);
    if (!ok) ok = await tryAttempt(useWebSocket: true, port: wsPort);
    return ok;
  }

  void dispose() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _connected.close();
  }
}
