import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
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
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: ${e.toString().replaceAll('[firebase_auth/user-not-found]', '').replaceAll('[firebase_auth/wrong-password]', '')}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
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
                    child: Container(
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
                            enabled: !_isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Sign In'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                            label: const Text('Sign in with Google'),
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
