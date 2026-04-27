import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a new expense after asserting the actor's permission and
/// emitting an audit-log entry.
class CreateExpenseUseCase {
  final ExpenseRepository _repository;
  final ActivityLogger _logger;

  CreateExpenseUseCase({
    required ExpenseRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<ExpenseEntity>> execute({
    required UserEntity actor,
    required ExpenseEntity expense,
  }) async {
    try {
      assertPermission(actor, Permission.addExpense);

      final stamped = expense.copyWith(
        createdBy: actor.id,
        createdByName: actor.displayName,
      );
      final created = await _repository.createExpense(stamped);

      await _logger.log(
        type: ActivityType.expense,
        action: 'Created expense: ${created.description}',
        details: '${created.category} • ₱${created.amount.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'expense',
        metadata: {
          'amount': created.amount,
          'category': created.category,
        },
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create expense: $e');
    }
  }
}
