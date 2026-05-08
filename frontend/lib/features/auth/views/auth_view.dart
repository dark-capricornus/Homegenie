import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _confirmPasswordController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final controller = context.read<DashboardController>();
      await controller.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      _errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final controller = context.read<DashboardController>();
      await controller.register(
        _usernameController.text.trim(),
        _passwordController.text,
        email: _emailController.text.trim(),
      );
    } catch (e) {
      _errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          const _BackgroundAccent(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D23),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AuthHeader(primary: theme.colorScheme.primary),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withOpacity(0.3),
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'LOGIN'),
                        Tab(text: 'REGISTER'),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _LoginForm(
                            formKey: _loginFormKey,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            errorMessage: _errorMessage,
                            onSubmit: _handleLogin,
                          ),
                          _RegisterForm(
                            formKey: _registerFormKey,
                            usernameController: _usernameController,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            confirmPasswordController: _confirmPasswordController,
                            errorMessage: _errorMessage,
                            onSubmit: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _LoadingOverlay(isLoading: _isLoading),
        ],
      ),
    );
  }
}

class _BackgroundAccent extends StatelessWidget {
  const _BackgroundAccent();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      right: -100,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.primary});
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security_rounded, size: 32, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            'HomeGenie',
            style: TextStyle(fontFamily: 'Outfit', 
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Secure Industrial Infrastructure',
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ValueNotifier<String?> errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AuthTextField(
              key: const ValueKey('login_username'),
              controller: usernameController,
              label: 'Username',
              icon: Icons.person_outline,
              validator: (v) => v!.isEmpty ? 'Enter username' : null,
            ),
            const SizedBox(height: 20),
            _AuthTextField(
              key: const ValueKey('login_password'),
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => v!.isEmpty ? 'Enter password' : null,
            ),
            _ErrorBanner(message: errorMessage),
            const SizedBox(height: 16),
            _SubmitButton(label: 'ACCESS SYSTEM', onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final ValueNotifier<String?> errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AuthTextField(
              key: const ValueKey('reg_username'),
              controller: usernameController,
              label: 'Username',
              icon: Icons.person_outline,
              validator: (v) => v!.isEmpty ? 'Enter username' : null,
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              key: const ValueKey('reg_email'),
              controller: emailController,
              label: 'Email (Optional)',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              key: const ValueKey('reg_password'),
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 16),
            _AuthTextField(
              key: const ValueKey('reg_confirm'),
              controller: confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => v != passwordController.text ? 'Mismatch' : null,
            ),
            _ErrorBanner(message: errorMessage),
            const SizedBox(height: 16),
            _SubmitButton(label: 'CREATE ACCOUNT', onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  bool _visible = false;

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  static final _enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
  );
  static final _labelStyle = TextStyle(color: Colors.white.withOpacity(0.5));
  static final _iconColor = Colors.white.withOpacity(0.3);
  static final _fillColor = Colors.white.withOpacity(0.03);
  static const _textStyle = TextStyle(color: Colors.white);

  @override
  Widget build(BuildContext context) {
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
      ),
    );

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && !_visible,
      style: _textStyle,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: _labelStyle,
        prefixIcon: Icon(widget.icon, color: _iconColor),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _visible ? Icons.visibility_off : Icons.visibility,
                  color: _iconColor,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              )
            : null,
        filled: true,
        fillColor: _fillColor,
        border: _border,
        enabledBorder: _enabledBorder,
        focusedBorder: focusedBorder,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final ValueNotifier<String?> message;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: message,
      builder: (_, msg, __) {
        if (msg == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  static final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          shape: _shape,
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'Inter', 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.isLoading});
  final ValueNotifier<bool> isLoading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (_, loading, __) {
        if (!loading) return const SizedBox.shrink();
        return Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
