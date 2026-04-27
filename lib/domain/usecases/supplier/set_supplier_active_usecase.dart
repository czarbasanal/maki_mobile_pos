import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Activates or deactivates a supplier (soft delete / restore).
/// Permission: [Permission.deleteSupplier] for deactivate,
/// [Permission.editSupplier] for reactivate.
class SetSupplierActiveUseCase {
  final SupplierRepository _repository;
  final ActivityLogger _logger;

  SetSupplierActiveUseCase({
    required SupplierRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String supplierId,
    required bool active,
  }) async {
    try {
      assertPermission(
        actor,
        active ? Permission.editSupplier : Permission.deleteSupplier,
      );

      if (active) {
        await _repository.reactivateSupplier(
          supplierId: supplierId,
          updatedBy: actor.id,
        );
      } else {
        await _repository.deactivateSupplier(
          supplierId: supplierId,
          updatedBy: actor.id,
        );
      }

      await _logger.log(
        type: ActivityType.supplier,
        action: active
            ? 'Reactivated supplier $supplierId'
            : 'Deactivated supplier $supplierId',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: supplierId,
        entityType: 'supplier',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to change supplier status: $e');
    }
  }
}
