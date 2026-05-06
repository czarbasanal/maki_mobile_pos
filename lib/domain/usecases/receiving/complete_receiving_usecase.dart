import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Completes a receiving (commits stock to inventory) and emits an audit log.
///
/// Permission: [Permission.receiveStock]. The repository call already updates
/// products and writes price history; this use-case adds the permission check
/// and the audit-log entry that was previously missing.
class CompleteReceivingUseCase {
  final ReceivingRepository _repository;
  final ActivityLogger _logger;

  CompleteReceivingUseCase({
    required ReceivingRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<ReceivingEntity>> execute({
    required UserEntity actor,
    required String receivingId,
  }) async {
    try {
      assertPermission(actor, Permission.receiveStock);

      final completed = await _repository.completeReceiving(
        receivingId: receivingId,
        completedBy: actor.id,
        completedByName: actor.displayName,
      );

      await _logger.logReceiving(
        user: actor,
        receivingId: completed.id,
        referenceNumber: completed.referenceNumber,
        itemCount: completed.items.length,
        totalCost: completed.totalCost,
        supplierName: completed.supplierName,
      );

      return UseCaseResult.successData(completed);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to complete receiving: $e');
    }
  }
}
