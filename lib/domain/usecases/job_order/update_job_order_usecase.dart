import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Updates an existing job order (Job Order).
///
/// Permission: [Permission.editJobOrder]. Additionally, only the original
/// creator OR an admin may edit a ticket (mirrors the firestore.rules
/// owner-or-admin rule; the rules carry one extra exception this use case
/// doesn't need — bill-out marks any ticket converted via the repository
/// directly). A converted ticket is frozen. Returns `not-found` if the
/// job order is gone, `forbidden-not-owner` for non-owner non-admin edits, and
/// `already-converted` for edits to a billed-out ticket.
class UpdateJobOrderUseCase {
  final JobOrderRepository _repository;
  final ActivityLogger _logger;

  UpdateJobOrderUseCase({
    required JobOrderRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<JobOrderEntity>> execute({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
  }) async {
    try {
      assertPermission(actor, Permission.editJobOrder);

      final original = await _repository.getJobOrderById(jobOrder.id);
      if (original == null) {
        return const UseCaseResult.failure(
          message: 'Job Order not found',
          code: 'not-found',
        );
      }

      // A billed-out ticket is frozen (mirrors the firestore.rules guard).
      // Without this, an editor holding a stale copy could write
      // isConverted:false back over a converted ticket and let it be billed
      // out a second time.
      if (original.isConverted) {
        return const UseCaseResult.failure(
          message: 'This job order was already billed out',
          code: 'already-converted',
        );
      }

      final isOwner = original.createdBy == actor.id;
      final isAdmin = actor.role == UserRole.admin;
      if (!isOwner && !isAdmin) {
        return const UseCaseResult.failure(
          message: 'You can only edit job orders you created',
          code: 'forbidden-not-owner',
        );
      }

      final updated = await _repository.updateJobOrder(
        jobOrder: jobOrder,
        updatedBy: actor.id,
      );

      await _logger.log(
        type: ActivityType.other,
        action: 'Saved job order ${updated.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: updated.id,
        entityType: 'job_order',
      );

      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update job order: $e');
    }
  }
}
