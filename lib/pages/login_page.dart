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
  bool _showLoginFaqs = false;
  String _errorMessage = '';
  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;
  bool _isLockoutDialogVisible = false;
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(0);

  static const List<_LoginFaqEntry> _loginFaqs = [
    _LoginFaqEntry(
      icon: Icons.add_card_outlined,
      question: 'How do I add an expense?',
      answer:
          'After sign in, go to Expenses, enter details, and tap Add Expense.',
    ),
    _LoginFaqEntry(
      icon: Icons.wallet_outlined,
      question: 'How do I change my monthly budget?',
      answer:
          'Open the dashboard allowance section and update the value for your selected month.',
    ),
    _LoginFaqEntry(
      icon: Icons.history_outlined,
      question: 'What does the History page show?',
      answer:
          'It shows your logged transactions with filters for category, month, and search.',
    ),
    _LoginFaqEntry(
      icon: Icons.file_download_outlined,
      question: 'Can I export my data?',
      answer:
          'Yes, you can export transactions to Excel and PDF from the History section.',
    ),
    _LoginFaqEntry(
      icon: Icons.support_agent_outlined,
      question: 'How do I contact the developers?',
      answer:
          'Use the FAQs page inside the app and submit your concern in the Ticket section.',
    ),
  ];

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
        if (_isLockoutDialogVisible &&
            Navigator.of(context, rootNavigator: true).canPop()) {
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
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

  Future<void> _openForgotPassword() async {
    if (_isLoading || _isLockedOut) return;
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
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
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
                                  .withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
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
                                    'Welcome back',
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sign in to view your allowance dashboard and recent expenses.',
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
                              controller: _emailController,
                              enabled: !_isLoading && !_isLockedOut,
                              keyboardType: TextInputType.emailAddress,
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
                                    _showPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: _isLoading || _isLockedOut
                                      ? null
                                      : () => setState(
                                          () => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _isLoading || _isLockedOut
                                    ? null
                                    : _openForgotPassword,
                                icon: const Icon(Icons.help_outline, size: 18),
                                label: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              onPressed:
                                  _isLoading || _isLockedOut ? null : _signIn,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                _isLockedOut
                                    ? 'Locked ($_lockoutSecondsRemaining)'
                                    : 'Sign In',
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
                        child: Row(
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
                                            onToggleDarkMode:
                                                widget.onToggleDarkMode,
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
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showLoginFaqs = !_showLoginFaqs);
                      },
                      icon: Icon(
                        _showLoginFaqs
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                      label: const Text('FAQs'),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _showLoginFaqs
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primaryContainer.withValues(alpha: 0.45),
                                scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.quiz_outlined,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'FAQs',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Quick answers before signing in.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._loginFaqs.map(
                                  (faq) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: scheme.outlineVariant,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      collapsedBackgroundColor:
                                          scheme.surface.withValues(alpha: 0.8),
                                      backgroundColor: scheme.surface
                                          .withValues(alpha: 0.96),
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 2,
                                      ),
                                      childrenPadding: const EdgeInsets.only(
                                        left: 12,
                                        right: 12,
                                        bottom: 12,
                                      ),
                                      leading: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          faq.icon,
                                          color: scheme.onPrimaryContainer,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        faq.question,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            faq.answer,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                          ),
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

class _LoginFaqEntry {
  const _LoginFaqEntry({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}
