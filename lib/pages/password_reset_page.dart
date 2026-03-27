import 'package:flutter/material.dart';

import '../auth_service.dart';
import 'forgot_password_page.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    required this.resetCode,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final String resetCode;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isResetting = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? scheme.primary : scheme.error,
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

  String _validateForm() {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) {
      return 'Please fill in all fields';
    }

    if (newPass.length < 6) {
      return 'Password must be at least 6 characters long';
    }

    if (newPass != confirmPass) {
      return 'Passwords do not match';
    }

    return '';
  }

  Future<void> _resetPassword() async {
    final validationError = _validateForm();
    if (validationError.isNotEmpty) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isResetting = true;
      _errorMessage = '';
    });

    try {
      await AuthService.confirmPasswordResetWithCode(
        code: widget.resetCode,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      await _showAlert(
        title: 'Password Reset Successful',
        message: 'Your password has been reset successfully. Sign in with your new password.',
        success: true,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => ForgotPasswordPage(
            isDarkMode: widget.isDarkMode,
            onToggleDarkMode: widget.onToggleDarkMode,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _friendlyErrorMessage(e);
      setState(() => _errorMessage = errorMsg);
      await _showAlert(
        title: 'Reset Failed',
        message: errorMsg,
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('invalid-action-code') ||
        raw.contains('expired-action-code')) {
      return 'This reset link has expired. Please request a new one.';
    }
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Use a stronger password.';
    }
    if (raw.contains('user-not-found')) {
      return 'User account not found.';
    }
    return 'Failed to reset password. Please try again.';
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onToggleVisibility,
    required bool isConfirm,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      enabled: !_isResetting,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
        helperText: isConfirm ? null : 'At least 6 characters',
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
                      IconButton(
                        onPressed: _isResetting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
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
                        Icons.vpn_key_outlined,
                        size: 40,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set New Password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a strong password to recover your account',
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: scheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: scheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: scheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_errorMessage.isNotEmpty)
                            const SizedBox(height: 12),
                          _buildPasswordField(
                            label: 'New Password',
                            controller: _newPasswordController,
                            showPassword: _showNewPassword,
                            isConfirm: false,
                            onToggleVisibility: () => setState(
                              () => _showNewPassword = !_showNewPassword,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPasswordField(
                            label: 'Confirm Password',
                            controller: _confirmPasswordController,
                            showPassword: _showConfirmPassword,
                            isConfirm: true,
                            onToggleVisibility: () => setState(
                              () => _showConfirmPassword = !_showConfirmPassword,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isResetting ? null : _resetPassword,
                            icon: _isResetting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isResetting ?
                              'Setting new password...' :
                              'Set New Password & Recover Account',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Your password must be at least 6 characters long and include a mix of letters, numbers, and symbols for security.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isResetting
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
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
    );
  }
}
