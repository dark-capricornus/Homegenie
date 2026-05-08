import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:homegenie_app/core/models/device.dart';
import 'package:homegenie_app/network/websocket_service.dart';
import 'package:homegenie_app/core/services/device_service.dart';
import 'package:homegenie_app/core/services/ai_service.dart';
import 'package:homegenie_app/core/services/insights_service.dart';
import 'package:homegenie_app/core/services/auth_service.dart';
import 'package:homegenie_app/core/services/integration_service.dart';
import 'package:homegenie_app/core/models/user.dart';
import 'package:homegenie_app/core/models/integration.dart';

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
  Timer? _statusTimer;
  DateTime? _lastStatusCheck;
  late final WebSocketService _wsService;
  StreamSubscription<bool>? _wsSubscription; // Single subscription
  bool wsConnected = false;
  late final DeviceService _deviceService;
  late final AIService _aiService;
  late final InsightsService _insightsService;
  AuthService? _authService;
  AuthService get authService => _authService!;

  // Canonical device keys from /devices — the source of truth for WHICH
  // devices exist.  WebSocket/MQTT updates are only accepted for keys in
  // this set (after normalisation).
  Set<String> _knownDeviceKeys = {};

  // Debounce: coalesce rapid notifyListeners() calls into one per frame.
  bool _notifyScheduled = false;

  // ETag for conditional HTTP fetches
  String? _devicesEtag;

  // Cache invalidation token. Bumped whenever _rawDevices or
  // _deviceAccessCounts changes so memoized getters know to recompute.
  int _dataVersion = 0;

  // Memoized derived collections — recomputed only when _dataVersion changes.
  int _cachedDevicesVersion = -1;
  List<DeviceInfo>? _cachedDevices;
  int _cachedDevicesByRoomVersion = -1;
  Map<String, List<DeviceInfo>>? _cachedDevicesByRoom;
  int _cachedFrequentVersion = -1;
  List<DeviceInfo>? _cachedFrequent;

  void _invalidateDeviceCaches() {
    _dataVersion++;
    _cachedDevices = null;
    _cachedDevicesByRoom = null;
    _cachedFrequent = null;
  }

  // Frequency tracking
  Map<String, int> _deviceAccessCounts = {};
  // Persistence keys
  static const String _kAccessCountsKey = 'device_access_counts';
  static const String _kModeKey = 'homegenie_mode_demo';
  static const String _kTokenKey = 'homegenie_auth_token';
  static const String _kUserKey = 'homegenie_user_data';

  // Mode state
  bool? _isDemoMode;
  bool get isDemoMode => _isDemoMode ?? true;
  bool get hasModeSet => _isDemoMode != null;

  // Authentication
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  String? _token;
  String? get token => _token;

  Future<AuthService> _getValidatedAuth() async {
    if (_authService != null) return _authService!;
    
    final baseUrl = await ApiLocator.getBaseUrl();
    if (baseUrl.isNotEmpty && baseUrl.startsWith('http')) {
      _authService = AuthService(baseUrl: baseUrl);
      return _authService!;
    }
    
    // Explicit fallback if somehow still empty/invalid
    _authService = AuthService(baseUrl: 'http://localhost:8081');
    return _authService!;
  }

  // Update debouncing
  Timer? _updateDebounceTimer;
  final Map<String, dynamic> _pendingUpdates = {};

  Future<void> login(String username, String password) async {
    try {
      final auth = await _getValidatedAuth();
      final result = await auth.login(username, password);
      _token = result['access_token'];
      _isLoggedIn = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, _token!);
      
      // Fetch user profile
      _currentUser = await auth.getMe(_token!);
      if (_currentUser != null) {
        await prefs.setString(_kUserKey, _currentUser!.toJson());
      }
      
      _scheduleNotify();
    } catch (e) {
      _log.severe('Login failed: $e');
      rethrow;
    }
  }

  Future<void> register(String username, String password, {String? email}) async {
    try {
      final auth = await _getValidatedAuth();
      final result = await auth.register(username, password, email: email);
      _token = result['access_token'];
      _isLoggedIn = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, _token!);
      
      _currentUser = User(username: username, email: email);
      await prefs.setString(_kUserKey, _currentUser!.toJson());
      
      _scheduleNotify();
    } catch (e) {
      _log.severe('Registration failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _isLoggedIn = false;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
    
    _scheduleNotify();
  }

  // Chat state
  List<ChatMessage> chatMessages = [];
  bool isChatProcessing = false;

  // Insights state
  List<Map<String, dynamic>> insights = [];
  List<Map<String, dynamic>> suggestions = [];
  Map<String, dynamic> analytics = {};
  bool isInsightsLoading = false;
  
  // History state
  List<Map<String, dynamic>> energyHistory = [];
  List<Map<String, dynamic>> energyBreakdown = [];
  bool isHistoryLoading = false;
  int currentHistoryDays = 1;
  
  // Rules state
  List<Map<String, dynamic>> rules = [];
  bool isRulesLoading = false;

  // Integration state (Live mode)
  List<PlatformIntegration> integrations = [];
  bool isIntegrationsLoading = false;
  late final IntegrationService _integrationService;

  // ---------------------------------------------------------------------------
  // Computed getters
  // ---------------------------------------------------------------------------
  List<DeviceInfo> get devices {
    if (_cachedDevices != null && _cachedDevicesVersion == _dataVersion) {
      return _cachedDevices!;
    }
    // Canonical device list filtered for interactive devices and sorted by name
    final filteredDevices = _rawDevices.entries.map((e) => DeviceInfo(
      key: e.key,
      data: _deviceService.normalizeDeviceData(e.value),
      name: _deviceService.formatDeviceName(e.key),
      type: _deviceService.getDeviceType(e.key),
    )).where((d) => d.type != 'sensor').toList();

    filteredDevices.sort((a, b) {
      final nameComp = a.name.compareTo(b.name);
      return nameComp != 0 ? nameComp : a.key.compareTo(b.key);
    });

    _cachedDevices = List.unmodifiable(filteredDevices);
    _cachedDevicesVersion = _dataVersion;
    return _cachedDevices!;
  }

  double get totalPowerConsumption {
    double total = 0;
    for (final device in devices) {
      if (device.isOn) {
        total += device.powerConsumption;
      }
    }
    return total;
  }

  bool _aiEngineActive = true;
  bool get aiEngineActive => _aiEngineActive;
  void toggleAiEngine(bool value) {
    _aiEngineActive = value;
    logActivity('AI Engine ${value ? 'Started' : 'Stopped'}');
    notifyListeners();
  }

  // Live Power Tracking for Sparklines.
  //
  // Exposed as a ValueNotifier so the sparkline widget can listen via
  // ValueListenableBuilder and rebuild on its own — without dragging the
  // entire DashboardController consumer tree along for every 2s tick.
  final ValueNotifier<List<double>> powerSpotsNotifier =
      ValueNotifier<List<double>>(const []);
  List<double> get powerSpots => powerSpotsNotifier.value;
  static const int _maxPowerSpots = 50;
  Timer? _powerTimer;

  final List<String> _recentActivity = [
    'AI Planner Initiated · Queuing evening routine',
    'Environment Updated · Temp sensor recalibrated',
    'Rule Triggered · Hallway Welcome Rule fired',
  ];
  List<String> get recentActivity => _recentActivity;

  void logActivity(String message) {
    _recentActivity.insert(0, message);
    if (_recentActivity.length > 20) _recentActivity.removeLast();
    notifyListeners();
  }

  void clearActivity() {
    _recentActivity.clear();
    notifyListeners();
  }

  Map<String, List<DeviceInfo>> get devicesByRoom {
    if (_cachedDevicesByRoom != null &&
        _cachedDevicesByRoomVersion == _dataVersion) {
      return _cachedDevicesByRoom!;
    }
    final map = <String, List<DeviceInfo>>{};
    for (final d in devices) {
      // 1. Try explicit location/room from normalized data
      String? room = d.data['location'] ?? d.data['room'];

      // 2. Fallback to parsing the key (type.location)
      if (room == null || room.isEmpty) {
        final parts = d.key.split('.');
        room = parts.length > 1 ? parts[1] : 'Other';
      }

      // 3. Normalize and canonicalize room name for grouping. This merges
      // semantically duplicate rooms (e.g. "outdoor_temp" → "outdoor",
      // "motion_living" → "living_room") so the UI doesn't show a forest
      // of one-device cards.
      final key = _canonicalRoomKey(room);
      map.putIfAbsent(key, () => []).add(d);
    }
    
    // Sort devices within each room by canonical key for a fully stable order
    // that does NOT depend on mutable state (so toggling a device or polling
    // never reorders tiles).
    for (final list in map.values) {
      list.sort((a, b) => a.key.compareTo(b.key));
    }

    _cachedDevicesByRoom = map;
    _cachedDevicesByRoomVersion = _dataVersion;
    return map;
  }

  static String _canonicalRoomKey(String raw) {
    final n = raw.toLowerCase().trim().replaceAll(RegExp(r'[\s\-]+'), '_');

    // Outdoor / outside cluster
    if (n.contains('outdoor') ||
        n.contains('outside') ||
        n.contains('garden') ||
        n.contains('yard') ||
        n.contains('patio')) {
      if (n.contains('back')) return 'backyard';
      if (n.contains('front') && n.contains('porch')) return 'front_porch';
      return 'outdoor';
    }

    // Entry cluster
    if (n.contains('front') && (n.contains('entry') || n.contains('door'))) {
      return 'front_entry';
    }
    if (n.contains('back') && (n.contains('entry') || n.contains('door'))) {
      return 'back_entry';
    }

    // Living room (handles "motion_living", "livingroom", etc.)
    if (n.contains('living')) return 'living_room';

    // Bedroom / bath / kitchen / garage / hallway
    if (n.contains('bedroom') || n == 'bed') return 'bedroom';
    if (n.contains('bathroom') || n == 'bath') return 'bathroom';
    if (n.contains('kitchen')) return 'kitchen';
    if (n.contains('garage')) return 'garage';
    if (n.contains('hall')) return 'hallway';
    if (n.contains('office') || n.contains('study')) return 'office';

    if (n.isEmpty || n == 'unknown' || n == 'other' || n == 'misc') {
      return 'other';
    }
    return n;
  }

  List<DeviceInfo> get frequentlyAccessedDevices {
    if (_cachedFrequent != null && _cachedFrequentVersion == _dataVersion) {
      return _cachedFrequent!;
    }
    final sorted = List<DeviceInfo>.from(devices);
    sorted.sort((a, b) {
      final countA = _deviceAccessCounts[a.key] ?? 0;
      final countB = _deviceAccessCounts[b.key] ?? 0;
      final cmp = countB.compareTo(countA);
      if (cmp != 0) return cmp;
      return a.key.compareTo(b.key);
    });
    _cachedFrequent = List.unmodifiable(sorted.take(8).toList());
    _cachedFrequentVersion = _dataVersion;
    return _cachedFrequent!;
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  DashboardController() {
    _deviceService = DeviceService();
    _aiService = AIService();
    _insightsService = InsightsService();
    _integrationService = IntegrationService();
    _wsService = WebSocketService();
    _wsService.stream.listen(_handleWsMessage);
    _startPowerTracking();
  }

  void _startPowerTracking() {
    _powerTimer?.cancel();
    _powerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final next = List<double>.from(powerSpotsNotifier.value)
        ..add(totalPowerConsumption);
      if (next.length > _maxPowerSpots) next.removeAt(0);
      // Update only the sparkline notifier — do NOT call notifyListeners()
      // here, otherwise every Consumer<DashboardController> rebuilds every
      // 2 seconds and INP suffers across the app.
      powerSpotsNotifier.value = List.unmodifiable(next);
    });
  }

  @override
  void dispose() {
    _powerTimer?.cancel();
    _statusTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService.dispose();
    powerSpotsNotifier.dispose();
    super.dispose();
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
    // Bump the data version so the frequently-accessed cache rebuilds.
    _cachedFrequent = null;
    _dataVersion++;
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
      final token = prefs.getString(_kTokenKey) ?? '';

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
      final token = prefs.getString(_kTokenKey) ?? '';

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

        // Use the AI response from the transcription endpoint if available,
        // then check for n8n response, otherwise fall back to goal pipeline.
        final aiResponse = data['response'];
        final n8n = data['n8n_response'];
        if (aiResponse != null && aiResponse.toString().trim().isNotEmpty) {
          chatMessages.add(ChatMessage(
              text: aiResponse.toString(), isUser: false));
          isChatProcessing = false;
          notifyListeners();
          await fetchDevices();
        } else if (n8n != null) {
          final responseText =
              n8n['response'] ?? n8n['output'] ?? 'Command processed.';
          chatMessages
              .add(ChatMessage(text: responseText.toString(), isUser: false));
          isChatProcessing = false;
          notifyListeners();
          await fetchDevices();
        } else {
          // No AI or n8n response — send through goal pipeline
          isChatProcessing = false;
          await sendChatMessage(transcript);
        }
      } else {
        chatMessages.add(
            ChatMessage(text: 'Transcription failed. Please try again.', isUser: false));
        isChatProcessing = false;
        notifyListeners();
      }
    } catch (e, st) {
      _log.severe('sendVoiceAudio error: $e\n$st');
      chatMessages.add(ChatMessage(
          text: 'Voice processing error. Please try again.', isUser: false));
      isChatProcessing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // MQTT / WebSocket handlers
  // ---------------------------------------------------------------------------


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
      if (!_isKnownDevice(topic)) {
        if (!topic.startsWith('probes/')) {
          _log.fine('WS state_update rejected: topic=$topic key=$key');
        }
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
  bool _isKnownDevice(String topic) {
    // 1. Always allow if it's already in our canonical list from /devices
    if (_knownDeviceKeys.contains(topic)) return true;

    // 2. If it's a structured topic, check if the derived ID is known
    if (topic.startsWith('devices/') && topic.endsWith('/observed')) {
      final id = topic.split('/')[1];
      if (_knownDeviceKeys.contains(id)) return true;
    }

    // 3. In Demo Mode, allow "new" topics ONLY if they match device patterns
    // and are NOT system/probe messages.
    if (isDemoMode) {
      if (topic.startsWith('probes/')) return false;
      if (topic.endsWith('/commanded')) return false;
      
      // Allow standard device state patterns
      if (topic.startsWith('devices/') && topic.endsWith('/observed')) return true;
      if (topic.startsWith('home/') && topic.endsWith('/state')) return true;
      
      // Fallback: if it doesn't look like a device topic, reject it to prevent "phantom" devices
      return false;
    }

    return false;
  }

  /// Merge a realtime state payload into the existing device entry, updating
  /// only the 'state' sub-map rather than replacing the whole structured
  /// record that /devices returned (which also has device_id, type, name).
  void _mergeDeviceState(String topic, dynamic payload) {
    final String deviceId = _topicToDeviceKey(topic);

    // While a user-initiated toggle is in flight for this device, ignore
    // realtime state pushes for it — the backend often re-emits the
    // pre-toggle value before the change propagates, which would otherwise
    // flicker derived UI (brightness slider, status label, etc.). The
    // post-toggle fetchDevices() in toggleDevice() will reconcile state.
    if (isToggleLoading[deviceId] ?? false) return;

    final Map<String, dynamic> existing = Map.from(_rawDevices[deviceId] ?? {});
    
    if (existing.containsKey('device_id')) {
      // /devices gave us a structured record — update only its 'state' field.
      if (payload is Map) {
        _rawDevices[deviceId] = {
          ...existing,
          'state': Map<String, dynamic>.from(payload),
        };
      } else {
        _rawDevices[deviceId] = {
          ...existing,
          'state': {'state': payload, 'value': payload, 'power': payload},
        };
      }
    } else {
      // No structured record yet — store the raw payload.
      _rawDevices[deviceId] = payload;
    }
    _invalidateDeviceCaches();
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
    _log.info('DASHBOARD_INIT: Full Reset Starting...');
    isLoading = true;
    notifyListeners();

    await _loadAccessCounts();
    await _loadSettings();

    await _performFullServiceStart();
  }

  /// Internal helper to start/restart all network services without re-loading disk settings.
  Future<void> _performFullServiceStart() async {
    _log.info('_performFullServiceStart: isDemoMode=$_isDemoMode');
    isLoading = true;
    statusMessage = 'Discovering HomeGenie server...';
    notifyListeners();

    try {
      baseUrl = await ApiLocator.getBaseUrl();
      if (_authService == null) {
        _authService = AuthService(baseUrl: baseUrl);
      }
      
      statusMessage = 'Connected';

      if (_isDemoMode == false) {
        // Live mode: only fetch integrations, no demo devices
        _log.info('_performFullServiceStart: LIVE mode — fetching integrations only');
        _rawDevices = {};
        _knownDeviceKeys = {};
        deviceToggles = {};
        await fetchIntegrations();
      } else {
        // Demo mode: fetch simulated devices + insights
        _log.info('_performFullServiceStart: calling fetchDevices at $baseUrl');
        await fetchDevices();
        _log.info('_performFullServiceStart: fetchDevices complete');
        await fetchInsights();
      }

      // Manage subscription to avoid duplicates
      await _wsSubscription?.cancel();
      _wsSubscription = _wsService.connectionStateStream.listen((c) {
        wsConnected = c;
        _scheduleNotify();
      });

      // WebSocket: connect in both modes (Live will use it for real device updates)
      await _wsService.connect(baseUrl: baseUrl);

      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(
          const Duration(seconds: 10), (_) => _checkConnection());
    } catch (e) {
      statusMessage = 'Discovery failed: $e';
      _log.warning(statusMessage);
    } finally {
      isLoading = false;
      _scheduleNotify();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_kModeKey)) {
        _isDemoMode = prefs.getBool(_kModeKey);
      }
      
      if (prefs.containsKey(_kTokenKey)) {
        _token = prefs.getString(_kTokenKey);
        _isLoggedIn = _token != null;
        
        if (prefs.containsKey(_kUserKey)) {
          final userJson = prefs.getString(_kUserKey);
          if (userJson != null) {
            _currentUser = User.fromJson(userJson);
          }
        }
      }
      _log.info('Settings loaded: isDemoMode=$_isDemoMode, isLoggedIn=$_isLoggedIn');
    } catch (e) {
      _log.warning('Failed to load settings: $e');
    }
  }

  Future<void> setMode(bool isDemo) async {
    _isDemoMode = isDemo;

    // Both modes need backend services running.
    // Clear stale data before reconnecting to avoid mixing modes.
    _rawDevices = {};
    _knownDeviceKeys = {};
    deviceToggles = {};
    _invalidateDeviceCaches();
    _devicesEtag = null;
    _wsService.disconnect();
    _statusTimer?.cancel();
    _statusTimer = null;

    _log.info('Switching to ${isDemo ? "DEMO" : "LIVE"} mode: starting services');
    unawaited(_performFullServiceStart());

    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kModeKey, isDemo);
      _log.info('Mode updated to: ${isDemo ? "DEMO" : "LIVE"}');
    } catch (e) {
      _log.warning('Failed to save mode: $e');
    }
  }

  Future<void> setManualServerUrl(String url) async {
    _log.info('Setting manual server URL: $url');
    await ApiLocator.setManualOverride(url);
    baseUrl = url;
    
    // Clear state data before reconnecting to the new server
    _rawDevices = {};
    _knownDeviceKeys = {};
    deviceToggles = {};
    _invalidateDeviceCaches();
    _devicesEtag = null;
    
    // Refresh the auth service with the new base URL if needed
    _authService = AuthService(baseUrl: baseUrl);
    
    // Disconnect existing socket to force reconnect to new IP
    _wsService.disconnect();
    
    _scheduleNotify();
    
    // Trigger a full start to validate and fetch data from the new IP
    await _performFullServiceStart();
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
      _scheduleNotify();
      return;
    }
    final ok = await ApiLocator.testUrl(baseUrl);
    connectionStatus =
        ok ? ConnectionStatus.connected : ConnectionStatus.disconnected;
    _scheduleNotify();
  }

  Future<void> fetchDevices({int retryCount = 0}) async {
    if (isProcessingGoal || baseUrl.isEmpty) return;
    
    // Only set isLoading on first attempt
    if (retryCount == 0) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(_kTokenKey) ?? '';
      final resp = await _deviceService.fetchDevices(baseUrl, _devicesEtag, token: authToken);

      // 304 Not Modified — nothing changed on the server.
      if (resp.statusCode == 304) {
        _log.fine('FETCH_DEVICES: 304 Not Modified, skipping');
        isLoading = false;
        _scheduleNotify();
        return;
      }

      _log.info('FETCH_DEVICES: count=$retryCount status=${resp.statusCode}, len=${resp.body.length}');
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

        // Replace _rawDevices with the authoritative /devices payload, with
        // keys inserted in sorted order so any consumer that iterates the
        // map directly sees a stable, deterministic device order across
        // refreshes (independent of however the backend ordered the JSON).
        final sortedKeys = incoming.keys.toList()..sort();
        _rawDevices = {
          for (final k in sortedKeys) k: incoming[k],
        };
        _invalidateDeviceCaches();

        final items = _rawDevices.length;
        _log.info('FETCH_DEVICES: success, items=$items');

        // IF items = 0 and we are early in the boot, wait and retry.
        // This handles the race where the backend is up but probes haven't 
        // finished yet.
        if (items == 0 && retryCount < 3) {
           _log.info('FETCH_DEVICES: 0 items, retrying in 2.5s (attempt ${retryCount + 1})...');
           await Future.delayed(Duration(milliseconds: (2500 + (retryCount * 1000))));
           return fetchDevices(retryCount: retryCount + 1);
        }

        _rawDevices.forEach((key, value) {
          if (!(isToggleLoading[key] ?? false)) _syncToggle(key, value);
        });
        
        statusMessage = 'Updated at ${DateTime.now().toString().substring(11, 19)}';
        if (items == 0 && retryCount >= 3) {
          statusMessage = 'No devices found after retries.';
        }
      }
    } catch (e) {
      _log.warning('Failed to fetch devices: $e');
    } finally {
      isLoading = false;
      _scheduleNotify();
    }
  }

  Future<void> fetchInsights() async {
    if (baseUrl.isEmpty) return;
    isInsightsLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(_kTokenKey) ?? '';
      final results = await _insightsService.fetchInsightsData(baseUrl, token: authToken);

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

  Future<void> fetchEnergyData({int days = 1}) async {
    if (baseUrl.isEmpty) return;
    isHistoryLoading = true;
    currentHistoryDays = days;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(_kTokenKey) ?? '';
      final resp = await _deviceService.fetchEnergyHistory(baseUrl, days: days, token: authToken);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        energyHistory = List<Map<String, dynamic>>.from(data['history'] ?? []);
      }

      final resp2 = await _deviceService.fetchDeviceBreakdown(baseUrl, days: days, token: authToken);
      if (resp2.statusCode == 200) {
        final data2 = json.decode(resp2.body);
        energyBreakdown = List<Map<String, dynamic>>.from(data2['breakdown'] ?? []);
      }
      _log.info('Fetched ${energyHistory.length} history points, ${energyBreakdown.length} breakdown items');
    } catch (e) {
      _log.warning('Failed to fetch energy data: $e');
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRules() async {
    if (baseUrl.isEmpty) return;
    isRulesLoading = true;
    notifyListeners();
    try {
      final key = _token ?? '';
      final resp = await http.get(
        Uri.parse('$baseUrl/rules'),
        headers: {
          'Content-Type': 'application/json',
          if (key.isNotEmpty) 'X-HomeGenie-Token': key,
        },
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        rules = List<Map<String, dynamic>>.from(data['rules'] ?? []);
      }
    } catch (e) {
      _log.warning('Failed to fetch rules: $e');
    } finally {
      isRulesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveRule(Map<String, dynamic> ruleData) async {
    if (baseUrl.isEmpty) return false;
    try {
      final key = _token ?? '';
      final resp = await http.post(
        Uri.parse('$baseUrl/rules'),
        headers: {
          'Content-Type': 'application/json',
          if (key.isNotEmpty) 'X-HomeGenie-Token': key,
        },
        body: json.encode(ruleData),
      );
      if (resp.statusCode == 200) {
        await fetchRules();
        return true;
      }
    } catch (e) {
      _log.warning('Failed to save rule: $e');
    }
    return false;
  }

  Future<bool> deleteRule(int ruleId) async {
    if (baseUrl.isEmpty) return false;
    try {
      final key = _token ?? '';
      final resp = await http.delete(
        Uri.parse('$baseUrl/rules/$ruleId'),
        headers: {
          'Content-Type': 'application/json',
          if (key.isNotEmpty) 'X-HomeGenie-Token': key,
        },
      );
      if (resp.statusCode == 200) {
        await fetchRules();
        return true;
      }
    } catch (e) {
      _log.warning('Failed to delete rule: $e');
    }
    return false;
  }

  Future<void> sendGoal(String message, {bool silent = false}) async {
    logActivity('Simulation: $message');
    if (!silent) {
      isProcessingGoal = true;
      statusMessage = 'AI is thinking...';
      notifyListeners();
    }
    try {
      final url = await ApiLocator.getBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kTokenKey) ?? '';
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
      if (!silent) {
        isProcessingGoal = false;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
        await fetchDevices();
      } else {
        // Silent updates just fetch once immediately to confirm
        unawaited(fetchDevices());
      }
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
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(_kTokenKey) ?? '';
      await _deviceService.toggleDevice(baseUrl, device.key, action, token: authToken);
      await _incrementAccessCount(device.key);
    } catch (e) {
      _log.warning('Failed to toggle device ${device.key}: $e');
      deviceToggles[device.key] = current;
    } finally {
      // Keep isToggleLoading=true across the refresh so _syncToggle won't
      // clobber our optimistic state with a stale server snapshot (the
      // backend may not have propagated the change yet). Clearing it AFTER
      // the refresh prevents the tile from flickering back to its previous
      // state and then forward again.
      try {
        await fetchDevices();
      } finally {
        isToggleLoading[device.key] = false;
        _scheduleNotify();
      }
    }
  }

  Future<void> updateDeviceValue(DeviceInfo device, String attribute, dynamic value) async {
    // 1. Optimistic update for immediate UI feedback
    final currentRaw = _rawDevices[device.key];
    if (currentRaw != null) {
      final Map<String, dynamic> updated = Map.from(currentRaw);
      final state = Map<String, dynamic>.from(updated['state'] ?? {});
      state[attribute] = value;
      
      if (attribute == 'brightness' && (value as num) > 0) {
        state['power'] = 'on';
        state['state'] = 'on';
      }
      
      updated['state'] = state;
      _rawDevices[device.key] = updated;
      _invalidateDeviceCaches();
      _syncToggle(device.key, updated);

      // Notify listeners immediately for local UI responsiveness
      notifyListeners();
    }

    // 2. Debounce the backend update to prevent clogging
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        if (baseUrl.isEmpty) return;
        final command = 'Set ${attribute} of ${device.name} to ${value}';
        await sendGoal(command, silent: true);
      } catch (e) {
        _log.warning('Failed to update device value: $e');
      }
    });
  }

  Future<void> fetchIntegrations() async {
    if (baseUrl.isEmpty) return;
    isIntegrationsLoading = true;
    _scheduleNotify();
    try {
      integrations = await _integrationService.fetchIntegrations(baseUrl);
    } catch (e) {
      _log.warning('Failed to fetch integrations: $e');
      // Fall back to default scaffold list
      integrations = PlatformIntegration.defaults();
    } finally {
      isIntegrationsLoading = false;
      _scheduleNotify();
    }
  }

  Future<bool> setupIntegration(String platformId, Map<String, dynamic> config) async {
    if (baseUrl.isEmpty) return false;
    try {
      final success = await _integrationService.setupPlatform(baseUrl, platformId, config);
      if (success) await fetchIntegrations();
      return success;
    } catch (e) {
      _log.warning('Failed to setup integration $platformId: $e');
      return false;
    }
  }

}
