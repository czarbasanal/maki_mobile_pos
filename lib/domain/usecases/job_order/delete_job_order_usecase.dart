import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Deletes a job order.
///
/// Permission: [Permission.deleteJobOrder]. Owner-or-admin guard mirrors the
/// firestore.rules rule. Idempotent on a missing job order (succeeds with
/// nothing to delete).
class DeleteJobOrderUseCase {
  final JobOrderRepository _repository;
  final ActivityLogger _logger;

  DeleteJobOrderUseCase({
    required JobOrderRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String jobOrderId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteJobOrder);

      final original = await _repository.getJobOrderById(jobOrderId);
      if (original == null) {
        // Already gone — succeed silently rather than surface a 404 the
        // caller has to handle.
        return const UseCaseResult.successVoid();
      }

      final isOwner = original.createdBy == actor.id;
      final isAdmin = actor.role == UserRole.admin;
      if (!isOwner && !isAdmin) {
        return const UseCaseResult.failure(
          message: 'You can only delete job orders you created',
          code: 'forbidden-not-owner',
        );
      }

      await _repository.deleteJobOrder(jobOrderId);

      // A deleted job order is a pending ticket that vanished — the audit
      // trail is how a missing ticket gets explained. Matches web.
      await _logger.log(
        type: ActivityType.other,
        action: 'Deleted job order ${original.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: jobOrderId,
        entityType: 'job_order',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete job order: $e');
    }
  }
}
