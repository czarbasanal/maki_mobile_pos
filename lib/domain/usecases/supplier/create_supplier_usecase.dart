import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/supplier_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a supplier. Permission: [Permission.addSupplier].
class CreateSupplierUseCase {
  final SupplierRepository _repository;
  final ActivityLogger _logger;

  CreateSupplierUseCase({
    required SupplierRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<SupplierEntity>> execute({
    required UserEntity actor,
    required SupplierEntity supplier,
  }) async {
    try {
      assertPermission(actor, Permission.addSupplier);

      final created = await _repository.createSupplier(
        supplier: supplier,
        createdBy: actor.id,
      );

      await _logger.log(
        type: ActivityType.supplier,
        action: 'Created supplier: ${created.name}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'supplier',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create supplier: $e');
    }
  }
}
