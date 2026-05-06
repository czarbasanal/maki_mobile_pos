import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a product. Permission: [Permission.addProduct] (admin-only).
class CreateProductUseCase {
  final ProductRepository _repository;
  final ActivityLogger _logger;

  CreateProductUseCase({
    required ProductRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<ProductEntity>> execute({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    try {
      assertPermission(actor, Permission.addProduct);

      final created = await _repository.createProduct(
        product: product,
        createdBy: actor.id,
        createdByName: actor.displayName,
      );

      await _logger.log(
        type: ActivityType.inventory,
        action: 'Created product: ${created.name}',
        details: 'SKU ${created.sku} • ₱${created.price.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'product',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create product: $e');
    }
  }
}
