import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Adds cash to the petty-cash fund. Permission: [Permission.managePettyCash].
class CashInUseCase {
  final PettyCashRepository _repository;
  final ActivityLogger _logger;

  CashInUseCase({
    required PettyCashRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<PettyCashEntity>> execute({
    required UserEntity actor,
    required double amount,
    required String description,
    String? notes,
  }) async {
    try {
      assertPermission(actor, Permission.managePettyCash);
      if (amount <= 0) {
        return const UseCaseResult.failure(
          message: 'Amount must be greater than zero',
          code: 'invalid-amount',
        );
      }

      final record = await _repository.cashIn(
        amount: amount,
        description: description,
        createdBy: actor.id,
        createdByName: actor.displayName,
        notes: notes,
      );

      await _logger.log(
        type: ActivityType.pettyCash,
        action: 'Cash in: $description',
        details: '+₱${amount.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: record.id,
        entityType: 'petty_cash',
        metadata: {'amount': amount, 'direction': 'in'},
      );

      return UseCaseResult.successData(record);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to record cash in: $e');
    }
  }
}
