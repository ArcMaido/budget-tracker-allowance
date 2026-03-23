import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== TRANSACTIONS ====================

  // Save transaction to Firebase
  static Future<void> saveTransaction({
    required String category,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'category': category,
        'amount': amount,
        'date': date,
        'description': description ?? '',
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      print('Error saving transaction: $e');
    }
  }

  // Get transactions stream (real-time updates)
  static Stream<QuerySnapshot> getTransactionsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get transactions for specific date range
  static Future<List<Map<String, dynamic>>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate.add(const Duration(days: 1)))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  // Delete transaction
  static Future<void> deleteTransaction(String transactionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      print('Error deleting transaction: $e');
    }
  }

  // ==================== CATEGORIES & BUDGETS ====================

  // Save category budget
  static Future<void> saveCategory({
    required String categoryName,
    required double budget,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryName)
          .set({
        'name': categoryName,
        'budget': budget,
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving category: $e');
    }
  }

  // Get categories stream
  static Stream<QuerySnapshot> getCategoriesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .snapshots();
  }

  // Get all categories
  static Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Delete category
  static Future<void> deleteCategory(String categoryName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryName)
          .delete();
    } catch (e) {
      print('Error deleting category: $e');
    }
  }

  // ==================== MONTHLY ALLOWANCE ====================

  // Save monthly allowance
  static Future<void> setMonthlyAllowance(double amount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'monthlyAllowance': amount,
        'lastUpdated': DateTime.now(),
      });
    } catch (e) {
      print('Error setting allowance: $e');
    }
  }

  // Get monthly allowance
  static Future<double> getMonthlyAllowance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc =
          await _firestore.collection('users').doc(user.uid).get();
      return (doc.data()?['monthlyAllowance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      print('Error getting allowance: $e');
      return 0;
    }
  }

  // ==================== UTILITY ====================

  // Get total spending for month
  static Future<double> getTotalSpentThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);

      final transactions = await getTransactionsByDateRange(
        startOfMonth,
        endOfMonth,
      );

      double total = 0;
      for (var tx in transactions) {
        total += (tx['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      print('Error calculating spending: $e');
      return 0;
    }
  }

  // Get spending for category
  static Future<double> getSpentForCategory(
    String category,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions = await getTransactionsByDateRange(startDate, endDate);
      double total = 0;
      for (var tx in transactions) {
        if (tx['category'] == category) {
          total += (tx['amount'] as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      print('Error calculating category spending: $e');
      return 0;
    }
  }
}
