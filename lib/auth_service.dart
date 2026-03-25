import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class GoogleSignupPrefill {
  const GoogleSignupPrefill({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _forceLoginAfterSignupKey = 'force_login_after_signup';

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Stream auth state changes
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Sign up with email and password
  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? photoUrl,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(fullName);
        if (photoUrl != null && photoUrl.trim().isNotEmpty) {
          await userCredential.user!.updatePhotoURL(photoUrl.trim());
        }
        await userCredential.user!.reload();
        final refreshedUser = _auth.currentUser ?? userCredential.user!;
        await _saveUserProfile(
          refreshedUser,
          fullName,
          email,
          isNewUser: true,
          photoUrl: photoUrl,
        );
        await _syncToLocalStorage(refreshedUser);
        
        // Mark as new user in local preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isNewUser', true);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('SignUp error: ${e.message}');
      rethrow;
    } catch (e) {
      final message = e.toString();
      final isKnownPigeonCastIssue =
          message.contains('PigeonUserDetails') ||
          message.contains("List<Object> is not a subtype");

      if (isKnownPigeonCastIssue) {
        // Account creation may have completed before a plugin bridge cast error.
        // Attempt a normal sign-in so the user can continue.
        final fallback = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (fallback.user != null) {
          await fallback.user!.updateDisplayName(fullName);
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            await fallback.user!.updatePhotoURL(photoUrl.trim());
          }
          await fallback.user!.reload();
          final refreshedFallback = _auth.currentUser ?? fallback.user!;
          await _saveUserProfile(
            refreshedFallback,
            fullName,
            email,
            isNewUser: true,
            photoUrl: photoUrl,
          );
          await _syncToLocalStorage(refreshedFallback);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isNewUser', true);
          return fallback;
        }
      }

      rethrow;
    }
  }

  // Google sign-up flow with required password setup.
  static Future<void> signUpWithGoogleAndPassword({
    required String password,
  }) async {
    final userCredential = await signInWithGoogle();
    if (userCredential?.user == null) {
      throw Exception('Google sign-up cancelled or failed.');
    }

    await finalizeGoogleSignupWithPassword(password: password);
  }

  // Finalize Google sign-up for an already selected Google account.
  static Future<void> finalizeGoogleSignupWithPassword({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No Google account selected. Please try again.');
    }

    await linkEmailPasswordToCurrentUser(password: password);
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        User syncedUser = userCredential.user!;
        try {
          final profileDoc =
              await _firestore.collection('users').doc(userCredential.user!.uid).get();
          final profile = profileDoc.data();
          final storedName = (profile?['fullName'] as String?)?.trim();
          final storedPhoto = (profile?['photoUrl'] as String?)?.trim();

          if (storedName != null && storedName.isNotEmpty) {
            await userCredential.user!.updateDisplayName(storedName);
          }
          if (storedPhoto != null && storedPhoto.isNotEmpty) {
            await userCredential.user!.updatePhotoURL(storedPhoto);
          }
          await userCredential.user!.reload();
          syncedUser = _auth.currentUser ?? userCredential.user!;
        } catch (_) {
          // Ignore profile sync issues and keep sign-in successful.
        }
        await _syncToLocalStorage(syncedUser);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('SignIn error: ${e.message}');
      rethrow;
    } catch (e) {
      final message = e.toString();
      final isKnownPigeonCastIssue =
          message.contains('PigeonUserDetails') ||
          message.contains("List<Object> is not a subtype");

      if (isKnownPigeonCastIssue) {
        // On some plugin bridge failures, auth can still succeed on Firebase side.
        final current = _auth.currentUser;
        if (current != null &&
            (current.email ?? '').toLowerCase() == email.trim().toLowerCase()) {
          await _syncToLocalStorage(current);
          return null;
        }

        // Retry once to recover from transient bridge sync issues.
        final retryCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (retryCredential.user != null) {
          await _syncToLocalStorage(retryCredential.user!);
          return retryCredential;
        }
      }

      rethrow;
    }
  }

  // Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _saveUserProfile(
          userCredential.user!,
          googleUser.displayName ?? 'Google User',
          googleUser.email,
          photoUrl: userCredential.user!.photoURL,
        );
        await _syncToLocalStorage(userCredential.user!);
      }
      return userCredential;
    } on PlatformException catch (e) {
      final message = e.message ?? '';
      final details = e.details?.toString() ?? '';
      final raw = '$message $details';

      if (raw.contains('ApiException: 10') || raw.contains('ApiException:10')) {
        throw Exception(
          'Google Sign-In is not fully configured for Android (OAuth/SHA). '
          'Add SHA-1 and SHA-256 in Firebase, download updated google-services.json, and rebuild the app.',
        );
      }

      print('Google SignIn platform error: $e');
      rethrow;
    } catch (e) {
      print('Google SignIn error: $e');
      rethrow;
    }
  }

  // Pick a Google account and return email/profile info for sign-up prefill.
  static Future<GoogleSignupPrefill?> pickGoogleEmailForSignup() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final prefill = GoogleSignupPrefill(
        email: googleUser.email,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
      );

      // Keep this flow as email prefill only, not an active Google-auth session.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      return prefill;
    } on PlatformException catch (e) {
      final message = e.message ?? '';
      final details = e.details?.toString() ?? '';
      final raw = '$message $details';

      if (raw.contains('ApiException: 10') || raw.contains('ApiException:10')) {
        throw Exception(
          'Google Sign-In is not fully configured for Android (OAuth/SHA). '
          'Add SHA-1 and SHA-256 in Firebase, download updated google-services.json, and rebuild the app.',
        );
      }

      rethrow;
    }
  }

  // Link email/password to currently signed-in user (useful for Google sign-up flow)
  static Future<void> linkEmailPasswordToCurrentUser({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found. Please try Google sign-up again.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('Google account has no email. Cannot set password.');
    }

    final alreadyLinked = user.providerData.any((p) => p.providerId == 'password');
    if (alreadyLinked) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        return;
      }
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Google sign-out can fail when no Google session exists; continue.
      print('Google SignOut warning: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      print('Firebase SignOut error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userData');
    } catch (e) {
      print('Local SignOut cleanup error: $e');
    }
  }

  static Future<void> _setForceLoginAfterSignup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_forceLoginAfterSignupKey, enabled);
  }

  // Public helper used by UI flows that must always return users to Login.
  static Future<void> markForceLoginAfterSignup() async {
    await _setForceLoginAfterSignup(true);
  }

  // True when this email already supports password sign-in.
  static Future<bool> isEmailRegisteredForPassword(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return methods.contains('password');
    } catch (e) {
      print('Error checking sign-in methods: $e');
      return false;
    }
  }

  // Attempts sign-out and confirms auth state is cleared.
  static Future<bool> ensureSignedOut() async {
    await signOut();
    if (_auth.currentUser == null) {
      return true;
    }

    try {
      await _auth.signOut();
    } catch (e) {
      print('Ensure sign-out retry failed: $e');
    }

    return _auth.currentUser == null;
  }

  // Returns true once, then clears the flag.
  static Future<bool> consumeForceLoginAfterSignup() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldForceLogin = prefs.getBool(_forceLoginAfterSignupKey) ?? false;
    if (shouldForceLogin) {
      await prefs.remove(_forceLoginAfterSignupKey);
      return true;
    }
    return false;
  }

  // Save user profile to Firebase
  static Future<void> _saveUserProfile(
    User user,
    String fullName,
    String email, {
    bool isNewUser = false,
    String? photoUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'uid': user.uid,
          'email': email,
          'fullName': fullName,
            'photoUrl':
              (photoUrl != null && photoUrl.trim().isNotEmpty)
                ? photoUrl.trim()
                : user.photoURL,
          'createdAt': DateTime.now(),
          'lastLogin': DateTime.now(),
          'isNewUser': isNewUser,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  // Sync user data to local storage for offline access
  static Future<void> _syncToLocalStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'lastSync': DateTime.now().toIso8601String(),
      };
      await prefs.setString('userData', jsonEncode(userData));
    } catch (e) {
      print('Error syncing to local storage: $e');
    }
  }

  // Get cached user data from local storage
  static Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('userData');
      if (userDataJson != null) {
        return jsonDecode(userDataJson);
      }
      return null;
    } catch (e) {
      print('Error getting cached user data: $e');
      return null;
    }
  }

  // Reset password
  static Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String fullName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(fullName);
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
        await user.reload();
        final refreshedUser = _auth.currentUser ?? user;
        await _saveUserProfile(
          refreshedUser,
          fullName,
          refreshedUser.email ?? '',
          photoUrl: photoUrl,
        );
        await _syncToLocalStorage(refreshedUser);
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Save app preferences (including dark mode)
  static Future<void> saveAppPreferences({
    required bool darkMode,
    required Map<String, dynamic> appData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', darkMode);
      await prefs.setString('appData', jsonEncode(appData));

      // Also sync to Firebase
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'preferences': {
            'darkMode': darkMode,
            'lastUpdated': DateTime.now(),
          },
        });
      }
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  // Get app preferences
  static Future<Map<String, dynamic>> getAppPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'darkMode': prefs.getBool('darkMode') ?? false,
        'appData': prefs.getString('appData') ?? '{}',
      };
    } catch (e) {
      print('Error getting preferences: $e');
      return {'darkMode': false, 'appData': '{}'};
    }
  }

  // Check if user is new (needs onboarding)
  static Future<bool> isNewUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isNewUser') ?? false;
    } catch (e) {
      print('Error checking if user is new: $e');
      return false;
    }
  }

  // Complete onboarding for user
  static Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isNewUser', false);
      await prefs.setBool('onboardingCompleted', true);

      // Also update in Firebase
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isNewUser': false,
          'onboardingCompleted': true,
          'onboardingCompletedAt': DateTime.now(),
        });
      }
    } catch (e) {
      print('Error completing onboarding: $e');
    }
  }
}
