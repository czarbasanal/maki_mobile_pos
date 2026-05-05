import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [ExpenseRepository].
class ExpenseRepositoryImpl implements ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _expensesRef =>
      _firestore.collection(FirestoreCollections.expenses);

  // ==================== CREATE ====================

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    try {
      debugPrint('ExpenseRepository: Creating expense');
      final model = ExpenseModel.fromEntity(expense);
      final docRef = await _expensesRef.add(model.toCreateMap());

      final doc = await docRef.get();
      return ExpenseModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create expense: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<ExpenseEntity?> getExpenseById(String expenseId) async {
    try {
      final doc = await _expensesRef.doc(expenseId).get();
      if (!doc.exists) return null;
      return ExpenseModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get expense: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _expensesRef.orderBy('date', descending: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      if (startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get expenses: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<ExpenseEntity>> watchExpenses({int limit = 50}) {
    return _expensesRef
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
            .toList());
  }

  // ==================== UPDATE ====================

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) async {
    try {
      debugPrint('ExpenseRepository: Updating expense ${expense.id}');
      final model = ExpenseModel.fromEntity(expense);
      await _expensesRef.doc(expense.id).update(model.toUpdateMap());

      final doc = await _expensesRef.doc(expense.id).get();
      return ExpenseModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update expense: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== DELETE ====================

  @override
  Future<void> deleteExpense(String expenseId) async {
    try {
      debugPrint('ExpenseRepository: Deleting expense $expenseId');
      await _expensesRef.doc(expenseId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete expense: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== AGGREGATION ====================

  @override
  Future<double> getTotalExpenses({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _expensesRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get total expenses: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, double>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _expensesRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final Map<String, double> categoryTotals = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] as String? ?? 'General';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
      return categoryTotals;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get expenses by category: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

}
