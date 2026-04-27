import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Performs the end-of-day petty-cash cut-off.
/// Permission: [Permission.performCutOff] (admin-only).
class PerformCutOffUseCase {
  final PettyCashRepository _repository;
  final ActivityLogger _logger;

  PerformCutOffUseCase({
    required PettyCashRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<PettyCashEntity>> execute({
    required UserEntity actor,
    String? notes,
  }) async {
    try {
      assertPermission(actor, Permission.performCutOff);

      final balanceBefore = await _repository.getCurrentBalance();
      final record = await _repository.performCutOff(
        createdBy: actor.id,
        createdByName: actor.displayName,
        notes: notes,
      );

      await _logger.log(
        type: ActivityType.pettyCashCutOff,
        action: 'Performed petty cash cut-off',
        details: 'Closed at ₱${balanceBefore.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: record.id,
        entityType: 'petty_cash',
        metadata: {'closingBalance': balanceBefore, 'notes': notes},
      );

      return UseCaseResult.successData(record);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to perform cut-off: $e');
    }
  }
}
