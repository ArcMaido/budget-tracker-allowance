import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }

  // ==================== AUTHENTICATION ====================

  // Sign up with email and password
  static Future<UserCredential?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Reset password
  static Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
    }
  }

  // ==================== FIRESTORE ====================

  // Save user profile
  static Future<void> saveUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Save transaction
  static Future<void> saveTransaction({
    required String userId,
    required Map<String, dynamic> transactionData,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add(transactionData);
    } catch (e) {
      print('Error saving transaction: $e');
      rethrow;
    }
  }

  // Get transactions
  static Stream<QuerySnapshot> getTransactions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Save category
  static Future<void> saveCategory({
    required String userId,
    required String categoryName,
    required double budget,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryName)
          .set({'name': categoryName, 'budget': budget});
    } catch (e) {
      print('Error saving category: $e');
      rethrow;
    }
  }

  // Get categories
  static Stream<QuerySnapshot> getCategories(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .snapshots();
  }

  // Delete category
  static Future<void> deleteCategory({
    required String userId,
    required String categoryName,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryName)
          .delete();
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  // ==================== STORAGE ====================

  static Future<String?> _uploadImageWithRetry({
    required String userId,
    required String filePath,
    required String folder,
    required String filePrefix,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Selected image file was not found.');
    }

    FirebaseException? lastFirebaseError;
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage
            .ref()
            .child('users/$userId/$folder/${filePrefix}_$stamp.jpg');
        final task = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await task.timeout(const Duration(seconds: 60));
        final url = await ref.getDownloadURL();
        if (url.trim().isNotEmpty) {
          return url.trim();
        }
      } on FirebaseException catch (e) {
        lastFirebaseError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 450 * attempt));
        }
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 450 * attempt));
        }
      }
    }

    if (lastFirebaseError != null) {
      throw Exception(
        'storage/${lastFirebaseError.code}: ${lastFirebaseError.message ?? 'Upload failed'}',
      );
    }

    throw Exception('Upload failed${lastError != null ? ': $lastError' : ''}');
  }

  static Future<String?> _uploadImageBytesWithRetry({
    required String userId,
    required Uint8List bytes,
    required String folder,
    required String filePrefix,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Image bytes are empty.');
    }

    FirebaseException? lastFirebaseError;
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage
            .ref()
            .child('users/$userId/$folder/${filePrefix}_$stamp.jpg');
        final task = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await task.timeout(const Duration(seconds: 60));
        final url = await ref.getDownloadURL();
        if (url.trim().isNotEmpty) {
          return url.trim();
        }
      } on FirebaseException catch (e) {
        lastFirebaseError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 450 * attempt));
        }
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 450 * attempt));
        }
      }
    }

    if (lastFirebaseError != null) {
      throw Exception(
        'storage/${lastFirebaseError.code}: ${lastFirebaseError.message ?? 'Upload failed'}',
      );
    }

    throw Exception('Upload failed${lastError != null ? ': $lastError' : ''}');
  }

  // Upload profile image
  static Future<String?> uploadProfileImage({
    required String userId,
    required String filePath,
  }) async {
    try {
      return await _uploadImageWithRetry(
        userId: userId,
        filePath: filePath,
        folder: 'profile_images',
        filePrefix: 'profile',
      );
    } on FirebaseException catch (e) {
      throw Exception('storage/${e.code}: ${e.message ?? 'Upload failed'}');
    } catch (e) {
      print('Error uploading profile image: $e');
      throw Exception('Upload failed: $e');
    }
  }

  static Future<String?> uploadProfileImageBytes({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      return await _uploadImageBytesWithRetry(
        userId: userId,
        bytes: bytes,
        folder: 'profile_images',
        filePrefix: 'profile',
      );
    } on FirebaseException catch (e) {
      throw Exception('storage/${e.code}: ${e.message ?? 'Upload failed'}');
    } catch (e) {
      print('Error uploading profile image bytes: $e');
      throw Exception('Upload failed: $e');
    }
  }

  static Future<String?> uploadCoverImage({
    required String userId,
    required String filePath,
  }) async {
    try {
      return await _uploadImageWithRetry(
        userId: userId,
        filePath: filePath,
        folder: 'cover_images',
        filePrefix: 'cover',
      );
    } on FirebaseException catch (e) {
      throw Exception('storage/${e.code}: ${e.message ?? 'Upload failed'}');
    } catch (e) {
      print('Error uploading cover image: $e');
      throw Exception('Upload failed: $e');
    }
  }

  static Future<String?> uploadCoverImageBytes({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      return await _uploadImageBytesWithRetry(
        userId: userId,
        bytes: bytes,
        folder: 'cover_images',
        filePrefix: 'cover',
      );
    } on FirebaseException catch (e) {
      throw Exception('storage/${e.code}: ${e.message ?? 'Upload failed'}');
    } catch (e) {
      print('Error uploading cover image bytes: $e');
      throw Exception('Upload failed: $e');
    }
  }

  // Delete file from storage
  static Future<void> deleteFile(String filePath) async {
    try {
      await _storage.ref(filePath).delete();
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
}
