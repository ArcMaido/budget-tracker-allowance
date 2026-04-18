import 'package:flutter/material.dart';

import '../auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
    this.initialEmail,
  });

  final bool isDarkMode;
  final ValueChanged<bool>? onToggleDarkMode;
  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isSendingLink = false;
  bool _linkSent = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    final prefill = (widget.initialEmail ?? '').trim();
    if (prefill.isNotEmpty) {
      _emailController.text = prefill;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _showAlert({
    required String title,
    required String message,
    bool success = false,
  }) async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.info_outline,
              color: success ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _statusMessage = 'Enter your email address to continue.';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _statusMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isSendingLink = true;
      _statusMessage = '';
    });
    try {
      await AuthService.resetPassword(email: email);
      if (!mounted) return;

      setState(() {
        _linkSent = true;
        _statusMessage =
            'Reset email sent to $email. Check your inbox and spam folder.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Unable to send reset email right now. Please confirm your email and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSendingLink = false);
      }
    }
  }

  Widget _buildFormContent() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Account recovery',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your email and we will send a secure reset link.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isSendingLink && !_linkSent,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          onSubmitted: (_) {
            if (!_isSendingLink && !_linkSent) {
              _sendResetLink();
            }
          },
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _linkSent
                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                  : scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _linkSent ? scheme.primary : scheme.error,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _linkSent
                      ? Icons.mark_email_read_outlined
                      : Icons.info_outline,
                  color: _linkSent
                      ? scheme.onPrimaryContainer
                      : scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _linkSent
                          ? scheme.onPrimaryContainer
                          : scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isSendingLink || _linkSent ? null : _sendResetLink,
          icon: _isSendingLink
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_read_outlined),
          label: Text(_isSendingLink ? 'Sending...' : 'Send Reset Link'),
        ),
        if (_linkSent) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.refresh, size: 18),
                label: const Text('Use another email'),
                onPressed: _isSendingLink
                    ? null
                    : () {
                        setState(() {
                          _linkSent = false;
                          _statusMessage = '';
                        });
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.login, size: 18),
                label: const Text('Back to Sign In'),
                onPressed:
                    _isSendingLink ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick steps',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Open the reset email\n2. Tap the secure link\n3. Create a new password\n4. Return to sign in',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!_linkSent) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed:
                _isSendingLink ? null : () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ] else ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isSendingLink
                ? null
                : () {
                    final email = _emailController.text.trim();
                    setState(() {
                      _linkSent = false;
                      _statusMessage = '';
                      _emailController.text = email;
                    });
                  },
            child: const Text('Send another link'),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(ColorScheme scheme, TextTheme textTheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.65),
              scheme.surfaceContainerHighest.withValues(alpha: 0.85),
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
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                Icons.lock_reset_outlined,
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
                    'Forgot your password?',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No worries. Recover access in under a minute.',
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _isSendingLink
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        if (widget.onToggleDarkMode != null)
                          IconButton.filledTonal(
                            tooltip:
                                widget.isDarkMode ? 'Light mode' : 'Dark mode',
                            onPressed: () =>
                                widget.onToggleDarkMode!(!widget.isDarkMode),
                            icon: Icon(
                              widget.isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildHeaderCard(scheme, textTheme),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: _buildFormContent(),
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
