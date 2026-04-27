import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/supplier_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Updates a supplier. Permission: [Permission.editSupplier].
class UpdateSupplierUseCase {
  final SupplierRepository _repository;
  final ActivityLogger _logger;

  UpdateSupplierUseCase({
    required SupplierRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<SupplierEntity>> execute({
    required UserEntity actor,
    required SupplierEntity supplier,
  }) async {
    try {
      assertPermission(actor, Permission.editSupplier);

      final updated = await _repository.updateSupplier(
        supplier: supplier,
        updatedBy: actor.id,
      );

      await _logger.log(
        type: ActivityType.supplier,
        action: 'Updated supplier: ${updated.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: updated.id,
        entityType: 'supplier',
      );

      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update supplier: $e');
    }
  }
}
