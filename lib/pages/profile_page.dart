import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
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
        final lastSignupName = await AuthService.readLastSignupFullName(user.email!);
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
      String? photoUrl = (profile?['photoUrl'] as String?)?.trim();
      if (photoUrl == null || photoUrl.isEmpty) {
        photoUrl = user.photoURL?.trim();
      }
      if ((photoUrl == null || photoUrl.isEmpty) && (user.email ?? '').trim().isNotEmpty) {
        final cachedPhoto = await AuthService.readLastSignupPhotoUrl(user.email!);
        if (cachedPhoto != null && cachedPhoto.isNotEmpty) {
          photoUrl = cachedPhoto;
          unawaited(
            FirebaseService.saveUserProfile(
              userId: user.uid,
              userData: {
                'photoUrl': cachedPhoto,
                'lastUpdated': DateTime.now(),
              },
            ),
          );
          unawaited(user.updatePhotoURL(cachedPhoto));
        }
      }
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
      return 'Image upload requires Firebase Storage billing to be enabled. Activation is enough; you are not charged unless usage exceeds free limits.';
    }
    if (raw.contains('permission-denied')) {
      return 'You do not have permission to access this image. Please sign in again and retry.';
    }
    return fallback;
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
                    Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: scheme.primaryContainer,
                        backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? NetworkImage(_photoUrl!)
                            : null,
                        child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? null
                            : Icon(
                                Icons.person_outline,
                                size: 30,
                                color: scheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
