import 'package:flutter/material.dart';
import '../auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (!_agreedToTerms) {
      setState(
          () => _errorMessage = 'Please agree to terms and conditions');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
    } catch (e) {
      setState(
          () => _errorMessage = 'Sign up failed: ${e.toString().split(']').last}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-up failed: ${e.toString()}');
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
                      IconButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
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
                  const SizedBox(height: 2),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set up your account to start tracking allowance and expenses.',
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
                            controller: _nameController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: _isLoading
                                    ? null
                                    : () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            enabled: !_isLoading,
                            obscureText: !_showConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => setState(
                                          () => _showConfirmPassword = !_showConfirmPassword,
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _agreedToTerms,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() => _agreedToTerms = value ?? false);
                                  },
                            title: const Text('I agree to Terms and Conditions'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _isLoading ? null : _signUp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Create Account'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signUpWithGoogle,
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                            label: const Text('Sign up with Google'),
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
                        'Already have an account? ',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
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
