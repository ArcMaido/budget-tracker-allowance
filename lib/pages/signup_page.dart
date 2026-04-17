import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'forgot_password_page.dart';

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

  bool _looksLikeEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  }

  String? _passwordPolicyError(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    // Allow only standard ASCII characters to avoid unsupported symbols/scripts.
    if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(password)) {
      return 'Password can only use standard letters, numbers, and symbols (no spaces).';
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(password).length;
    if (letterCount < 8) {
      return 'Password must include at least 8 letters (A-Z or a-z).';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least 1 uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least 1 number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must include at least 1 symbol.';
    }
    return null;
  }

  bool _hasAtLeastEightLetters(String password) {
    return RegExp(r'[A-Za-z]').allMatches(password).length >= 8;
  }

  bool _hasUppercaseLetter(String password) {
    return RegExp(r'[A-Z]').hasMatch(password);
  }

  bool _hasNumber(String password) {
    return RegExp(r'[0-9]').hasMatch(password);
  }

  bool _hasSymbol(String password) {
    return RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  }

  Widget _buildPasswordPolicyItem({
    required bool isSatisfied,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: isSatisfied ? Colors.green : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSatisfied ? Colors.green : scheme.onSurfaceVariant,
                  fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordPolicyChecklist(String password) {
    final ruleSatisfied = _passwordPolicyError(password) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPasswordPolicyItem(
          isSatisfied: password.length >= 8,
          label: 'At least 8 characters',
        ),
        const SizedBox(height: 6),
        _buildPasswordPolicyItem(
          isSatisfied: _hasAtLeastEightLetters(password),
          label: 'At least 8 letters (A-Z or a-z)',
        ),
        const SizedBox(height: 6),
        _buildPasswordPolicyItem(
          isSatisfied: _hasUppercaseLetter(password),
          label: 'At least 1 uppercase letter',
        ),
        const SizedBox(height: 6),
        _buildPasswordPolicyItem(
          isSatisfied: _hasNumber(password),
          label: 'At least 1 number',
        ),
        const SizedBox(height: 6),
        _buildPasswordPolicyItem(
          isSatisfied: _hasSymbol(password),
          label: 'At least 1 symbol',
        ),
        if (ruleSatisfied) ...[
          const SizedBox(height: 8),
          Text(
            'Password meets all requirements.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

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

    if (_looksLikeEmail(_nameController.text)) {
      setState(() =>
          _errorMessage = 'Full name must be your name, not an email address.');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    final passwordError = _passwordPolicyError(_passwordController.text);
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to terms and conditions');
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
      await AuthService.cachePendingSignupFullName(
        email: normalizedEmail,
        fullName: normalizedName,
      );
      if (normalizedPhoto.isNotEmpty) {
        await AuthService.cachePendingSignupPhotoUrl(
          email: normalizedEmail,
          photoUrl: normalizedPhoto,
        );
      }
      final credential = await AuthService.signUpWithEmail(
        email: normalizedEmail,
        password: _passwordController.text,
        fullName: normalizedName,
        photoUrl: normalizedPhoto.isNotEmpty ? normalizedPhoto : null,
      );

      final createdUser = credential?.user ?? AuthService.currentUser;
      if (createdUser != null) {
        if ((createdUser.displayName ?? '').trim().isEmpty &&
            normalizedName.isNotEmpty) {
          try {
            await createdUser.updateDisplayName(normalizedName);
          } catch (e) {
            print('Warning: Could not update auth display name: $e');
          }
        }
        if (normalizedPhoto.isNotEmpty) {
          try {
            await createdUser.updatePhotoURL(normalizedPhoto);
          } catch (e) {
            print('Warning: Could not update auth photo: $e');
          }
        }
      }

      await _showSignupNotice(
        title: 'Account Created',
        message:
            'Your account was created successfully. Please sign in with your email and password.',
        success: true,
      );
      await _returnToLogin();
    } catch (e) {
      final raw = e.toString();
      final email = _emailController.text.trim();
      final hasPasswordSignIn = email.isNotEmpty &&
          await AuthService.isEmailRegisteredForPassword(email);

      if (raw.contains('email-already-in-use')) {
        await _showSignupNotice(
          title: 'Account Exists',
          message:
              'This email is already registered. Please sign in on the Login page.',
          success: false,
        );
        await _returnToLogin();
      } else if (raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype")) {
        // Auth succeeded but there was a bridge error. Account is usable.
        await _showSignupNotice(
          title: 'Account Created',
          message:
              'Your account was created successfully. Please sign in with your email and password.',
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
          setState(
              () => _errorMessage = _friendlyAuthError(e, isGoogle: false));
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
        if (displayName.isNotEmpty && !_looksLikeEmail(displayName)) {
          _nameController.text = displayName;
          _namePrefilledFromGoogle = true;
        } else {
          _nameController.clear();
          _namePrefilledFromGoogle = false;
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

  Future<void> _openForgotPassword() async {
    if (_isLoading) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip:
                              widget.isDarkMode ? 'Light mode' : 'Dark mode',
                          onPressed: () =>
                              widget.onToggleDarkMode(!widget.isDarkMode),
                          icon: Icon(
                            widget.isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primaryContainer.withValues(alpha: 0.6),
                              scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 34,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create your account',
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Set up your profile and start tracking allowance and expenses in one place.',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: scheme.error),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: scheme.onErrorContainer),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                            color: scheme.onErrorContainer),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            TextField(
                              controller: _nameController,
                              enabled: !_isLoading,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              enabled:
                                  !_isLoading && !_emailPrefilledFromGoogle,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            if (_emailPrefilledFromGoogle)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Email was selected from Google account.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (_namePrefilledFromGoogle)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Name was prefilled from Google. You can still edit it.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: !_showPassword,
                              onChanged: (_) {
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(
                                          () => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Password Policy',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Follow the live checklist below as you type.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPasswordPolicyChecklist(
                                    _passwordController.text,
                                  ),
                                ],
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
                                    _showConfirmPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(
                                            () => _showConfirmPassword =
                                                !_showConfirmPassword,
                                          ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                value: _agreedToTerms,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(() =>
                                            _agreedToTerms = value ?? false);
                                      },
                                title: const Text(
                                    'I agree to Terms and Conditions'),
                                subtitle: Text(
                                  'Your data is encrypted and securely stored. We never share your personal information.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _signUp,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: const Text('Create Account'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _selectGoogleEmail,
                              icon: const Icon(Icons.g_mobiledata_rounded,
                                  size: 28),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant),
                                ),
                                GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => Navigator.pop(context),
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
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _openForgotPassword,
                              icon: const Icon(Icons.lock_reset_outlined,
                                  size: 18),
                              label: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
