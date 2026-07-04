import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Expense operations.
abstract class ExpenseRepository {
  /// Pre-allocates a document id, letting callers upload ancillary files
  /// (receipt photo) BEFORE creating the document — the expense then lands
  /// in one write with the file URL already on it.
  String newExpenseId();

  /// Creates a new expense. A non-empty [ExpenseEntity.id] (from
  /// [newExpenseId]) is honored; an empty id lets Firestore generate one.
  Future<ExpenseEntity> createExpense(ExpenseEntity expense);

  /// Gets an expense by ID.
  Future<ExpenseEntity?> getExpenseById(String expenseId);

  /// Gets expenses with optional filters.
  Future<List<ExpenseEntity>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  /// Streams expenses for real-time updates.
  Stream<List<ExpenseEntity>> watchExpenses({int limit = 50});

  /// Updates an expense.
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense);

  /// Deletes an expense.
  Future<void> deleteExpense(String expenseId);

  /// Gets total expenses for a date range, optionally scoped to one category.
  Future<double> getTotalExpenses({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  });

  /// Gets expenses grouped by category for a date range. When [category] is
  /// non-null, the result contains only that bucket (useful for category-
  /// filtered views that still want the breakdown shape).
  Future<Map<String, double>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  });
}
