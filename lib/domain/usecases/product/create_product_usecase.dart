import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/cost_code_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a product. Permission: [Permission.addProduct] (admin + staff).
///
/// Admins enter a numeric cost directly. Non-admins (staff) enter a cost
/// CODE; this use case decodes it to the real cost so the numeric value never
/// lives in the UI layer.
class CreateProductUseCase {
  final ProductRepository _repository;
  final ActivityLogger _logger;
  final CostCodeRepository _costCodeRepository;

  CreateProductUseCase({
    required ProductRepository repository,
    required ActivityLogger logger,
    required CostCodeRepository costCodeRepository,
  })  : _repository = repository,
        _logger = logger,
        _costCodeRepository = costCodeRepository;

  Future<UseCaseResult<ProductEntity>> execute({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    try {
      assertPermission(actor, Permission.addProduct);

      var toCreate = product;

      // Non-admin actors submit a cost CODE, not a number. Decode it here so
      // the numeric cost is derived authoritatively in logic, not the UI.
      if (actor.role != UserRole.admin) {
        final mapping = await _costCodeRepository.getCostCodeMapping();
        final decoded = mapping.decode(product.costCode);
        if (decoded == null) {
          return const UseCaseResult.failure(
            message: 'Invalid cost code',
            code: 'invalid-cost-code',
          );
        }
        toCreate = product.copyWith(
          cost: decoded,
          costCode: mapping.encode(decoded),
        );
      }

      final created = await _repository.createProduct(
        product: toCreate,
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
