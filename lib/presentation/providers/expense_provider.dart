import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/create_expense_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/delete_expense_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/update_expense_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE-CASE PROVIDERS ====================

final createExpenseUseCaseProvider = Provider<CreateExpenseUseCase>((ref) {
  return CreateExpenseUseCase(
    repository: ref.watch(expenseRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateExpenseUseCaseProvider = Provider<UpdateExpenseUseCase>((ref) {
  return UpdateExpenseUseCase(
    repository: ref.watch(expenseRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final deleteExpenseUseCaseProvider = Provider<DeleteExpenseUseCase>((ref) {
  return DeleteExpenseUseCase(
    repository: ref.watch(expenseRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== EXPENSE QUERIES ====================

/// Provides all expenses as a real-time stream.
final expensesProvider = StreamProvider<List<ExpenseEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(expenseRepositoryProvider).watchExpenses();
  });
});

/// Provides a single expense by ID.
final expenseByIdProvider =
    FutureProvider.family<ExpenseEntity?, String>((ref, expenseId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpenseById(expenseId);
});

/// Provides expenses filtered by date range.
final expensesByDateRangeProvider =
    FutureProvider.family<List<ExpenseEntity>, ExpenseDateRangeParams>(
        (ref, params) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpenses(
    startDate: params.startDate,
    endDate: params.endDate,
    category: params.category,
  );
});

/// Provides total expenses for a date range.
final totalExpensesProvider =
    FutureProvider.family<double, ExpenseDateRangeParams>((ref, params) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getTotalExpenses(
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Provides expenses grouped by category.
final expensesByCategoryProvider =
    FutureProvider.family<Map<String, double>, ExpenseDateRangeParams>(
        (ref, params) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByCategory(
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Provides all unique expense categories.
final expenseCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getCategories();
});

// ==================== EXPENSE OPERATIONS ====================

/// Notifier for expense CRUD operations.
///
/// All mutations route through use-cases, which assert permissions and emit
/// audit logs. The current user is resolved from [currentUserProvider]; callers
/// don't need to pass it.
class ExpenseOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ExpenseOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  /// Creates a new expense. Returns the created expense, or null on failure.
  Future<ExpenseEntity?> createExpense({
    required ExpenseEntity expense,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(createExpenseUseCaseProvider)
          .execute(actor: actor, expense: expense);

      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(expensesProvider);
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to create expense',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing expense.
  Future<ExpenseEntity?> updateExpense({
    required ExpenseEntity expense,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(updateExpenseUseCaseProvider)
          .execute(actor: actor, expense: expense);

      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(expensesProvider);
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to update expense',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Deletes an expense. Returns true on success.
  Future<bool> deleteExpense(String expenseId) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(deleteExpenseUseCaseProvider)
          .execute(actor: actor, expenseId: expenseId);

      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(expensesProvider);
        return true;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to delete expense',
        StackTrace.current,
      );
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for expense operations.
final expenseOperationsProvider =
    StateNotifierProvider<ExpenseOperationsNotifier, AsyncValue<void>>((ref) {
  return ExpenseOperationsNotifier(ref);
});

// ==================== PARAMETER CLASSES ====================

/// Parameters for date-range expense queries.
class ExpenseDateRangeParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? category;

  const ExpenseDateRangeParams({
    required this.startDate,
    required this.endDate,
    this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseDateRangeParams &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          category == other.category;

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode ^ category.hashCode;
}
