import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:homegenie_app/network/mqtt_service.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/network/websocket_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:homegenie_app/core/services/device_service.dart';
import 'package:homegenie_app/core/services/ai_service.dart';
import 'package:homegenie_app/core/services/insights_service.dart';

final _log = Logger('DashboardController');

enum ConnectionStatus { unknown, connected, disconnected }

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}



// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------
class DashboardController extends ChangeNotifier {
  String baseUrl = '';
  Map<String, dynamic> _rawDevices = {};
  Map<String, bool> deviceToggles = {};
  Map<String, bool> isToggleLoading = {};
  bool isLoading = false;
  bool isProcessingGoal = false;
  String statusMessage = '';
  String? lastGoalResult;
  ConnectionStatus connectionStatus = ConnectionStatus.unknown;
  MqttService? _mqttService;
  bool mqttConnected = false;
  Timer? _statusTimer;
  DateTime? _lastStatusCheck;
  late final WebSocketService _wsService;
  late final DeviceService _deviceService;
  late final AIService _aiService;
  late final InsightsService _insightsService;

  // Canonical device keys from /devices — the source of truth for WHICH
  // devices exist.  WebSocket/MQTT updates are only accepted for keys in
  // this set (after normalisation).
  Set<String> _knownDeviceKeys = {};

  // Debounce: coalesce rapid notifyListeners() calls into one per frame.
  bool _notifyScheduled = false;

  // ETag for conditional HTTP fetches
  String? _devicesEtag;

  // Frequency tracking
  Map<String, int> _deviceAccessCounts = {};
  static const String _kAccessCountsKey = 'device_access_counts';

  // Chat state
  List<ChatMessage> chatMessages = [];
  bool isChatProcessing = false;

  // Insights state
  List<Map<String, dynamic>> insights = [];
  List<Map<String, dynamic>> suggestions = [];
  Map<String, dynamic> analytics = {};
  bool isInsightsLoading = false;

  // ---------------------------------------------------------------------------
  // Computed getters
  // ---------------------------------------------------------------------------
  List<DeviceInfo> get devices => _rawDevices.entries
      .map((e) => DeviceInfo(
            key: e.key,
            data: _deviceService.normalizeDeviceData(e.value),
            name: _deviceService.formatDeviceName(e.key),
            type: _deviceService.getDeviceType(e.key),
          ))
      .toList();

  double get totalPowerConsumption {
    double total = 0;
    for (final device in devices) {
      if (device.isOn) {
        total += (device.data['power_consumption'] ?? 0.0).toDouble();
      }
    }
    return total;
  }

  Map<String, List<DeviceInfo>> get devicesByRoom {
    final map = <String, List<DeviceInfo>>{};
    for (final d in devices) {
      final parts = d.key.split('.');
      final room = parts.length > 1 ? parts[1] : 'Other';
      map.putIfAbsent(room, () => []).add(d);
    }
    return map;
  }

  List<DeviceInfo> get frequentlyAccessedDevices {
    final sorted = List<DeviceInfo>.from(devices);
    sorted.sort((a, b) {
      final countA = _deviceAccessCounts[a.key] ?? 0;
      final countB = _deviceAccessCounts[b.key] ?? 0;
      return countB.compareTo(countA);
    });
    return sorted.take(8).toList();
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  DashboardController() {
    _deviceService = DeviceService();
    _aiService = AIService();
    _insightsService = InsightsService();
    _wsService = WebSocketService();
    _wsService.stream.listen(_handleWsMessage);
  }

  /// Coalesce multiple state changes into a single notifyListeners() call
  /// per microtask, preventing excessive widget rebuilds from rapid
  /// WebSocket/MQTT bursts.
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Frequency tracking
  // ---------------------------------------------------------------------------
  Future<void> _loadAccessCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAccessCountsKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        _deviceAccessCounts = decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (_) {}
  }

  Future<void> _incrementAccessCount(String deviceKey) async {
    _deviceAccessCounts[deviceKey] = (_deviceAccessCounts[deviceKey] ?? 0) + 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessCountsKey, json.encode(_deviceAccessCounts));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Chat / voice
  // ---------------------------------------------------------------------------
  Future<void> sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;
    chatMessages.add(ChatMessage(text: message, isUser: true));
    isChatProcessing = true;
    notifyListeners();

