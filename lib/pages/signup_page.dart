import 'package:flutter/material.dart';
import '../auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.autoStartGoogleSignup = false,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final bool autoStartGoogleSignup;

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
  bool _emailPrefilledFromGoogle = false;
  bool _namePrefilledFromGoogle = false;
  String? _googlePhotoUrl;

  Future<void> _showSignupNotice({
    required String title,
    required String message,
    required bool success,
  }) async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.info_outline,
                color: success ? Colors.green : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoStartGoogleSignup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectGoogleEmail();
        }
      });
    }
  }

  Future<void> _returnToLogin() async {
    final signedOut = await AuthService.ensureSignedOut();
    if (!mounted) return;

    if (!signedOut) {
      setState(() {
        _errorMessage =
            'Could not complete sign-out cleanly. Please restart the app, then sign in.';
      });
      return;
    }

    // Return to the existing root login route so auth state can drive app entry.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _friendlyAuthError(Object error, {required bool isGoogle}) {
    final raw = error.toString();
    if (raw.contains('email-already-in-use')) {
      return 'This email is already registered. Please go to Sign In.';
    }
    if (raw.contains('PigeonUserDetails') ||
        raw.contains("List<Object> is not a subtype")) {
      return 'Account is ready. Please sign in on the Login page.';
    }
    if (raw.contains('ApiException:10') || raw.contains('ApiException: 10')) {
      return 'Google sign-in is not fully configured yet. Complete SHA setup in Firebase and rebuild the app.';
    }
    if (isGoogle) {
      return 'Google sign-up failed: $raw';
    }
    return 'Sign up failed: ${raw.split(']').last.trim()}';
  }

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
      final normalizedName = _nameController.text.trim();
      final normalizedEmail = _emailController.text.trim();
      final normalizedPhoto = (_googlePhotoUrl ?? '').trim();
      final credential = await AuthService.signUpWithEmail(
        email: normalizedEmail,
        password: _passwordController.text,
        fullName: normalizedName,
        photoUrl: normalizedPhoto.isNotEmpty ? normalizedPhoto : null,
      );

      final createdUser = credential?.user ?? AuthService.currentUser;
      if (createdUser != null) {
        if ((createdUser.displayName ?? '').trim().isEmpty && normalizedName.isNotEmpty) {
          try {
            await createdUser.updateDisplayName(normalizedName);
          } catch (e) {
            print('Warning: Could not update auth display name: $e');
          }
        }
        if ((createdUser.photoURL ?? '').trim().isEmpty && normalizedPhoto.isNotEmpty) {
          try {
            await createdUser.updatePhotoURL(normalizedPhoto);
          } catch (e) {
            print('Warning: Could not update auth photo: $e');
          }
        }
      }

      await _showSignupNotice(
        title: 'Account Created',
        message: 'Your account was created successfully. Please sign in with your email and password.',
        success: true,
      );
      await _returnToLogin();
    } catch (e) {
      final raw = e.toString();
      final email = _emailController.text.trim();
      final hasPasswordSignIn =
          email.isNotEmpty && await AuthService.isEmailRegisteredForPassword(email);

      if (raw.contains('email-already-in-use')) {
        await _showSignupNotice(
          title: 'Account Exists',
          message: 'This email is already registered. Please sign in on the Login page.',
          success: false,
        );
        await _returnToLogin();
      } else if (raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype")) {
        // Auth succeeded but there was a bridge error. Account is usable.
        await _showSignupNotice(
          title: 'Account Created',
          message: 'Your account was created successfully. Please sign in with your email and password.',
          success: true,
        );
        await _returnToLogin();
      } else if (hasPasswordSignIn) {
        await _showSignupNotice(
          title: 'Account Created',
          message: 'Your account is ready. Please sign in on the Login page.',
          success: true,
        );
        await _returnToLogin();
      } else {
        if (mounted) {
          setState(() => _errorMessage = _friendlyAuthError(e, isGoogle: false));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectGoogleEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefill = await AuthService.pickGoogleEmailForSignup();
      if (prefill == null || prefill.email.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      if (!mounted) return;
      final displayName = (prefill.displayName ?? '').trim();
      setState(() {
        _emailController.text = prefill.email;
        if (displayName.isNotEmpty) {
          _nameController.text = displayName;
          _namePrefilledFromGoogle = true;
        }
        _googlePhotoUrl = (prefill.photoUrl ?? '').trim().isNotEmpty
            ? prefill.photoUrl!.trim()
            : null;
        _emailPrefilledFromGoogle = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyAuthError(e, isGoogle: true));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                            enabled: !_isLoading && !_emailPrefilledFromGoogle,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          if (_emailPrefilledFromGoogle)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Email was selected from Google account.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          if (_namePrefilledFromGoogle)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Name was prefilled from Google. You can still edit it.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
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
                            subtitle: Text(
                              'Your data is encrypted and securely stored. We never share your personal information.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
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
                            onPressed: _isLoading ? null : _selectGoogleEmail,
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                            label: Text(
                              _emailPrefilledFromGoogle
                                  ? 'Google profile selected'
                                  : 'Use Google to prefill profile',
                            ),
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
