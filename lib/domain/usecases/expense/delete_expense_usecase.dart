import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Deletes an expense (admin-only) and emits an audit log.
class DeleteExpenseUseCase {
  final ExpenseRepository _repository;
  final ActivityLogger _logger;

  DeleteExpenseUseCase({
    required ExpenseRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String expenseId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteExpense);

      // Capture for audit before deletion.
      final existing = await _repository.getExpenseById(expenseId);
      await _repository.deleteExpense(expenseId);

      await _logger.log(
        type: ActivityType.expense,
        action: existing == null
            ? 'Deleted expense $expenseId'
            : 'Deleted expense: ${existing.description}',
        details: existing == null
            ? null
            : '${existing.category} • ₱${existing.amount.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: expenseId,
        entityType: 'expense',
        metadata: existing == null
            ? null
            : {
                'amount': existing.amount,
                'category': existing.category,
              },
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete expense: $e');
    }
  }
}
