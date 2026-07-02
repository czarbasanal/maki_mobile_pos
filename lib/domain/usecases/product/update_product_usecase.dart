import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Updates a product.
///
/// Permission tier:
/// - [Permission.editProduct]         — admin: full update including price,
///   cost, costCode.
/// - [Permission.editProductLimited]  — staff: same fields **except**
///   price, cost, costCode. Mirrors the firestore.rules staff branch.
/// - [Permission.editProductNameOnly] — cashier: only name and imageUrl,
///   REBASED onto the freshly-read doc (a concurrent sale mid-edit must not
///   fail — or be overwritten by — the save). Mirrors the firestore.rules
///   cashier branch.
///
/// Returns `restricted-fields` if a staff actor attempts to change a column
/// outside their tier; cashier out-of-tier values are silently dropped by
/// the rebase.
class UpdateProductUseCase {
  static const _restrictedFields = ['price', 'cost', 'costCode'];

  final ProductRepository _repository;
  final ActivityLogger _logger;

  UpdateProductUseCase({
    required ProductRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<ProductEntity>> execute({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    try {
      final hasFullEdit = actor.hasPermission(Permission.editProduct);
      final hasLimitedEdit = actor.hasPermission(Permission.editProductLimited);
      final hasNameOnlyEdit =
          actor.hasPermission(Permission.editProductNameOnly);
      if (!hasFullEdit && !hasLimitedEdit && !hasNameOnlyEdit) {
        // Borrow editProduct as the "what was missing" hint — actor with
        // no edit permission gets the standard PermissionDeniedException.
        assertPermission(actor, Permission.editProduct);
      }

      final original = await _repository.getProductById(product.id);
      if (original == null) {
        return const UseCaseResult.failure(
          message: 'Product not found',
          code: 'not-found',
        );
      }

      final skuChanged = product.sku != original.sku;

      // If only the limited permission is held, reject any change to the
      // restricted columns. SKU is admin-only, so it belongs here too.
      if (!hasFullEdit && hasLimitedEdit) {
        final changed = <String>[];
        if (skuChanged) changed.add('sku');
        if (product.price != original.price) changed.add('price');
        if (product.cost != original.cost) changed.add('cost');
        if (product.costCode != original.costCode) changed.add('costCode');
        if (changed.isNotEmpty) {
          return UseCaseResult.failure(
            message:
                'Staff cannot change ${changed.join(", ")}. Ask an admin to update those fields.',
            code: 'restricted-fields',
          );
        }
      }

      // Cashier (name-only tier) may change only name and imageUrl. Rebase
      // those two onto the FRESH doc instead of comparing the submitted
      // snapshot field-by-field: the form's copy goes stale the moment a
      // sale decrements stock mid-edit, and the old comparison then rejected
      // the save with restricted-fields (2026-07-02 shop bug — the image had
      // already uploaded to Storage but the product doc kept imageUrl null).
      // Any stray value outside the tier is dropped, never written; the
      // firestore.rules cashier denylist stays as defense-in-depth.
      var productToSave = product;
      if (!hasFullEdit && !hasLimitedEdit && hasNameOnlyEdit) {
        productToSave = original.copyWith(
          name: product.name,
          imageUrl: product.imageUrl,
          clearImageUrl: product.imageUrl == null,
        );
      }

      // Admin SKU change: validate format + uniqueness, keep the old SKU
      // scannable (append to barcodes), and count the variation children the
      // repository will re-point to the new SKU (for the audit log).
      var relinkedVariations = 0;
      if (hasFullEdit && skuChanged) {
        if (!SkuGenerator.isValidSku(product.sku)) {
          return const UseCaseResult.failure(
            message:
                'SKU may contain only letters, numbers, and hyphens (max 50 characters).',
            code: 'invalid-sku',
          );
        }
        final duplicate = await _repository.skuExists(
          sku: product.sku,
          excludeProductId: product.id,
        );
        if (duplicate) {
          return UseCaseResult.failure(
            message: 'Another product already uses SKU "${product.sku}".',
            code: 'duplicate-sku',
          );
        }
        final barcodes = List<String>.of(product.barcodes);
        if (!barcodes.contains(original.sku)) barcodes.add(original.sku);
        productToSave = product.copyWith(barcodes: barcodes);

        final group = await _repository.getSkuVariations(original.sku);
        relinkedVariations =
            group.where((p) => p.baseSku == original.sku).length;
      }

      final updated = await _repository.updateProduct(
        product: productToSave,
        updatedBy: actor.id,
        updatedByName: actor.displayName,
      );

      await _logger.log(
        type: ActivityType.inventory,
        action: skuChanged
            ? 'Changed SKU: ${original.sku} → ${updated.sku}'
            : 'Updated product: ${updated.name}',
        details: skuChanged
            ? '${updated.name}${relinkedVariations > 0 ? ' · relinked $relinkedVariations variation(s)' : ''}'
            : 'SKU ${updated.sku}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: updated.id,
        entityType: 'product',
        metadata: skuChanged
            ? {
                'oldSku': original.sku,
                'newSku': updated.sku,
                'relinkedVariations': relinkedVariations,
              }
            : null,
      );

      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update product: $e');
    }
  }

  /// Fields staff are forbidden from changing (exposed for tests + UI hints).
  static List<String> get restrictedFields =>
      List.unmodifiable(_restrictedFields);

}
