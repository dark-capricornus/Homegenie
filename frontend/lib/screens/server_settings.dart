import 'package:flutter/material.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:homegenie_app/network/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController();
  final _mqttController = TextEditingController();
  String _detected = '';
  bool _testing = false;
  bool _testingMqtt = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  @override
  void dispose() {
    _controller.dispose();
    _mqttController.dispose();
    super.dispose();
  }

  Future<void> _loadValues() async {
    final base = await ApiLocator.getBaseUrl();
    final ov = await ApiLocator.getManualOverride();
    // Load MQTT override from shared preferences
    String? mqttOv;
    try {
      final prefs = await SharedPreferences.getInstance();
      mqttOv = prefs.getString('mqtt_override_host');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _detected = base;
      _controller.text = ov ?? '';
      _mqttController.text = mqttOv ?? '';
    });
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _testing = false);
      const snack = SnackBar(content: Text('Please enter a URL first'));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
      return;
    }
    final ok = await ApiLocator.testUrl(url);
    setState(() => _testing = false);
    final snack = SnackBar(
      content: Text(ok
          ? 'SUCCESS: Backend detected at $url ✅'
          : 'FAILURE: Connection test failed for $url ❌'),
      backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<void> _testMqttConnection() async {
    setState(() => _testingMqtt = true);
    final mqttText = _mqttController.text.trim();
    try {
      final svc = MqttService();
      final ok = await svc.testConnection(
          overrideHost: mqttText.isEmpty ? null : mqttText);
      final snack = SnackBar(
          content:
              Text(ok ? 'MQTT connection OK ✅' : 'MQTT connection FAILED ❌'));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
    } catch (e) {
      const snack = SnackBar(content: Text('MQTT connection FAILED ❌'));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
    } finally {
      setState(() => _testingMqtt = false);
    }
  }

  Future<void> _saveOverride() async {
    final text = _controller.text.trim();
    await ApiLocator.setManualOverride(text.isEmpty ? null : text);
    // Save mqtt override
    final mqttText = _mqttController.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mqttText.isEmpty) {
        await prefs.remove('mqtt_override_host');
      } else {
        await prefs.setString('mqtt_override_host', mqttText);
      }
    } catch (_) {}
    await _loadValues();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearAndRedetect() async {
    await ApiLocator.setManualOverride(null);
    await _loadValues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detected server (cached):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(_detected.isEmpty ? 'None' : _detected),
            const SizedBox(height: 20),
            const Text('Manual override (full base URL)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                  hintText: 'http://host:8080 or http://host:8081'),
            ),
            const SizedBox(height: 12),
            const Text('MQTT broker host override (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _mqttController,
              decoration: const InputDecoration(
                  hintText: 'host or IP (e.g. 192.168.1.10)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link),
                  label: const Text('Test Connection'),
                ),
                ElevatedButton.icon(
                  onPressed: _testingMqtt ? null : _testMqttConnection,
                  icon: _testingMqtt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi),
                  label: const Text('Test MQTT'),
                ),
                OutlinedButton(
                  onPressed: _clearAndRedetect,
                  child: const Text('Clear Override & Re-Detect'),
                ),
                ElevatedButton(
                  onPressed: _saveOverride,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
