import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Soft-deletes (deactivates) a product. Permission:
/// [Permission.deleteProduct] (admin-only).
class DeactivateProductUseCase {
  final ProductRepository _repository;
  final ActivityLogger _logger;

  DeactivateProductUseCase({
    required ProductRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String productId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteProduct);

      final original = await _repository.getProductById(productId);
      if (original == null) {
        return const UseCaseResult.successVoid();
      }

      await _repository.deactivateProduct(
        productId: productId,
        updatedBy: actor.id,
        updatedByName: actor.displayName,
      );

      await _logger.log(
        type: ActivityType.inventory,
        action: 'Deactivated product: ${original.name}',
        details: 'SKU ${original.sku}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: productId,
        entityType: 'product',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to deactivate product: $e');
    }
  }
}
