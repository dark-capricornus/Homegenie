import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeBaseUrl();
    // Don't start auto-refresh until API discovery is complete
  }
  
  void _initializeBaseUrl() {
    // Detect if running on mobile device
    const isWeb = kIsWeb;
    
    if (isWeb) {
      // Web version - use localhost
      baseUrl = 'http://localhost:8000';
      _logger.info('Flutter running on: Web');
      _logger.info('HomeGenie API URL: $baseUrl');
      _fetchDeviceStates();
      _startAutoRefresh(); // Start auto-refresh for web
    } else {
      // Mobile version - discover API server dynamically
      _logger.info('Flutter running on: Mobile - discovering API server...');
      _discoverApiServer();
    }
  }

    // Dynamic API server discovery for mobile devices
  Future<void> _discoverApiServer() async {
    setState(() {
      statusMessage = 'Discovering HomeGenie server...';
      isLoading = true;
    });

    // List of potential API endpoints to try
    final List<String> candidateUrls = [];
    
    try {
      // Add common network ranges and development IPs
      final networkRanges = [
        '192.168.1',
        '192.168.0', 
        '10.0.0',
        '10.132.71',  // Your current network
        '172.16.0',
        '172.20.10', // iOS hotspot range
        '192.168.43', // Android hotspot range
      ];
      
      // Common host IPs to check in each range
      final commonHosts = [1, 2, 100, 101, 102, 103, 104, 105, 110, 200, 254];
      
      for (final range in networkRanges) {
        for (final host in commonHosts) {
          candidateUrls.add('http://$range.$host:8080');  // Docker port first
          candidateUrls.add('http://$range.$host:8000');  // Standard port
        }
      }
      
      // Add some specific common development IPs - prioritize current network
      final additionalIps = [
        'http://10.132.71.35:8080',  // Your current IP with Docker port
        'http://10.132.71.35:8000',  // Your current IP alternate port
        'http://localhost:8080',    // Fallback Docker port
        'http://localhost:8000',    // Fallback standard port
      ];
      candidateUrls.addAll(additionalIps);
      
      _logger.info('Checking ${candidateUrls.length} potential API endpoints...');
      
      // Try to find working API server
      baseUrl = await _findWorkingApiServer(candidateUrls);
      
      if (baseUrl.isNotEmpty) {
        _logger.info('Found HomeGenie API at: $baseUrl');
        setState(() {
          statusMessage = 'Connected to HomeGenie server';
        });
        _fetchDeviceStates();
        _startAutoRefresh(); // Start auto-refresh only after successful discovery
      } else {
        setState(() {
          statusMessage = 'Could not find HomeGenie server on network';
          isLoading = false;
        });
      }
      
    } catch (e) {
      _logger.warning('Network discovery error: $e');
      setState(() {
        statusMessage = 'Network discovery failed: $e';
        isLoading = false;
      });
    }
  }
  
  // Find working API server from candidate URLs
  Future<String> _findWorkingApiServer(List<String> candidates) async {
    _logger.info('Testing ${candidates.length} potential API endpoints...');
    
    // Test candidates in small batches to avoid network flooding
    const batchSize = 5;
    
    for (int i = 0; i < candidates.length; i += batchSize) {
      final batch = candidates.skip(i).take(batchSize).toList();
      final futures = batch.map((url) => _testApiEndpoint(url)).toList();
      
      // Wait for this batch with a timeout
      final results = await Future.wait(futures, eagerError: false);
      
      // Check if any URL in this batch worked
      for (final url in results) {
        if (url.isNotEmpty) {
          return url;
        }
      }
      
      // Update progress
      setState(() {
        statusMessage = 'Scanning network... ${i + batch.length}/${candidates.length}';
      });
      
      // Small delay between batches to be network-friendly
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return '';
  }
  
  // Test if an API endpoint is working
  Future<String> _testApiEndpoint(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$url/devices'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 1)); // Faster timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && (data.containsKey('devices') || data.isNotEmpty)) {
          _logger.info('✅ Found API server at: $url');
          baseUrl = url;
          return url;
        }
      }
    } catch (e) {
      // Silently fail - this is expected for most IPs
    }
    return '';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  Future<void> _executeGoal(String goal) async {
    setState(() {
      isProcessingGoal = true;
      statusMessage = 'Processing "$goal"...';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/goal/$userId?goal=${Uri.encodeComponent(goal)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          statusMessage = 'Success: ${data['message'] ?? 'Goal executed'}';
        });
        // Wait a moment then refresh the states
        await Future.delayed(const Duration(seconds: 1));
        await _fetchDeviceStates();
      } else {
        setState(() {
          statusMessage = 'Failed to execute goal: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error executing goal: $e';
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
                icon: const Icon(Icons.mic, color: Colors.white),
                tooltip: 'Voice Control',
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
                        Text(
                          'API: $baseUrl',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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

  // Voice Control Dialog
  void _showVoiceControlDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mic, color: Colors.blue),
              SizedBox(width: 8),
              Text('Voice Control'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Voice control is coming soon!'),
              SizedBox(height: 16),
              Text('You\'ll be able to say things like:'),
              SizedBox(height: 8),
              Text('• "Turn on the living room lights"'),
              Text('• "Make it cozy"'),
              Text('• "Set bedroom temperature to 72"'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
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
                  () => _executeGoal('make it cozy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  'Save Energy',
                  Icons.eco,
                  Colors.green,
                  () => _executeGoal('save energy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  'Goodnight',
                  Icons.bedtime,
                  Colors.indigo,
                  () => _executeGoal('goodnight'),
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
    // Immediately update UI for responsive feedback
    setState(() {
      deviceToggles[deviceKey] = turnOn;
      isToggleLoading[deviceKey] = true;
    });
    
    await _sendDeviceCommand(deviceKey, {
      'action': turnOn ? 'turn_on' : 'turn_off',
      'brightness': turnOn ? 80 : 0,
    });
    
    // Clear loading state
    setState(() {
      isToggleLoading[deviceKey] = false;
    });
  }

  Future<void> _toggleLock(String deviceKey, bool lock) async {
    await _sendDeviceCommand(deviceKey, {
      'action': lock ? 'lock' : 'unlock',
    });
  }

  Future<void> _toggleMedia(String deviceKey, bool play) async {
    await _sendDeviceCommand(deviceKey, {
      'action': play ? 'play' : 'pause',
    });
  }

  Future<void> _toggleSwitch(String deviceKey, bool turnOn) async {
    await _sendDeviceCommand(deviceKey, {
      'action': turnOn ? 'turn_on' : 'turn_off',
    });
  }



  Future<void> _sendDeviceCommand(String deviceKey, Map<String, dynamic> command) async {
    try {
      // Convert device key to device ID format (e.g., "living_room.temperature" -> "living_room.temperature")
      final deviceId = deviceKey;
      
      final response = await http.post(
        Uri.parse('$baseUrl/devices/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'action': command['action'] ?? 'set',
          'parameters': {
            ...command,
          },
          'user_id': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        // Show brief success feedback
        setState(() {
          statusMessage = 'Device updated successfully!';
        });
        
        // Clear status message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              statusMessage = '';
            });
          }
        });
        
        // Refresh state after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchDeviceStates();
      } else {
        // Revert toggle state on error
        setState(() {
          deviceToggles.remove(deviceKey);
          statusMessage = 'Failed to update device';
        });
      }
    } catch (e) {
      // Revert toggle state on error
      setState(() {
        deviceToggles.remove(deviceKey);
        statusMessage = 'Connection error';
      });
      _logger.warning('Error sending device command: $e');
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