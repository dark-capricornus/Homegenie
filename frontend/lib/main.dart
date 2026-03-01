import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:homegenie_app/screens/server_settings.dart';
import 'package:homegenie_app/network/mqtt_service.dart';

enum ConnectionStatus { unknown, connected, disconnected }

final Logger _logger = Logger('HomeGenieApp');

void main() {
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
  });
  
  runApp(const HomeGenieApp());
}

class HomeGenieApp extends StatelessWidget {
  const HomeGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeGenie Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeControlScreen(),
    );
  }
}

class HomeControlScreen extends StatefulWidget {
  const HomeControlScreen({super.key});

  @override
  State<HomeControlScreen> createState() => _HomeControlScreenState();
}

class _HomeControlScreenState extends State<HomeControlScreen> {
  String baseUrl = '';
  static const String userId = 'mobile_user_001';
  
  Map<String, dynamic> deviceStates = {};
  Map<String, bool> deviceToggles = {}; // Track local toggle states
  Map<String, bool> isToggleLoading = {}; // Track loading state per device
  bool isLoading = false;
  bool isProcessingGoal = false;
  String statusMessage = '';
  Timer? _refreshTimer;
  Timer? _statusTimer;
  DateTime? _lastStatusCheck;
  ConnectionStatus connectionStatus = ConnectionStatus.unknown;
  MqttService? _mqttService;
  bool _mqttConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeBaseUrl();
    // Don't start auto-refresh until API discovery is complete
  }
  
  Future<void> _initializeBaseUrl() async {
    // Use ApiLocator (handles cached, override, emulator, LAN scan, cloud)
    _logger.info('Initializing API discovery via ApiLocator...');
    setState(() {
      statusMessage = 'Discovering HomeGenie server...';
      isLoading = true;
    });

    try {
      final found = await ApiLocator.getBaseUrl();
      baseUrl = found;
      _logger.info('HomeGenie API URL (ApiLocator): $baseUrl');
      setState(() {
        statusMessage = 'Connected to HomeGenie server';
      });

      await _fetchDeviceStates();
      _startAutoRefresh();
      _startStatusTicker();
      // Start MQTT connection using universal selection logic in MqttService
      _mqttService = MqttService();
      await _mqttService!.connect();
      _mqttService!.connectedStream.listen((connected) {
        setState(() {
          _mqttConnected = connected;
        });
      });
    } catch (e) {
      _logger.warning('ApiLocator discovery failed: $e');
      setState(() {
        statusMessage = 'Could not find HomeGenie server';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusTicker() {
    // Do not check more often than once every 10 seconds
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkConnection();
    });
    // Kick off an immediate check
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    // Throttle checks using last check timestamp
    final now = DateTime.now();
    if (_lastStatusCheck != null && now.difference(_lastStatusCheck!).inSeconds < 10) return;
    _lastStatusCheck = now;

    if (baseUrl.isEmpty) {
      setState(() => connectionStatus = ConnectionStatus.disconnected);
      return;
    }

    final ok = await ApiLocator.testUrl(baseUrl);
    setState(() {
      connectionStatus = ok ? ConnectionStatus.connected : ConnectionStatus.disconnected;
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Only start auto-refresh after successful discovery
      if (baseUrl.isNotEmpty && (!baseUrl.contains('localhost') || kIsWeb)) {
        _fetchDeviceStates();
      }
    });
  }

  Future<void> _fetchDeviceStates() async {
    if (isProcessingGoal) return; // Skip refresh while processing goals
    
    // Check if baseUrl is properly set
    if (baseUrl.isEmpty) {
      _logger.warning('BaseURL not set, skipping fetch...');
      return;
    }
    
    // For mobile, ensure we're not using the default localhost
    if (!kIsWeb && baseUrl == 'http://localhost:8000') {
      _logger.warning('Using localhost on mobile - API discovery may not be complete yet');
      return;
    }
    
    setState(() {
      isLoading = true;
    });

    try {
              _logger.info('Fetching devices from: $baseUrl/devices'); // Debug info
      final response = await http.get(
        Uri.parse('$baseUrl/devices'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _logger.info('Response status: ${response.statusCode}');
      _logger.fine('Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        _logger.fine('API response keys: ${data.keys.toList()}');
        
        // Check if response has 'devices' key or devices are at top level
        Map<String, dynamic> devices;
        if (data.containsKey('devices')) {
          devices = data['devices'] as Map<String, dynamic>;
          _logger.info('Found devices in "devices" key: ${devices.length} devices');
        } else {
          devices = data;
          _logger.info('Devices at top level: ${devices.length} devices');
        }
        
        setState(() {
          deviceStates = devices;
          
          _logger.info('Loaded ${deviceStates.length} devices');
          
          // Sync local toggle states with server state (only if not currently loading)
          deviceStates.forEach((key, value) {
            if (!(isToggleLoading[key] ?? false)) {
              final deviceData = value as Map<String, dynamic>? ?? {};
              final state = deviceData['state'] as Map<String, dynamic>? ?? {};
              
              _logger.fine('Device $key state: $state');
              
              if (key.contains('light_sensor')) {
                final isDark = state['is_dark'] ?? false;
                deviceToggles[key] = !isDark;
              } else if (key.contains('light') || key.contains('switch')) {
                final isOn = state['power']?.toString().toLowerCase() == 'on' || 
                            state['state']?.toString().toLowerCase() == 'on' ||
                            state['status']?.toString().toLowerCase() == 'on';
                deviceToggles[key] = isOn;
                _logger.fine('Device $key toggle state: $isOn');
              }
            }
          });
          
          statusMessage = deviceStates.isEmpty 
              ? 'No devices found' 
              : 'Updated at ${DateTime.now().toString().substring(11, 19)}';
        });
      } else {
        setState(() {
          statusMessage = 'API Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      _logger.warning('Exception occurred: $e');
      setState(() {
        statusMessage = 'Connection failed: Cannot reach API at $baseUrl';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendToN8n(String message) async {
    setState(() {
      isProcessingGoal = true;
      statusMessage = 'Sending command to AI Orchestrator...';
    });

    try {
      final apiUrl = await ApiLocator.getBaseUrl();
      final n8nWebhookUrl = '$apiUrl/chat/n8n';
      
      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-HomeGenie-Token': 'homegenie_dev_token_123',
        },
        body: json.encode({'message': message}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          statusMessage = 'Command executed via n8n Orchestrator!';
        });
        // Wait a moment then refresh the states
        await Future.delayed(const Duration(seconds: 2));
        await _fetchDeviceStates();
      } else {
        setState(() {
          statusMessage = 'Failed to execute via n8n: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error connecting to n8n webhook: $e';
      });
    } finally {
      setState(() {
        isProcessingGoal = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Clean Modern App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF2196F3),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Row(
                children: [
                  Icon(Icons.home, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'HomeGenie',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2196F3),
                      Color(0xFF1976D2),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showVoiceControlDialog(),
                icon: const Icon(Icons.chat, color: Colors.white),
                tooltip: 'Chat with n8n AI',
              ),
              IconButton(
                onPressed: () async {
                  // Open server settings and refresh discovery on return
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServerSettingsScreen()));
                  final newBase = await ApiLocator.getBaseUrl();
                  setState(() {
                    baseUrl = newBase;
                  });
                  await _fetchDeviceStates();
                  // Reconnect MQTT to pick up any manual overrides
                  try {
                    await _mqttService?.connect();
                  } catch (e) {
                    _logger.warning('MQTT reconnect after settings failed: $e');
                  }
                },
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: 'Server Settings',
              ),
              IconButton(
                onPressed: _fetchDeviceStates,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Simple Status Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isProcessingGoal ? Icons.sync : Icons.check_circle,
                    size: 20,
                    color: isProcessingGoal ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusMessage.isEmpty ? 'System Status: Online' : statusMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: connectionStatus == ConnectionStatus.connected
                                    ? Colors.green
                                    : (connectionStatus == ConnectionStatus.unknown ? Colors.orange : Colors.red),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'API: $baseUrl',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Small MQTT status indicator
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _mqttConnected ? Colors.green : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (deviceStates.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${deviceStates.length} devices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickActionsSection(),
            ),
          ),

          // Main Content - Masonry Layout
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            sliver: deviceStates.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to HomeGenie',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect your devices to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildMasonryGrid(),
          ),
        ],
      ),
    );
  }

  // Voice Control / Audio Record Dialog
  void _showVoiceControlDialog() {
    final record = AudioRecorder();
    bool isRecording = false;
    bool isTranscribing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            Future<void> stopRecording() async {
              setStateBuilder(() => isRecording = false);
              setStateBuilder(() => isTranscribing = true);
              try {
                final path = await record.stop();
                if (path != null) {
                  // Fetch the audio bytes from the blob URL or local path
                  final uri = Uri.parse(path);
                  var response = await http.get(uri);
                  var audioBytes = response.bodyBytes;
                  
                  // Send to python backend transcriber wrapper
                  final apiUrl = await ApiLocator.getBaseUrl();
                  var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/voice/transcribe'));
                  request.headers['X-HomeGenie-Token'] = 'homegenie_dev_token_123';
                  request.files.add(http.MultipartFile.fromBytes('file', audioBytes, filename: 'audio.webm'));
                  
                  final streamedResponse = await request.send();
                  final res = await http.Response.fromStream(streamedResponse);
                  
                  if (res.statusCode >= 200 && res.statusCode < 300) {
                     setState(() {
                       statusMessage = "Voice command executed via Agent Orchestrator!";
                     });
                     // Refresh
                     await Future.delayed(const Duration(seconds: 2));
                     await _fetchDeviceStates();
                  } else {
                     setState(() {
                       statusMessage = "Voice Transcription failed: ${res.statusCode}";
                     });
                  }
                }
              } catch (e) {
                _logger.severe('Voice upload error: $e');
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              record.dispose();
            }

            Future<void> startRecording() async {
              if (await record.hasPermission()) {
                await record.start(RecordConfig(encoder: AudioEncoder.opus), path: '');
                setStateBuilder(() => isRecording = true);
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.mic, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Agentic Voice Command'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isTranscribing 
                    ? const CircularProgressIndicator()
                    : IconButton(
                        iconSize: 64,
                        color: isRecording ? Colors.red : Colors.blue,
                        icon: Icon(isRecording ? Icons.stop_circle : Icons.mic),
                        onPressed: isRecording ? stopRecording : startRecording,
                      ),
                  const SizedBox(height: 16),
                  Text(isTranscribing ? 'Transcribing & routing via n8n...' : (isRecording ? 'Listening...' : 'Tap Mic to speak to HomeGenie')),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isTranscribing ? null : () {
                    if (isRecording) record.stop();
                    record.dispose();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Clean Quick Actions Section
  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFF2196F3), size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Make it Cozy',
                  Icons.home,
                  Colors.orange,
                  () => _sendToN8n('make it cozy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  'Save Energy',
                  Icons.eco,
                  Colors.green,
                  () => _sendToN8n('save energy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  'Goodnight',
                  Icons.bedtime,
                  Colors.indigo,
                  () => _sendToN8n('goodnight'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Masonry Grid Layout
  Widget _buildMasonryGrid() {
    final devices = _getDevicesList();
    
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          int columns = 2;
          
          if (screenWidth > 1200) {
            columns = 4;
          } else if (screenWidth > 800) {
            columns = 3;
          } else if (screenWidth > 600) {
            columns = 2;
          } else {
            columns = 1;
          }
          
          final columnWidth = (screenWidth - (16 * (columns - 1))) / columns;
          
          // Create masonry columns
          List<List<Widget>> columnItems = List.generate(columns, (_) => []);
          List<double> columnHeights = List.generate(columns, (_) => 0.0);
          
          for (int i = 0; i < devices.length; i++) {
            final device = devices[i];
            int shortestColumn = 0;
            for (int j = 1; j < columnHeights.length; j++) {
              if (columnHeights[j] < columnHeights[shortestColumn]) {
                shortestColumn = j;
              }
            }
            
            final cardHeight = _getCardHeight(device);
            columnItems[shortestColumn].add(_buildMasonryCard(device, columnWidth));
            columnHeights[shortestColumn] += cardHeight + 16;
          }
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnItems.asMap().entries.map((entry) {
              final columnIndex = entry.key;
              final column = entry.value;
              
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: columnIndex == 0 ? 0 : 8,
                    right: columnIndex == columnItems.length - 1 ? 0 : 8,
                  ),
                  child: Column(
                    children: column.map((widget) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: widget,
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  double _getCardHeight(DeviceInfo device) {
    // Vary card heights based on device type for visual interest
    switch (device.type) {
      case 'light':
        return 120.0;
      case 'thermostat':
        return 180.0;
      case 'sensor':
        return 140.0;
      case 'lock':
        return 100.0;
      case 'media':
        return 160.0;
      case 'switch':
        return 110.0;
      default:
        return 120.0;
    }
  }

  Widget _buildMasonryCard(DeviceInfo device, double width) {
    final data = device.data;
    final state = data['state'] as Map<String, dynamic>? ?? {};
    final isLoading = isToggleLoading[device.key] ?? false;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with device icon and name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getDeviceColor(device.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDeviceIconData(device.type),
                  color: _getDeviceColor(device.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Device content based on type
          _buildMasonryCardContent(device, state, isLoading),
        ],
      ),
    );
  }

  Widget _buildMasonryCardContent(DeviceInfo device, Map<String, dynamic> state, bool isLoading) {
    switch (device.type) {
      case 'thermostat':
        final temp = (state['temperature'] ?? 20).toDouble();
        final target = (state['target_temperature'] ?? 20).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '${temp.toInt()}°C',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Target: ${target.toInt()}°C',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Icon(
                  temp > target ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: temp > target ? Colors.blue : Colors.red,
                  size: 20,
                ),
              ],
            ),
          ],
        );
      
      case 'sensor':
        if (device.key.contains('light_sensor')) {
          final value = state['value'] ?? 0;
          final isDark = state['is_dark'] ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Light Level',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '$value lux',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.indigo.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDark ? 'Dark' : 'Bright',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.indigo.shade700 : Colors.amber.shade700,
                  ),
                ),
              ),
            ],
          );
        } else {
          final value = state['value'] ?? 0;
          final unit = state['unit'] ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.type.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '$value $unit'.trim(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          );
        }
      
      default:
        // For lights, locks, media, etc.
        final canToggle = _canToggleDevice(device);
        final isOn = _getDeviceState(device);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOn ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOn ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const Spacer(),
                if (canToggle)
                  Switch(
                    value: isOn,
                    onChanged: isLoading ? null : (value) => _toggleDevice(device),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (device.type == 'light' && isOn) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final brightness = (state['brightness'] ?? 0).toInt();
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: brightness / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$brightness% brightness',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
    }
  }

  Color _getDeviceColor(String deviceType) {
    switch (deviceType) {
      case 'light':
        return Colors.amber.shade600;
      case 'thermostat':
        return Colors.red.shade600;
      case 'lock':
        return Colors.brown.shade600;
      case 'media':
        return Colors.purple.shade600;
      case 'sensor':
        return Colors.green.shade600;
      case 'switch':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getDeviceIconData(String deviceType) {
    switch (deviceType) {
      case 'light':
        return Icons.lightbulb;
      case 'thermostat':
        return Icons.thermostat;
      case 'lock':
        return Icons.lock;
      case 'media':
        return Icons.music_note;
      case 'sensor':
        return Icons.sensors;
      case 'switch':
        return Icons.power_settings_new;
      default:
        return Icons.device_unknown;
    }
  }

  bool _canToggleDevice(DeviceInfo device) {
    return ['light', 'lock', 'media', 'switch'].contains(device.type);
  }

  bool _getDeviceState(DeviceInfo device) {
    final data = device.data;
    final state = data['state'] as Map<String, dynamic>? ?? {};
    
    // Check toggle state first (for immediate UI feedback)
    if (deviceToggles.containsKey(device.key)) {
      return deviceToggles[device.key]!;
    }
    
    // Fall back to server state
    switch (device.type) {
      case 'light':
        return state['power']?.toString().toLowerCase() == 'on' || 
               state['state']?.toString().toLowerCase() == 'on';
      case 'lock':
        return state['locked']?.toString().toLowerCase() == 'true';
      case 'media':
        return state['playing']?.toString().toLowerCase() == 'true';
      case 'switch':
        return state['power']?.toString().toLowerCase() == 'on' || 
               state['state']?.toString().toLowerCase() == 'on' ||
               state['enabled']?.toString().toLowerCase() == 'true';
      default:
        return false;
    }
  }

  Future<void> _toggleDevice(DeviceInfo device) async {
    final currentState = _getDeviceState(device);
    final newState = !currentState;
    
    // Immediate UI feedback
    setState(() {
      deviceToggles[device.key] = newState;
      isToggleLoading[device.key] = true;
    });
    
    switch (device.type) {
      case 'light':
        await _toggleLight(device.key, newState);
        break;
      case 'lock':
        await _toggleLock(device.key, newState);
        break;
      case 'media':
        await _toggleMedia(device.key, newState);
        break;
      case 'switch':
        await _toggleSwitch(device.key, newState);
        break;
    }
    
    setState(() {
      isToggleLoading[device.key] = false;
    });
  }

  // Build quick action button
  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: isProcessingGoal ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  // Get formatted device list
  List<DeviceInfo> _getDevicesList() {
    return deviceStates.entries.map((entry) {
      return DeviceInfo(
        key: entry.key,
        data: entry.value,
        name: _formatDeviceName(entry.key),
        type: _getDeviceType(entry.key),
      );
    }).toList();
  }

  // Get device type from key
  String _getDeviceType(String deviceKey) {
    if (deviceKey.contains('light') && !deviceKey.contains('sensor')) {
      return 'light';
    }
    if (deviceKey.contains('thermostat')) {
      return 'thermostat';
    }
    if (deviceKey.contains('lock')) {
      return 'lock';
    }
    if (deviceKey.contains('media')) {
      return 'media';
    }
    if (deviceKey.contains('fan') || deviceKey.contains('outlet') || deviceKey.contains('switch')) {
      return 'switch';
    }
    if (deviceKey.contains('temperature') || deviceKey.contains('motion') || deviceKey.contains('sensor') || 
        deviceKey.contains('humidity') || deviceKey.contains('door') || deviceKey.contains('window') ||
        deviceKey.contains('air_quality')) {
      return 'sensor';
    }
    return 'unknown';
  }





  // Format device name to be user-friendly
  String _formatDeviceName(String deviceKey) {
    // Handle dot-separated format (e.g., "living_room.temperature", "light.bedroom")
    final parts = deviceKey.split('.');
    
    if (parts.isEmpty) return 'Unknown Device';
    
    String location = '';
    String deviceType = '';
    
    if (parts.length == 2) {
      // Format: "location.type" or "type.location"
      final first = parts[0];
      final second = parts[1];
      
      // Determine which is location and which is device type
      if (_isLocationName(first)) {
        location = _formatLocationName(first);
        deviceType = _formatDeviceType(second);
      } else if (_isLocationName(second)) {
        location = _formatLocationName(second);
        deviceType = _formatDeviceType(first);
      } else {
        // If unclear, use first as location, second as type
        location = _formatLocationName(first);
        deviceType = _formatDeviceType(second);
      }
    } else {
      // Single part - treat as device type
      deviceType = _formatDeviceType(deviceKey);
    }
    
    // Combine location and device type intelligently
    if (location.isNotEmpty && deviceType.isNotEmpty) {
      // Special cases for better naming
      if (deviceType.toLowerCase().contains('temperature')) {
        return '$location Temperature';
      } else if (deviceType.toLowerCase().contains('motion')) {
        return '$location Motion Sensor';
      } else if (deviceType.toLowerCase().contains('light') && deviceType.toLowerCase().contains('sensor')) {
        return '$location Light Sensor';
      } else if (deviceType.toLowerCase().contains('thermostat')) {
        return '$location Thermostat';
      } else if (deviceType.toLowerCase().contains('lock')) {
        return '$location Lock';
      } else if (deviceType.toLowerCase().contains('light')) {
        return '$location Light';
      } else {
        return '$location $deviceType';
      }
    } else if (location.isNotEmpty) {
      return location;
    } else if (deviceType.isNotEmpty) {
      return deviceType;
    }
    
    return 'Unknown Device';
  }
  
  // Helper to identify if a string is likely a location name
  bool _isLocationName(String name) {
    final locationWords = {
      'living', 'bedroom', 'kitchen', 'bathroom', 'garage', 'office', 
      'dining', 'hallway', 'basement', 'attic', 'outdoor', 'front', 
      'back', 'main', 'master', 'guest', 'room'
    };
    return locationWords.any((word) => name.toLowerCase().contains(word));
  }
  
  // Helper to format location names
  String _formatLocationName(String location) {
    return location
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          // Special location formatting
          if (word.toLowerCase() == 'living') return 'Living';
          if (word.toLowerCase() == 'room') return 'Room';
          if (word.toLowerCase() == 'front') return 'Front';
          if (word.toLowerCase() == 'door') return 'Door';
          if (word.toLowerCase() == 'main') return 'Main';
          if (word.toLowerCase() == 'master') return 'Master';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
  
  // Helper to format device type names
  String _formatDeviceType(String deviceType) {
    return deviceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          // Special device type formatting
          if (word.toLowerCase() == 'temp' || word.toLowerCase() == 'temperature') return 'Temperature';
          if (word.toLowerCase() == 'light') return 'Light';
          if (word.toLowerCase() == 'sensor') return 'Sensor';
          if (word.toLowerCase() == 'motion') return 'Motion';
          if (word.toLowerCase() == 'thermostat') return 'Thermostat';
          if (word.toLowerCase() == 'lock') return 'Lock';
          if (word.toLowerCase() == 'tv') return 'TV';
          if (word.toLowerCase() == 'co2') return 'CO2';
          if (word.toLowerCase() == 'pm25') return 'PM2.5';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }





  // Device control actions
  Future<void> _toggleLight(String deviceKey, bool turnOn) async {
    // Publish MQTT set message first (best-effort), then fallback to HTTP
    final parts = deviceKey.split('.');
    final deviceType = parts.isNotEmpty ? parts[0] : 'light';
    final location = parts.length > 1 ? parts[1] : deviceKey;

    final payload = json.encode({'state': turnOn ? 'on' : 'off'});
    final topic = 'home/$deviceType/$location/set';

    // Optimistic UI update
    setState(() {
      deviceToggles[deviceKey] = turnOn;
      isToggleLoading[deviceKey] = true;
    });

    await _sendDeviceCommand(
      deviceKey,
      {
        'action': turnOn ? 'turn_on' : 'turn_off',
        'brightness': turnOn ? 80 : 0,
      },
      mqttTopic: topic,
      mqttPayload: payload,
    );

    setState(() {
      isToggleLoading[deviceKey] = false;
    });
  }

  Future<void> _toggleLock(String deviceKey, bool lock) async {
    final parts = deviceKey.split('.');
    final deviceType = parts.isNotEmpty ? parts[0] : 'lock';
    final location = parts.length > 1 ? parts[1] : deviceKey;

    final payload = json.encode({'locked': lock});
    final topic = 'home/$deviceType/$location/set';

    setState(() {
      deviceToggles[deviceKey] = lock;
      isToggleLoading[deviceKey] = true;
    });

    await _sendDeviceCommand(
      deviceKey,
      {
        'action': lock ? 'lock' : 'unlock',
      },
      mqttTopic: topic,
      mqttPayload: payload,
    );

    setState(() {
      isToggleLoading[deviceKey] = false;
    });
  }

  Future<void> _toggleMedia(String deviceKey, bool play) async {
    await _sendDeviceCommand(deviceKey, {
      'action': play ? 'play' : 'pause',
    });
  }

  Future<void> _toggleSwitch(String deviceKey, bool turnOn) async {
    final parts = deviceKey.split('.');
    final deviceType = parts.isNotEmpty ? parts[0] : 'switch';
    final location = parts.length > 1 ? parts[1] : deviceKey;

    final payload = json.encode({'state': turnOn ? 'on' : 'off'});
    final topic = 'home/$deviceType/$location/set';

    setState(() {
      deviceToggles[deviceKey] = turnOn;
      isToggleLoading[deviceKey] = true;
    });

    await _sendDeviceCommand(
      deviceKey,
      {
        'action': turnOn ? 'turn_on' : 'turn_off',
      },
      mqttTopic: topic,
      mqttPayload: payload,
    );

    setState(() {
      isToggleLoading[deviceKey] = false;
    });
  }



  Future<void> _sendDeviceCommand(String deviceKey, Map<String, dynamic> command,
      {String? mqttTopic, String? mqttPayload}) async {
    // Optimistic update already applied by caller. Try MQTT first, then HTTP fallback.
    final deviceId = deviceKey;
    final prevToggle = deviceToggles.containsKey(deviceKey) ? deviceToggles[deviceKey] : null;

    bool mqttOk = false;
    bool httpOk = false;

    try {
      // Attempt MQTT publish if topic/payload provided
      if (mqttTopic != null && mqttPayload != null && _mqttService != null) {
        try {
          mqttOk = await _mqttService!.publish(mqttTopic, mqttPayload);
        } catch (e) {
          mqttOk = false;
          _logger.fine('MQTT publish error for $mqttTopic: $e');
        }
      }

      // Always send HTTP fallback in parallel (don't wait for MQTT success)
      try {
        final resp = await http
            .post(
          Uri.parse('$baseUrl/devices/${Uri.encodeComponent(deviceId)}/command'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'device_id': deviceId,
            'action': command['action'] ?? 'set',
            'parameters': command,
            'user_id': userId,
          }),
        )
            .timeout(const Duration(seconds: 5));

        if (resp.statusCode == 200) {
          httpOk = true;
        } else {
          httpOk = false;
          _logger.warning('HTTP fallback failed: ${resp.statusCode}');
        }
      } catch (e) {
        httpOk = false;
        _logger.fine('HTTP fallback error: $e');
      }

      if (mqttOk || httpOk) {
        // Success via at least one channel. Refresh authoritative state shortly.
        setState(() {
          statusMessage = 'Device update sent';
        });
        await Future.delayed(const Duration(milliseconds: 300));
        await _fetchDeviceStates();
      } else {
        // Both failed, revert optimistic UI
        setState(() {
          if (prevToggle == null) {
            deviceToggles.remove(deviceKey);
          } else {
            deviceToggles[deviceKey] = prevToggle;
          }
          statusMessage = 'Failed to update device (no MQTT or HTTP)';
        });
      }
    } catch (e) {
      // Unexpected error - revert optimistic UI
      setState(() {
        if (prevToggle == null) {
          deviceToggles.remove(deviceKey);
        } else {
          deviceToggles[deviceKey] = prevToggle;
        }
        statusMessage = 'Error sending device command';
      });
      _logger.warning('Error sending device command: $e');
    } finally {
      setState(() {
        isToggleLoading[deviceKey] = false;
      });
    }
  }


}

// Device info model
class DeviceInfo {
  final String key;
  final Map<String, dynamic> data;
  final String name;
  final String type;

  DeviceInfo({
    required this.key,
    required this.data,
    required this.name,
    required this.type,
  });
}