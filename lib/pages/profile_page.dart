import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_service.dart';
import '../auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _googleSignIn = GoogleSignIn();

  String? _coverPhotoUrl;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _signupStyleEmailFallback(String? email) {
    final e = (email ?? '').trim();
    if (e.isEmpty || !e.contains('@')) {
      return '';
    }

    final rawLocal = e.split('@').first.trim();
    var unquoted = rawLocal;
    while (unquoted.startsWith('"') || unquoted.startsWith("'")) {
      unquoted = unquoted.substring(1).trimLeft();
    }
    while (unquoted.endsWith('"') || unquoted.endsWith("'")) {
      unquoted = unquoted.substring(0, unquoted.length - 1).trimRight();
    }

    final cleaned = unquoted
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }

  String? _googleProviderDisplayName(User user) {
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        final name = (provider.displayName ?? '').trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
    }
    return null;
  }

  bool _isEmailDerivedName(String value, String? email) {
    final v = value.trim();
    if (v.isEmpty) {
      return false;
    }

    final normalizedValue =
        v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedValue.contains('@')) {
      return true;
    }

    final e = (email ?? '').trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      return false;
    }

    final localRaw = e.split('@').first.trim();
    var local = localRaw;
    while (local.startsWith('"') || local.startsWith("'")) {
      local = local.substring(1).trimLeft();
    }
    while (local.endsWith('"') || local.endsWith("'")) {
      local = local.substring(0, local.length - 1).trimRight();
    }
    local = local.trim();
    final localSpaced = _signupStyleEmailFallback(e).toLowerCase();
    final compactSpaced = localSpaced.replaceAll(' ', '');

    final candidateSet = <String>{
      localRaw,
      local,
      localSpaced,
      compactSpaced,
    }.map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim()).toSet();

    return candidateSet.contains(normalizedValue);
  }

  Future<String?> _googleDisplayNameLikeSignup(User user) async {
    final providerName = _googleProviderDisplayName(user);
    if (providerName != null && providerName.trim().isNotEmpty) {
      return providerName.trim();
    }

    try {
      final account = await _googleSignIn.signInSilently();
      final silentName = (account?.displayName ?? '').trim();
      if (silentName.isNotEmpty) {
        return silentName;
      }
    } catch (_) {
      // best effort only
    }

    return null;
  }

  String _resolveProfileFullName({
    required String? profileName,
    required String? providerDisplayName,
    required String? authDisplayName,
    required String? localCachedDisplayName,
    required String? email,
  }) {
    final p = (profileName ?? '').trim();
    final g = (providerDisplayName ?? '').trim();
    final a = (authDisplayName ?? '').trim();
    final l = (localCachedDisplayName ?? '').trim();
    final pLooksEmailDerived = _isEmailDerivedName(p, email);
    final gLooksEmailDerived = _isEmailDerivedName(g, email);
    final aLooksEmailDerived = _isEmailDerivedName(a, email);
    final lLooksEmailDerived = _isEmailDerivedName(l, email);

    if (p.isNotEmpty && p.toLowerCase() != 'user' && !pLooksEmailDerived) {
      return p;
    }
    if (g.isNotEmpty && g.toLowerCase() != 'user' && !gLooksEmailDerived) {
      return g;
    }
    if (a.isNotEmpty && a.toLowerCase() != 'user' && !aLooksEmailDerived) {
      return a;
    }
    if (l.isNotEmpty && l.toLowerCase() != 'user' && !lLooksEmailDerived) {
      return l;
    }

    return 'Not set';
  }

  Future<void> _diagnoseAndHealProfileName({
    required User user,
    required String? profileName,
    required String? authDisplayName,
    required String resolvedName,
  }) async {
    debugPrint(
      'PROFILE_DIAG uid=${user.uid} '
      'profileName="${profileName ?? ''}" '
      'authDisplayName="${authDisplayName ?? ''}" '
      'email="${user.email ?? ''}" '
      'resolvedName="$resolvedName"',
    );

    final stored = (profileName ?? '').trim();
    final shouldHealExistingEmailDerived =
        stored.isNotEmpty && _isEmailDerivedName(stored, user.email);

    // Heal if missing, or if existing stored value is email-derived.
    if ((!shouldHealExistingEmailDerived && stored.isNotEmpty) ||
        resolvedName.isEmpty ||
        resolvedName == 'User' ||
        resolvedName == 'Not set' ||
        resolvedName == stored) {
      return;
    }

    try {
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: {
          'fullName': resolvedName,
          'lastUpdated': DateTime.now(),
        },
      );
    } catch (_) {
      // best effort only
    }

    try {
      if ((user.displayName ?? '').trim() != resolvedName) {
        await user.updateDisplayName(resolvedName);
      }
    } catch (_) {
      // best effort only
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load profile with timeout
      final profile = await FirebaseService.getUserProfile(user.uid)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      final profileName = (profile?['fullName'] as String?)?.trim();
      final providerDisplayName = await _googleDisplayNameLikeSignup(user);
      final authDisplayName = user.displayName?.trim();
      final localCachedDisplayName = await _readLocalCachedDisplayName();
      var fullName = _resolveProfileFullName(
        profileName: profileName,
        providerDisplayName: providerDisplayName,
        authDisplayName: authDisplayName,
        localCachedDisplayName: localCachedDisplayName,
        email: user.email,
      );
      if (fullName == 'Not set' && (user.email ?? '').trim().isNotEmpty) {
        final lastSignupName =
            await AuthService.readLastSignupFullName(user.email!);
        if (lastSignupName != null && lastSignupName.isNotEmpty) {
          fullName = lastSignupName;
          unawaited(
            FirebaseService.saveUserProfile(
              userId: user.uid,
              userData: {
                'fullName': fullName,
                'lastUpdated': DateTime.now(),
              },
            ),
          );
          unawaited(user.updateDisplayName(fullName));
        }
      }
      final role = (profile?['role'] as String?)?.trim() ?? 'User';
      final coverUrl = (profile?['coverPhotoUrl'] as String?)?.trim();

      unawaited(
        _diagnoseAndHealProfileName(
          user: user,
          profileName: profileName,
          authDisplayName: providerDisplayName ?? authDisplayName,
          resolvedName: fullName,
        ),
      );

      // If Firestore has an explicit non-email-derived name, keep auth display name in sync.
      if (profileName != null &&
          profileName.isNotEmpty &&
          !_isEmailDerivedName(profileName, user.email) &&
          (user.displayName ?? '').trim() != profileName) {
        unawaited(user.updateDisplayName(profileName));
      }

      setState(() {
        _nameController.text = fullName;
        _roleController.text = role;
        _coverPhotoUrl = coverUrl;
        _isLoading = false;
      });
    } catch (e) {
      // Use local fallback
      if (mounted) {
        final providerDisplayName = await _googleDisplayNameLikeSignup(user);
        final resolvedName = _resolveProfileFullName(
          profileName: null,
          providerDisplayName: providerDisplayName,
          authDisplayName: user.displayName,
          localCachedDisplayName: await _readLocalCachedDisplayName(),
          email: user.email,
        );
        debugPrint(
          'PROFILE_DIAG_FALLBACK uid=${user.uid} '
          'authDisplayName="${user.displayName ?? ''}" '
          'email="${user.email ?? ''}" '
          'resolvedName="$resolvedName" '
          'error="$e"',
        );
        setState(() {
          _nameController.text = resolvedName;
          _roleController.text = 'User';
          _coverPhotoUrl = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final role = _roleController.text.trim();

    if (name.isEmpty || role.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    setState(() {
      _isSaving = true;
      _isEditing = false;
    });
    _showSavingMessage();

    try {
      final updateAuthFuture = AuthService.updateUserProfile(
        fullName: name,
      ).timeout(const Duration(seconds: 8));

      final saveProfileFuture = FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: {
          'fullName': name,
          'role': role,
          if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
            'coverPhotoUrl': _coverPhotoUrl,
          'lastUpdated': DateTime.now(),
        },
      ).timeout(const Duration(seconds: 8));

      await Future.wait([updateAuthFuture, saveProfileFuture]);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showSaveSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = true;
      });
      _showMessage('Failed to save profile: ${e.toString()}');
    }
  }

  Future<String?> _readLocalCachedDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('userData');
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final name = (decoded['displayName'] as String?)?.trim();
        return (name != null && name.isNotEmpty) ? name : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final bgColor =
        isSuccess ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    const fgColor = Colors.white;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        elevation: 10,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: fgColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSuccess ? 'Success' : 'Error',
                    style: const TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(color: fgColor.withValues(alpha: 0.95)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavingMessage() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    const bgColor = Color(0xFF1E40AF);
    const fgColor = Colors.white;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        elevation: 10,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(fgColor),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saving',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Updating your profile details...',
                    style: TextStyle(color: fgColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveSuccessDialog() async {
    if (!mounted) return;
    _showMessage('Your profile details were saved successfully.',
        isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayName =
      _nameController.text.isEmpty ? 'Not set' : _nameController.text;
    final displayRole =
      _roleController.text.isEmpty ? 'Not set' : _roleController.text;
    final displayEmail = user?.email ?? 'No email';

    final initials = displayName == 'Not set'
      ? 'U'
      : displayName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
            onPressed: _isSaving
                ? null
                : () {
                    if (_isEditing) {
                      _loadProfileData(); // Reload on cancel
                    }
                    setState(() => _isEditing = !_isEditing);
                  },
            tooltip: _isEditing ? 'Cancel' : 'Edit',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.1),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.62),
                      scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surface.withValues(alpha: 0.75),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                _coverPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayRole,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayEmail,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                _isEditing
                    ? 'Edit your details below and save when finished.'
                    : 'Keep your profile details up to date so your account stays easy to recognize.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isEditing)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit Profile',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roleController,
                        decoration: const InputDecoration(
                          labelText: 'Role/Title',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Email (Read-only)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        child: Text(
                          displayEmail,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Details',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoTile(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        value: displayName,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: displayRole,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: displayEmail,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
}
