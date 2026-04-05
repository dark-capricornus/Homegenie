import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

class RoutineBuilderView extends StatefulWidget {
  const RoutineBuilderView({super.key});

  @override
  State<RoutineBuilderView> createState() => _RoutineBuilderViewState();
}

class _RoutineBuilderViewState extends State<RoutineBuilderView> {
  final _nameController = TextEditingController();
  String? _triggerDeviceId;
  String _triggerField = 'state';
  String _triggerOperator = '==';
  String _triggerValue = 'on';

  String? _actionDeviceId;
  String _actionCommand = 'turn_on';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<DashboardController>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('New Routine',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => _saveRoutine(ctrl),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Trigger', Icons.bolt_rounded, Colors.amber),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                children: [
                  _buildDropdown<String>(
                    label: 'When this device...',
                    value: _triggerDeviceId,
                    items: ctrl.devices.map((d) => DropdownMenuItem(
                      value: d.key,
                      child: Text(d.name, style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (val) => setState(() => _triggerDeviceId = val),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildDropdown<String>(
                          label: 'Field',
                          value: _triggerField,
                          items: ['state', 'brightness', 'temperature', 'humidity', 'power_consumption']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13))))
                              .toList(),
                          onChanged: (val) => setState(() => _triggerField = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildDropdown<String>(
                          label: 'Op',
                          value: _triggerOperator,
                          items: ['==', '!=', '>', '<', '>=', '<=']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                              .toList(),
                          onChanged: (val) => setState(() => _triggerOperator = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          label: 'Value',
                          initialValue: _triggerValue,
                          onChanged: (val) => _triggerValue = val,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Action', Icons.play_arrow_rounded, AppColors.primary),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                children: [
                  _buildDropdown<String>(
                    label: 'Perform action on...',
                    value: _actionDeviceId,
                    items: ctrl.devices.map((d) => DropdownMenuItem(
                      value: d.key,
                      child: Text(d.name, style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (val) => setState(() => _actionDeviceId = val),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  _buildDropdown<String>(
                    label: 'Command',
                    value: _actionCommand,
                    items: ['turn_on', 'turn_off', 'toggle', 'set_brightness', 'set_temperature']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (val) => setState(() => _actionCommand = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Name My Routine', Icons.edit_note_rounded, Colors.purpleAccent),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Routine Name',
              controller: _nameController,
              hint: 'e.g. Night Lights',
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  void _saveRoutine(DashboardController ctrl) async {
    if (_triggerDeviceId == null || _actionDeviceId == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final ruleData = {
      'name': _nameController.text,
      'priority': 1,
      'enabled': true,
      'conditions': [
        {
          'field': 'devices.$_triggerDeviceId.observed.$_triggerField',
          'operator': _triggerOperator,
          'value': _triggerValue,
        }
      ],
      'outcome': {
        'type': 'command',
        'code': 'execute_device_cmd',
        'metadata': {
          'device_id': _actionDeviceId,
          'command': _actionCommand,
        }
      }
    };

    final success = await ctrl.saveRule(ruleData);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          underline: const SizedBox(),
          dropdownColor: const Color(0xFF1A1D23),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    String? hint,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
