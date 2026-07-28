import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Persists a job order (parked sale). Permission: [Permission.saveJobOrder].
///
/// The actor's id + name are stamped onto the job order so downstream
/// owner-or-admin checks resolve correctly. Job Orders are transient working
/// state — no activity log is written.
class SaveJobOrderUseCase {
  final JobOrderRepository _repository;

  SaveJobOrderUseCase({required JobOrderRepository repository})
      : _repository = repository;

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
      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to save job order: $e');
    }
  }
}
