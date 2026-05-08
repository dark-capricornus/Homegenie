import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/network/api_locator.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/core/widgets/page_header.dart';

class ServerSettingsScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final ValueChanged<int>? onNavTap;

  final int currentIndex;

  const ServerSettingsScreen({
    super.key,
    required this.isDark,
    required this.currentIndex,
    this.onToggleTheme,
    this.onNavTap,
  });

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController();
  String _detected = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadValues() async {
    final base = await ApiLocator.getBaseUrl();
    final ov = await ApiLocator.getManualOverride();
    if (!mounted) return;
    setState(() {
      _detected = base;
      _controller.text = ov ?? '';
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

  Future<void> _saveOverride() async {
    final text = _controller.text.trim();
    await ApiLocator.setManualOverride(text.isEmpty ? null : text);
    await _loadValues();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved ✅')),
      );
    }
  }

  Future<void> _clearAndRedetect() async {
    await ApiLocator.setManualOverride(null);
    await _loadValues();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final controller = context.watch<DashboardController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        PageHeader(
          title: 'Settings',
          subtitle: 'User & Server',
          isDark: widget.isDark,
          currentIndex: widget.currentIndex,
          onToggleTheme: widget.onToggleTheme,
          onNavTap: widget.onNavTap,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
        // ── User Profile ──
        _SettingsSection(
          title: 'PROFILE',
          isDark: isDark,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: controller.isLoggedIn
                          ? AppColors.primary
                          : AppColors.primaryDim,
                      child: Icon(
                          controller.isLoggedIn
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          color: controller.isLoggedIn
                              ? Colors.white
                              : AppColors.primary,
                          size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              controller.currentUser?.username ?? 'Guest User',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(
                              controller.isLoggedIn
                                  ? 'Authenticated Administrator'
                                  : 'Guest User',
                              style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: controller.isLoggedIn ? 'Logout' : 'Admin Login',
                icon: controller.isLoggedIn ? Icons.logout : Icons.login,
                onPressed: () => controller.isLoggedIn 
                    ? controller.logout() 
                    : null,
                isDark: isDark,
                primary: !controller.isLoggedIn,
                outlined: controller.isLoggedIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Theme ──
        _SettingsSection(
          title: 'APPEARANCE',
          isDark: isDark,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dark Mode',
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(isDark ? 'Currently enabled' : 'Currently disabled',
                          style: TextStyle(color: textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isDark,
                  onChanged: (_) => widget.onToggleTheme?.call(),
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Connection ──
        _SettingsSection(
          title: 'OPERATION MODE',
          isDark: isDark,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.bug_report_rounded,
                    color: controller.isDemoMode ? AppColors.primary : textSecondary,
                    size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Demo Mode',
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                          controller.isDemoMode
                              ? 'Using simulated data'
                              : 'Connected to server',
                          style: TextStyle(color: textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: controller.isDemoMode,
                  onChanged: (val) => controller.setMode(val),
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _SettingsSection(
          title: 'CONNECTION',
          isDark: isDark,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dns_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Detected Server',
                        style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _detected.isEmpty ? 'None' : _detected,
                    style: TextStyle(
                        color: _detected.isEmpty ? textSecondary : AppColors.success,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Manual Override',
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'http://host:8081',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionButton(
                      label: 'Test',
                      icon: Icons.link_rounded,
                      loading: _testing,
                      onPressed: _testConnection,
                      isDark: isDark,
                    ),
                    _ActionButton(
                      label: 'Re-Detect',
                      icon: Icons.autorenew_rounded,
                      onPressed: _clearAndRedetect,
                      isDark: isDark,
                      outlined: true,
                    ),
                    _ActionButton(
                      label: 'Save',
                      icon: Icons.check_rounded,
                      onPressed: _saveOverride,
                      isDark: isDark,
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
          ]),
        ),
      ],
    );
  }
}

// ── Reusable Helpers ──

class _SettingsSection extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget child;
  const _SettingsSection({required this.title, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title,
              style: TextStyle(
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.2,
              )),
        ),
        child,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final bool loading;
  final bool outlined;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.loading = false,
    this.outlined = false,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
