import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Updates an existing expense (admin-only) and emits an audit log.
class UpdateExpenseUseCase {
  final ExpenseRepository _repository;
  final ActivityLogger _logger;

  UpdateExpenseUseCase({
    required ExpenseRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<ExpenseEntity>> execute({
    required UserEntity actor,
    required ExpenseEntity expense,
  }) async {
    try {
      assertPermission(actor, Permission.editExpense);

      final stamped = expense.copyWith(
        updatedBy: actor.id,
        updatedAt: DateTime.now(),
      );
      final updated = await _repository.updateExpense(stamped);

      await _logger.log(
        type: ActivityType.expense,
        action: 'Updated expense: ${updated.description}',
        details: '${updated.category} • ₱${updated.amount.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: updated.id,
        entityType: 'expense',
        metadata: {
          'amount': updated.amount,
          'category': updated.category,
        },
      );

      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update expense: $e');
    }
  }
}
