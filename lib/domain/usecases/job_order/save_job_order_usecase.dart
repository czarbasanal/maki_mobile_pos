import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Persists a job order (parked sale). Permission: [Permission.saveJobOrder].
///
/// The actor's id + name are stamped onto the job order so downstream
/// owner-or-admin checks resolve correctly. Logged as ActivityType.other,
/// matching the web admin — the two surfaces record the same actions.
class SaveJobOrderUseCase {
  final JobOrderRepository _repository;
  final ActivityLogger _logger;

  SaveJobOrderUseCase({
    required JobOrderRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<JobOrderEntity>> execute({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
  }) async {
    try {
      assertPermission(actor, Permission.saveJobOrder);

      final stamped = jobOrder.copyWith(
        createdBy: actor.id,
        createdByName: actor.displayName,
      );
      final created = await _repository.createJobOrder(stamped);

      await _logger.log(
        type: ActivityType.other,
        action: 'Saved job order ${created.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'job_order',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to save job order: $e');
    }
  }
}
