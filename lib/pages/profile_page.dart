import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

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
  final _picker = ImagePicker();
  final _googleSignIn = GoogleSignIn();

  String? _photoUrl;
  String? _coverPhotoUrl;
  Uint8List? _pendingPhotoBytes;
  Uint8List? _pendingCoverBytes;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCover = false;
  bool _isClearingBrokenPhoto = false;
  bool _isClearingBrokenCover = false;

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

    final normalizedValue = v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
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
    required String? email,
  }) {
    final p = (profileName ?? '').trim();
    final g = (providerDisplayName ?? '').trim();
    final a = (authDisplayName ?? '').trim();
    final fallbackName = _signupStyleEmailFallback(email);

    // Stored name (in Firestore) is explicit; use it regardless of email-derived checks.
    // It was intentionally set during signup or profile edit.
    if (p.isNotEmpty) {
      return p;
    }
    // Prefer Google-provided display name (skipping email-derived sources).
    if (g.isNotEmpty && !_isEmailDerivedName(g, email)) {
      return g;
    }
    // Prefer auth display name (skipping email-derived sources).
    if (a.isNotEmpty && !_isEmailDerivedName(a, email)) {
      return a;
    }
    // Fallback: use email-derived name if available.
    if (fallbackName.isNotEmpty) {
      return fallbackName;
    }
    return 'User';
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
      'resolvedName="${resolvedName}"',
    );

    final stored = (profileName ?? '').trim();
    final shouldHealExistingEmailDerived =
        stored.isNotEmpty && _isEmailDerivedName(stored, user.email);

    // Heal if missing, or if existing stored value is email-derived.
    if ((!shouldHealExistingEmailDerived && stored.isNotEmpty) ||
        resolvedName.isEmpty ||
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
      final fullName = _resolveProfileFullName(
        profileName: profileName,
        providerDisplayName: providerDisplayName,
        authDisplayName: authDisplayName,
        email: user.email,
      );
      final role = (profile?['role'] as String?)?.trim() ?? 'User';
      final photoUrl = (profile?['photoUrl'] as String?)?.trim() ?? 
          user.photoURL?.trim();
      final coverUrl = (profile?['coverPhotoUrl'] as String?)?.trim();

      unawaited(
        _diagnoseAndHealProfileName(
          user: user,
          profileName: profileName,
          authDisplayName: providerDisplayName ?? authDisplayName,
          resolvedName: fullName,
        ),
      );

      setState(() {
        _nameController.text = fullName;
        _roleController.text = role;
        _photoUrl = photoUrl;
        _coverPhotoUrl = coverUrl;
        _isClearingBrokenPhoto = false;
        _isClearingBrokenCover = false;
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
          email: user.email,
        );
        debugPrint(
          'PROFILE_DIAG_FALLBACK uid=${user.uid} '
          'authDisplayName="${user.displayName ?? ''}" '
          'email="${user.email ?? ''}" '
          'resolvedName="${resolvedName}" '
          'error="$e"',
        );
        setState(() {
          _nameController.text = resolvedName;
          _roleController.text = 'User';
          _photoUrl = user.photoURL?.trim();
          _coverPhotoUrl = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pendingPhotoBytes = bytes;
        _isUploadingPhoto = true;
      });

      // Upload to Firebase
      try {
        final url = await FirebaseService.uploadProfileImageBytes(
          userId: user.uid,
          bytes: bytes,
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (url != null && url.isNotEmpty) {
          // Update local state immediately
          setState(() {
            _photoUrl = url;
            _pendingPhotoBytes = null;
            _isUploadingPhoto = false;
            _isClearingBrokenPhoto = false;
          });

          // Sync to Firebase in background
          _syncProfileChanges(photoUrl: url);

          _showMessage('Profile photo updated!', isSuccess: true);
        } else {
          // Upload returned empty
          if (mounted) {
            setState(() {
              _pendingPhotoBytes = null;
              _isUploadingPhoto = false;
            });
          }
          _showMessage('Upload failed. Please try again.');
        }
      } on TimeoutException {
        if (mounted) {
          setState(() {
            _pendingPhotoBytes = null;
            _isUploadingPhoto = false;
          });
        }
        _showMessage('Upload took too long. Please try again.');
      } catch (e) {
        if (mounted) {
          setState(() {
            _pendingPhotoBytes = null;
            _isUploadingPhoto = false;
          });
        }
        _showMessage(_friendlyStorageErrorMessage(e, fallback: 'Photo upload failed.'));
      }
    } catch (e) {
      _showMessage(_friendlyStorageErrorMessage(e, fallback: 'Unable to pick photo.'));
    }
  }

  Future<void> _pickAndUploadCoverPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pendingCoverBytes = bytes;
        _isUploadingCover = true;
      });

      // Upload to Firebase
      try {
        final url = await FirebaseService.uploadCoverImageBytes(
          userId: user.uid,
          bytes: bytes,
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (url != null && url.isNotEmpty) {
          // Update local state immediately
          setState(() {
            _coverPhotoUrl = url;
            _pendingCoverBytes = null;
            _isUploadingCover = false;
            _isClearingBrokenCover = false;
          });

          // Sync to Firebase in background
          _syncProfileChanges(coverUrl: url);

          _showMessage('Background photo updated!', isSuccess: true);
        } else {
          // Upload returned empty
          if (mounted) {
            setState(() {
              _pendingCoverBytes = null;
              _isUploadingCover = false;
            });
          }
          _showMessage('Upload failed. Please try again.');
        }
      } on TimeoutException {
        if (mounted) {
          setState(() {
            _pendingCoverBytes = null;
            _isUploadingCover = false;
          });
        }
        _showMessage('Upload took too long. Please try again.');
      } catch (e) {
        if (mounted) {
          setState(() {
            _pendingCoverBytes = null;
            _isUploadingCover = false;
          });
        }
        _showMessage(_friendlyStorageErrorMessage(e, fallback: 'Background upload failed.'));
      }
    } catch (e) {
      _showMessage(_friendlyStorageErrorMessage(e, fallback: 'Unable to pick background image.'));
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

    setState(() => _isSaving = true);

    try {
      final resolvedPhotoUrl = (_photoUrl != null && _photoUrl!.trim().isNotEmpty)
          ? _photoUrl!.trim()
          : user.photoURL?.trim();

      // Update auth profile
      await AuthService.updateUserProfile(
        fullName: name,
        photoUrl: resolvedPhotoUrl,
      ).timeout(const Duration(seconds: 8));

      // Save to Firestore
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: {
          'fullName': name,
          'role': role,
          if (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
            'photoUrl': resolvedPhotoUrl,
          if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
            'coverPhotoUrl': _coverPhotoUrl,
          'lastUpdated': DateTime.now(),
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _isSaving = false;
        _photoUrl = resolvedPhotoUrl;
      });

      await _showSaveSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Failed to save profile: ${e.toString()}');
    }
  }

  Future<void> _syncProfileChanges({
    String? photoUrl,
    String? coverUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update in background without blocking UI
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: {
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (coverUrl != null) 'coverPhotoUrl': coverUrl,
          'lastUpdated': DateTime.now(),
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Silent fail for background sync
      print('Background sync failed: $e');
    }
  }

  String _friendlyStorageErrorMessage(Object error, {required String fallback}) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('storage/object-not-found') || raw.contains('object-not-found')) {
      return 'The selected image could not be found in storage. Please try uploading again.';
    }
    if (raw.contains('permission-denied')) {
      return 'You do not have permission to access this image. Please sign in again and retry.';
    }
    return fallback;
  }

  void _handleBrokenPhotoUrl() {
    if (_isClearingBrokenPhoto || _photoUrl == null || _photoUrl!.isEmpty) {
      return;
    }
    final fallbackPhoto = FirebaseAuth.instance.currentUser?.photoURL?.trim();
    _isClearingBrokenPhoto = true;
    if (mounted) {
      setState(() {
        _photoUrl = (fallbackPhoto != null && fallbackPhoto.isNotEmpty)
            ? fallbackPhoto
            : null;
      });
    }
    if (fallbackPhoto != null && fallbackPhoto.isNotEmpty) {
      _syncProfileChanges(photoUrl: fallbackPhoto);
    }
  }

  void _handleBrokenCoverUrl() {
    if (_isClearingBrokenCover || _coverPhotoUrl == null || _coverPhotoUrl!.isEmpty) {
      return;
    }
    _isClearingBrokenCover = true;
    if (mounted) {
      setState(() {
        _coverPhotoUrl = null;
      });
    }
    _syncProfileChanges(coverUrl: '');
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showSaveSuccessDialog() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saved Successfully'),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, color: scheme.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Your profile details were saved successfully.'),
            ),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

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
            onPressed: (_isSaving || _isUploadingPhoto || _isUploadingCover)
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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Profile Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  // Background Image
                  GestureDetector(
                    onTap: _isEditing && !_isUploadingCover
                        ? _pickAndUploadCoverPhoto
                        : null,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_pendingCoverBytes != null)
                              Image.memory(
                                _pendingCoverBytes!,
                                fit: BoxFit.cover,
                              )
                            else if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
                              Image.network(
                                _coverPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  _handleBrokenCoverUrl();
                                  return Container(
                                    color: scheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.landscape_outlined,
                                      size: 48,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              )
                            else
                              Center(
                                child: Icon(
                                  Icons.landscape_outlined,
                                  size: 48,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (_isEditing)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: scheme.primary,
                                  child: _isUploadingCover
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile Photo
                  GestureDetector(
                    onTap: _isEditing && !_isUploadingPhoto
                        ? _pickAndUploadProfilePhoto
                        : null,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primaryContainer,
                            border: Border.all(
                              color: scheme.primary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _pendingPhotoBytes != null
                                ? Image.memory(
                                    _pendingPhotoBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                    ? Image.network(
                                        _photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          _handleBrokenPhotoUrl();
                                          return Icon(
                                            Icons.person,
                                            size: 40,
                                            color: scheme.primary,
                                          );
                                        },
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: scheme.primary,
                                      ),
                          ),
                        ),
                        if (_isEditing && !_isUploadingPhoto)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        else if (_isUploadingPhoto)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name and Role
                  Text(
                    _nameController.text.isEmpty ? 'User' : _nameController.text,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _roleController.text.isEmpty
                        ? 'Member'
                        : _roleController.text,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  if (_isEditing) const SizedBox(height: 12),
                  if (_isEditing)
                    Text(
                      'Tap photo or background to change',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Edit Form
          if (_isEditing)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
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
                    TextField(
                      controller: TextEditingController(text: user?.email ?? ''),
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email (Read-only)',
                        prefixIcon: Icon(Icons.email_outlined),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoTile(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      value: _nameController.text.isEmpty
                          ? 'Not set'
                          : _nameController.text,
                    ),
                    const Divider(),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Role',
                      value: _roleController.text.isEmpty
                          ? 'Not set'
                          : _roleController.text,
                    ),
                    const Divider(),
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user?.email ?? 'No email',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
