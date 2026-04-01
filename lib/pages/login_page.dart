import 'package:flutter/material.dart';
import 'dart:async';
import '../auth_service.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.onSignedIn,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final VoidCallback? onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String _errorMessage = '';
  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;
  bool _isLockoutDialogVisible = false;
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(0);

  bool get _isLockedOut => _lockoutSecondsRemaining > 0;

  String _friendlyAuthError(Object error, {required bool isGoogle}) {
    final raw = error.toString();
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Invalid email or password. Please try again.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many failed attempts. Please wait a moment and try again.';
    }
    if (raw.contains('PigeonUserDetails') ||
        raw.contains("List<Object> is not a subtype")) {
      return 'Temporary auth sync issue. Please try signing in again.';
    }
    if (raw.contains('ApiException:10') || raw.contains('ApiException: 10')) {
      return 'Google sign-in is not fully configured yet. Complete SHA setup in Firebase and rebuild the app.';
    }
    if (isGoogle) {
      return 'Google sign-in failed: $raw';
    }
    return 'Login failed: ${raw.replaceAll('[firebase_auth/user-not-found]', '').replaceAll('[firebase_auth/wrong-password]', '').trim()}';
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _countdownNotifier.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isInvalidCredentialError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('invalid_login_credentials');
  }

  void _startLoginLockout() {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSecondsRemaining = 10;
      _errorMessage =
          'Too many failed attempts. Please wait 10 seconds before trying again.';
    });
    _countdownNotifier.value = 10;

    _showSweetAlertLockout();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lockoutSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSecondsRemaining = 0;
          _failedAttempts = 0;
          _errorMessage = '';
        });
        _countdownNotifier.value = 0;
        if (_isLockoutDialogVisible && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isLockoutDialogVisible = false;
        return;
      }

      setState(() {
        _lockoutSecondsRemaining -= 1;
      });
      _countdownNotifier.value = _lockoutSecondsRemaining;
    });
  }

  Future<void> _showSweetAlertLockout() async {
    if (_isLockoutDialogVisible || !mounted) return;
    _isLockoutDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, _) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Login Temporarily Locked')),
                ],
              ),
              content: ValueListenableBuilder<int>(
                valueListenable: _countdownNotifier,
                builder: (context, seconds, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Too many failed attempts. Please wait 10 seconds before trying again.',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Try again in $seconds second${seconds == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );

    _isLockoutDialogVisible = false;
  }

  Future<void> _signIn() async {
    if (_isLockedOut) {
      if (!_isLockoutDialogVisible) {
        await _showSweetAlertLockout();
      }
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _failedAttempts = 0;
      widget.onSignedIn?.call();
    } catch (e) {
      final invalidCredentials = _isInvalidCredentialError(e);
      if (invalidCredentials) {
        _failedAttempts += 1;
        if (_failedAttempts >= 3) {
          _startLoginLockout();
        }
      }

      setState(() => _errorMessage = _friendlyAuthError(e, isGoogle: false));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _isLockedOut) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignupPage(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
          autoStartGoogleSignup: true,
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    if (_isLoading || _isLockedOut) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          tooltip: widget.isDarkMode ? 'Light mode' : 'Dark mode',
                          onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
                          icon: Icon(
                            widget.isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 40,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue to your allowance dashboard.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: scheme.error),
                              ),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: scheme.onErrorContainer),
                              ),
                            ),
                          TextField(
                            controller: _emailController,
                            enabled: !_isLoading && !_isLockedOut,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading && !_isLockedOut,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: _isLoading || _isLockedOut
                                    ? null
                                    : () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading || _isLockedOut ? null : _openForgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _isLoading || _isLockedOut ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _isLockedOut
                                        ? 'Locked ($_lockoutSecondsRemaining)'
                                        : 'Sign In',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isLoading || _isLockedOut ? null : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                            label: const Text('Create account with Google'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SignupPage(
                                      isDarkMode: widget.isDarkMode,
                                      onToggleDarkMode: widget.onToggleDarkMode,
                                    ),
                                  ),
                                ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
