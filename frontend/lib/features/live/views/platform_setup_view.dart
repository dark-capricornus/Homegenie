import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/models/integration.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

class PlatformSetupView extends StatefulWidget {
  final PlatformIntegration integration;
  final bool isDark;

  const PlatformSetupView({
    super.key,
    required this.integration,
    required this.isDark,
  });

  @override
  State<PlatformSetupView> createState() => _PlatformSetupViewState();
}

class _PlatformSetupViewState extends State<PlatformSetupView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};

  PlatformIntegration get p => widget.integration;
  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    for (final field in _fieldsForPlatform(p.id)) {
      _controllers[field.key] = TextEditingController(
        text: p.config[field.key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsForPlatform(p.id);
    final isCloudPlatform = p.id == 'google_home' || p.id == 'alexa';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          p.name,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Header
            _buildHeader(),
            const SizedBox(height: 32),

            if (isCloudPlatform) ...[
              _buildComingSoonCard(),
            ] else ...[
              _buildConfigForm(fields),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.color.withOpacity(0.15), p.color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(p.icon, color: p.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.construction_rounded,
            size: 56,
            color: p.color.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Coming Soon',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _comingSoonDescription(p.id),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: p.color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _comingSoonRequirements(p.id),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigForm(List<_FieldConfig> fields) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuration',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildField(f),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      p.isConfigured ? 'Update Configuration' : 'Save & Connect',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(_FieldConfig field) {
    return TextFormField(
      controller: _controllers[field.key],
      obscureText: field.isPassword,
      style: GoogleFonts.inter(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.white24 : Colors.black26,
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.color, width: 2),
        ),
        prefixIcon: Icon(field.icon, color: isDark ? Colors.white30 : Colors.black26),
      ),
      validator: field.required
          ? (v) => (v == null || v.isEmpty) ? '${field.label} is required' : null
          : null,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final config = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      if (entry.value.text.isNotEmpty) {
        config[entry.key] = entry.value.text;
      }
    }

    final ctrl = context.read<DashboardController>();
    final success = await ctrl.setupIntegration(p.id, config);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${p.name} configured successfully!'
              : 'Failed to configure ${p.name}. Check your settings.'),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
      if (success) Navigator.pop(context);
    }
  }
}

// ---------------------------------------------------------------------------
// Field configuration per platform
// ---------------------------------------------------------------------------
class _FieldConfig {
  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool required;

  const _FieldConfig({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.required = true,
  });
}

List<_FieldConfig> _fieldsForPlatform(String platformId) {
  switch (platformId) {
    case 'zigbee':
      return const [
        _FieldConfig(
          key: 'coordinator_host',
          label: 'Coordinator Address',
          hint: 'e.g. 192.168.1.100',
          icon: Icons.router_rounded,
        ),
        _FieldConfig(
          key: 'coordinator_port',
          label: 'Port',
          hint: 'e.g. 8080',
          icon: Icons.numbers_rounded,
        ),
        _FieldConfig(
          key: 'network_key',
          label: 'Network Key',
          hint: 'Zigbee network key',
          icon: Icons.key_rounded,
          isPassword: true,
          required: false,
        ),
      ];
    case 'matter':
      return const [
        _FieldConfig(
          key: 'controller_host',
          label: 'Matter Controller Address',
          hint: 'e.g. 192.168.1.100',
          icon: Icons.hub_rounded,
        ),
        _FieldConfig(
          key: 'controller_port',
          label: 'Port',
          hint: 'e.g. 5540',
          icon: Icons.numbers_rounded,
        ),
        _FieldConfig(
          key: 'fabric_id',
          label: 'Fabric ID',
          hint: 'Matter fabric identifier',
          icon: Icons.fingerprint_rounded,
          required: false,
        ),
      ];
    case 'custom_mqtt':
      return const [
        _FieldConfig(
          key: 'broker_url',
          label: 'MQTT Broker URL',
          hint: 'e.g. mqtt://192.168.1.100:1883',
          icon: Icons.dns_rounded,
        ),
        _FieldConfig(
          key: 'topic_prefix',
          label: 'Topic Prefix',
          hint: 'e.g. home/',
          icon: Icons.tag_rounded,
          required: false,
        ),
        _FieldConfig(
          key: 'username',
          label: 'Username',
          hint: 'MQTT username',
          icon: Icons.person_rounded,
          required: false,
        ),
        _FieldConfig(
          key: 'password',
          label: 'Password',
          hint: 'MQTT password',
          icon: Icons.lock_rounded,
          isPassword: true,
          required: false,
        ),
      ];
    default:
      return [];
  }
}

String _comingSoonDescription(String platformId) {
  switch (platformId) {
    case 'google_home':
      return 'Google Home integration will allow you to discover and control '
          'all Nest and Google Home-compatible devices through the Device Access API. '
          'Control lights, thermostats, cameras, and more.';
    case 'alexa':
      return 'Amazon Alexa integration will connect your Echo devices and all '
          'Alexa-compatible smart home accessories. Manage routines, control devices, '
          'and sync states in real-time.';
    default:
      return 'This integration is under development.';
  }
}

String _comingSoonRequirements(String platformId) {
  switch (platformId) {
    case 'google_home':
      return 'Requirements: Google Cloud project with Device Access API enabled, '
          'OAuth 2.0 credentials, and a Google Nest developer account.';
    case 'alexa':
      return 'Requirements: Amazon developer account, Alexa Smart Home Skill, '
          'and Login with Amazon (LWA) OAuth credentials.';
    default:
      return '';
  }
}