    try {
      final url = await ApiLocator.getBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('homegenie_api_token') ?? '';

      // Try the goal endpoint for device control commands
      final resp = await _aiService.sendGoal(url, message, token);

      if (resp.statusCode < 300) {
        final data = json.decode(resp.body);
        // Prefer the agent's conversational 'response' field, then 'message'
        final responseText = data['response'] ??
            data['message'] ??
            data['output'] ??
            data['result'] ??
            'Command processed successfully.';
        chatMessages.add(ChatMessage(text: responseText.toString(), isUser: false));
      } else {
        chatMessages.add(ChatMessage(
            text: 'Sorry, I could not process that request.', isUser: false));
      }
    } catch (e, st) {
      _log.severe('sendChatMessage error: $e\n$st');
      chatMessages
          .add(ChatMessage(text: 'Connection error. Please try again.', isUser: false));
    } finally {
      isChatProcessing = false;
      notifyListeners();
      await fetchDevices();
    }
  }

  Future<void> sendVoiceAudio(List<int> audioBytes, String filename) async {
    isChatProcessing = true;
    notifyListeners();

    try {
      final url = await ApiLocator.getBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('homegenie_api_token') ?? '';

      final resp = await _aiService.transcribeAudio(url, token, audioBytes, filename);

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final transcript = (data['transcript'] ?? '').toString().trim();

        if (transcript.isEmpty) {
          chatMessages.add(ChatMessage(
              text: 'Could not understand. Please try again.', isUser: false));
          isChatProcessing = false;
          notifyListeners();
          return;
        }

        // Show user voice as message bubble
        chatMessages.add(ChatMessage(text: transcript, isUser: true));

        // If n8n already responded, use that; otherwise send through goal pipeline
        final n8n = data['n8n_response'];
        if (n8n != null) {
          final responseText =
              n8n['response'] ?? n8n['output'] ?? 'Command processed.';
          chatMessages
              .add(ChatMessage(text: responseText.toString(), isUser: false));
          isChatProcessing = false;
          notifyListeners();
          await fetchDevices();
        } else {
          // sendChatMessage handles isChatProcessing + notifyListeners
          isChatProcessing = false;
          await sendChatMessage(transcript);
        }
      } else {
        chatMessages.add(
            ChatMessage(text: 'Transcription failed. Please try again.', isUser: false));
        isChatProcessing = false;
        notifyListeners();
      }
    } catch (_) {
      chatMessages.add(ChatMessage(
          text: 'Voice processing error. Please try again.', isUser: false));
      isChatProcessing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // MQTT / WebSocket handlers
  // ---------------------------------------------------------------------------
  void _handleMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final m in messages) {
      final topic = m.topic;
      final p = m.payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(p.payload.message);
      try {
        final data = json.decode(payload) as Map<String, dynamic>;
        final key = _topicToDeviceKey(topic);
        if (!_isKnownDevice(key)) continue;
        _mergeDeviceState(key, data);
        _syncToggle(key, _rawDevices[key]);
      } catch (e) {
        _log.warning('Error parsing MQTT payload: $e');
      }
    }
    _scheduleNotify();
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'initial_state') {
      final rawData = data['data'];
      final stateData = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final rawStates =
          stateData.containsKey('states') ? stateData['states'] : stateData;
      if (rawStates is Map) {
        int accepted = 0;
        int rejected = 0;
        for (final entry in rawStates.entries) {
          final rawTopic = entry.key.toString();
          final key = _topicToDeviceKey(rawTopic);
          if (!_isKnownDevice(key)) {
            rejected++;
            continue;
          }
          accepted++;
          _mergeDeviceState(key, entry.value);
        }
        _log.info(
          'WS initial_state: ${rawStates.length} topics, '
          '$accepted accepted, $rejected rejected, '
          '_rawDevices=${_rawDevices.length}, '
          'knownKeys=${_knownDeviceKeys.length}',
        );
      }
      _syncAllToggles();
      _scheduleNotify();
    } else if (type == 'state_update') {
      final topic = data['topic'] as String;
      final payload = data['payload'];
      final key = _topicToDeviceKey(topic);
      if (!_isKnownDevice(key)) {
        _log.fine('WS state_update rejected: topic=$topic key=$key');
        return;
      }
      _mergeDeviceState(key, payload);
      _syncToggle(key, _rawDevices[key]);
      _scheduleNotify();
    }
  }

  /// Returns true if [key] belongs to a device we know about.
  /// If _knownDeviceKeys hasn't been populated yet (first /devices call
  /// hasn't completed), we REJECT all updates to prevent phantom devices.
  /// The authoritative device list will arrive shortly via fetchDevices().
  bool _isKnownDevice(String key) {
    if (_knownDeviceKeys.isEmpty) return false;
    return _knownDeviceKeys.contains(key);
  }

  /// Merge a realtime state payload into the existing device entry, updating
  /// only the 'state' sub-map rather than replacing the whole structured
  /// record that /devices returned (which also has device_id, type, name).
  void _mergeDeviceState(String key, dynamic payload) {
    final existing = _rawDevices[key];
    if (existing is Map<String, dynamic> && existing.containsKey('device_id')) {
      // /devices gave us a structured record — update only its 'state' field.
      if (payload is Map) {
        _rawDevices[key] = {
          ...existing,
          'state': Map<String, dynamic>.from(payload),
        };
      } else {
        _rawDevices[key] = {
          ...existing,
          'state': {'state': payload, 'value': payload, 'power': payload},
        };
      }
    } else {
      // No structured record yet — store the raw payload.
      _rawDevices[key] = payload;
    }
  }

  /// Converts any topic format to the canonical dot-notation device key
  /// used by the /devices endpoint (e.g. "light.living_room").
  ///
  /// Supported formats:
  ///   "devices/temperature.living_room/observed"  → "temperature.living_room"
  ///   "devices/temperature.living_room/commanded" → "temperature.living_room"
  ///   "home/light/living_room/state"              → "light.living_room"
  ///   "home/light/living_room/set"                → "light.living_room"
  ///   "light.living_room"                         → "light.living_room" (passthrough)
  ///
  /// Non-device topics (probes/*, system/*, etc.) pass through unchanged
  /// and will be rejected by _isKnownDevice().
  String _topicToDeviceKey(String topic) {
    // New format: devices/{device_id}/observed or /commanded
    if (topic.startsWith('devices/')) {
      final parts = topic.split('/');
      if (parts.length >= 2) return parts[1]; // already dot-notation
    }
    // Legacy MQTT format: home/{type}/{location}/state or /set
    if (topic.startsWith('home/')) {
      final parts = topic.split('/');
      if (parts.length >= 3) return '${parts[1]}.${parts[2]}';
    }
    // Already dot-notation or unknown — return as-is
    return topic;
  }

  void _syncAllToggles() {
    _rawDevices.forEach((key, value) => _syncToggle(key, value));
  }



  void _syncToggle(String key, dynamic value) {
    if (!(isToggleLoading[key] ?? false)) {
      final normalized = _deviceService.normalizeDeviceData(value);
      final rawState = normalized['state'];
      final state = rawState is Map
          ? Map<String, dynamic>.from(rawState)
          : <String, dynamic>{};
      final type = _deviceService.getDeviceType(key);

      if (type == 'light' || type == 'switch') {
        deviceToggles[key] = state['power']?.toString().toLowerCase() == 'on' ||
            state['state']?.toString().toLowerCase() == 'on';
      } else if (type == 'sensor') {
        final val = (state['state'] ?? state['power'] ?? state['value'])
            ?.toString()
            .toLowerCase();
        deviceToggles[key] =
            val == 'on' || val == 'true' || val == 'open' || val == 'detected';
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    _log.info('DashboardController initializing...');
    isLoading = true;
    statusMessage = 'Discovering HomeGenie server...';
    notifyListeners();
    _log.info('DASHBOARD_INIT: start');

    await _loadAccessCounts();

    try {
      baseUrl = await ApiLocator.getBaseUrl();
      statusMessage = 'Connected';
      _log.info('DASHBOARD_INIT: calling fetchDevices');
      await fetchDevices();
      _log.info('DASHBOARD_INIT: fetchDevices complete');
      await fetchInsights();
      await _wsService.connect(baseUrl: baseUrl);
      _statusTimer = Timer.periodic(
          const Duration(seconds: 10), (_) => _checkConnection());
      _mqttService = MqttService();
      await _mqttService!.connect();
      _mqttService!.connectedStream.listen((c) {
        mqttConnected = c;
        if (c) { _mqttService!.subscribe('home/+/+/state'); }
        notifyListeners();
      });
      _mqttService!.messagesStream?.listen(_handleMqttMessage);
    } catch (e) {
      statusMessage = 'Discovery failed: $e';
      _log.warning(statusMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkConnection() async {
    final now = DateTime.now();
    if (_lastStatusCheck != null &&
        now.difference(_lastStatusCheck!).inSeconds < 10) {
      return;
    }
    _lastStatusCheck = now;
    if (baseUrl.isEmpty) {
      connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
      return;
    }
    final ok = await ApiLocator.testUrl(baseUrl);
    connectionStatus =
        ok ? ConnectionStatus.connected : ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> fetchDevices() async {
    if (isProcessingGoal || baseUrl.isEmpty) return;
    if (!kIsWeb && baseUrl.contains('localhost')) return;
    try {
      final resp = await _deviceService.fetchDevices(baseUrl, _devicesEtag);

      // 304 Not Modified — nothing changed on the server.
      if (resp.statusCode == 304) {
        _log.fine('FETCH_DEVICES: 304 Not Modified, skipping');
        return;
      }

      _log.info('FETCH_DEVICES: status=${resp.statusCode}, len=${resp.body.length}');
      if (resp.statusCode == 200) {
        // Cache ETag for next conditional request.
        final etag = resp.headers['etag'];
        if (etag != null) _devicesEtag = etag;

        final data = json.decode(resp.body) as Map<String, dynamic>;
        final incoming = (data.containsKey('devices')
                ? data['devices']
                : data['states'] ?? data)
            as Map<String, dynamic>;

        // Build the canonical set of known device keys.
        _knownDeviceKeys = incoming.keys.toSet();

        // Replace _rawDevices with the authoritative /devices payload, then
        // prune any stale keys that WebSocket/MQTT may have added.
        _rawDevices = Map<String, dynamic>.from(incoming);

        _log.info('FETCH_DEVICES: success, items=${_rawDevices.length}');
        _rawDevices.forEach((key, value) {
          if (!(isToggleLoading[key] ?? false)) _syncToggle(key, value);
        });
        statusMessage =
            'Updated at ${DateTime.now().toString().substring(11, 19)}';
        notifyListeners();
      }
    } catch (e) {
      _log.warning('Failed to fetch devices: $e');
    }
  }

  Future<void> fetchInsights() async {
    if (baseUrl.isEmpty) return;
    isInsightsLoading = true;
    notifyListeners();
    try {
      final results = await _insightsService.fetchInsightsData(baseUrl);

      if (results[0].statusCode == 200) {
        final data = json.decode(results[0].body) as Map<String, dynamic>;
        insights = List<Map<String, dynamic>>.from(data['insights'] ?? []);
      }
      if (results[1].statusCode == 200) {
        final data = json.decode(results[1].body) as Map<String, dynamic>;
        suggestions = List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
      }
      if (results[2].statusCode == 200) {
        final data = json.decode(results[2].body) as Map<String, dynamic>;
        analytics = (data['analytics'] ?? {}) as Map<String, dynamic>;
      }
      _log.info('Fetched ${insights.length} insights, ${suggestions.length} suggestions');
    } catch (e) {
      _log.warning('Failed to fetch insights: $e');
    } finally {
      isInsightsLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendGoal(String message) async {
    isProcessingGoal = true;
    statusMessage = 'AI is thinking...';
    notifyListeners();
    try {
      final url = await ApiLocator.getBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('homegenie_api_token') ?? '';
      final resp = await _aiService.sendGoal(url, message, token);

      if (resp.statusCode < 300) {
        statusMessage = 'Goal processed successfully!';
        lastGoalResult = 'Success: Command executed';
      } else {
        statusMessage = 'AI had trouble: ${resp.statusCode}';
        lastGoalResult = 'Error: AI brain not responding correctly';
      }
    } catch (e) {
      statusMessage = 'Connection error. Check backend.';
      lastGoalResult = 'Error: Connection failed';
      _log.severe('Goal error: $e');
    } finally {
      isProcessingGoal = false;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      await fetchDevices();
    }
  }

  Future<void> toggleDevice(DeviceInfo device) async {
    final current = deviceToggles[device.key] ?? device.isActive;
    final next = !current;
    deviceToggles[device.key] = next;
    isToggleLoading[device.key] = true;
    notifyListeners();

    // Locks use lock/unlock actions; everything else uses turn_on/turn_off
    final String action;
    if (device.type == 'lock') {
      action = next ? 'lock' : 'unlock';
    } else {
      action = next ? 'turn_on' : 'turn_off';
    }

    try {
      if (baseUrl.isEmpty) return;
      await _deviceService.toggleDevice(baseUrl, device.key, action);
      await _incrementAccessCount(device.key);
    } catch (e) {
      _log.warning('Failed to toggle device ${device.key}: $e');
      deviceToggles[device.key] = current;
    } finally {
      isToggleLoading[device.key] = false;
      notifyListeners();
      await fetchDevices();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _wsService.dispose();
    _mqttService?.dispose();
    super.dispose();
  }
}
