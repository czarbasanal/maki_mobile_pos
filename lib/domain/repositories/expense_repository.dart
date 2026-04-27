import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Expense operations.
abstract class ExpenseRepository {
  /// Creates a new expense.
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

  /// Gets total expenses for a date range.
  Future<double> getTotalExpenses({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets expenses grouped by category for a date range.
  Future<Map<String, double>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets all unique expense categories.
  Future<List<String>> getCategories();
}
