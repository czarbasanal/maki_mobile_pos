import 'package:uuid/uuid.dart';

import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';

/// Output of resolving classified import rows into receiving items.
///
/// [items] is one [ReceivingItemEntity] per classified row (existing,
/// cost-mismatch, and new). [createdProducts] holds the products materialized
/// for new-product rows, in row order, for caller awareness.
class ResolvedImport {
  final List<ReceivingItemEntity> items;
  final List<ProductEntity> createdProducts;
  const ResolvedImport({required this.items, required this.createdProducts});
}

/// Thrown when resolution cannot complete (e.g. a product fails to create).
/// Subclass of [AppException] so callers can use [UseCaseResult.fromException].
class ReceivingImportException extends AppException {
  const ReceivingImportException({required super.message, super.code});
}

/// Shared resolution step for both CSV import flows (batch screen + inline
/// dialog). Given classified rows it:
///
/// 1. Asserts [Permission.addProduct] only when the classification contains
///    at least one [NewProductRow].
/// 2. Creates a fresh product (quantity 0, costCode-encoded, supplier from
///    caller) for every [NewProductRow]. SKU is honored as-typed, or generated
///    from the name when the row uses the `GENERATE` literal.
/// 3. Builds a [ReceivingItemEntity] for every classified row. Existing and
///    cost-mismatch rows target the stored `existing.id` and pass the new CSV
///    cost — the receiving completion pipeline spawns the SKU variation for the
///    cost-mismatch case (see receiving_repository_impl).
///
/// Throws [ReceivingImportException] if any product creation fails; products
/// already created in this run are left in place (matches existing batch
/// behavior).
class ReceivingImportResolver {
  final CreateProductUseCase _createProductUseCase;
  final Uuid _uuid;

  ReceivingImportResolver({
    required CreateProductUseCase createProductUseCase,
    Uuid? uuid,
  })  : _createProductUseCase = createProductUseCase,
        _uuid = uuid ?? const Uuid();

  Future<ResolvedImport> resolve({
    required UserEntity actor,
    required List<ClassifiedRow> classified,
    required CostCodeEntity costCodeMapping,
    String? supplierId,
    String? supplierName,
  }) async {
    final hasNewProducts = classified.whereType<NewProductRow>().isNotEmpty;
    if (hasNewProducts) {
      assertPermission(actor, Permission.addProduct);
    }

    // Materialize new products, tracked by row number so item-building can
    // join them back without relying on identity.
    final createdByRow = <int, ProductEntity>{};
    final createdProducts = <ProductEntity>[];
    for (final c in classified) {
      if (c is! NewProductRow) continue;
      final row = c.row;
      final sku = row.autoGenerateSku
          ? SkuGenerator.generateForName(row.name)
          : row.sku;

      final candidate = ProductEntity(
        id: '',
        sku: sku,
        name: row.name,
        costCode: costCodeMapping.encode(row.cost),
        cost: row.cost,
        price: row.price,
        quantity: 0,
        reorderLevel: row.reorderLevel,
        unit: row.unit,
        supplierId: supplierId,
        supplierName: supplierName,
        isActive: true,
        createdAt: DateTime.now(),
        category: row.category,
      );

      final result = await _createProductUseCase.execute(
        actor: actor,
        product: candidate,
      );
      if (!result.success || result.data == null) {
        throw ReceivingImportException(
          message:
              'Could not create product for row ${row.rowNumber} (${row.name}): '
              '${result.errorMessage ?? "unknown error"}',
        );
      }
      createdByRow[row.rowNumber] = result.data!;
      createdProducts.add(result.data!);
    }

    final items = <ReceivingItemEntity>[];
    for (final c in classified) {
      final row = c.row;
      final ProductEntity targetProduct;
      if (c is ExistingMatchRow) {
        targetProduct = c.existing;
      } else if (c is CostMismatchRow) {
        targetProduct = c.existing;
      } else if (c is NewProductRow) {
        targetProduct = createdByRow[row.rowNumber]!;
      } else {
        throw StateError('Unknown ClassifiedRow subtype: ${c.runtimeType}');
      }

      items.add(ReceivingItemEntity(
        id: _uuid.v4(),
        productId: targetProduct.id,
        sku: targetProduct.sku,
        name: targetProduct.name,
        quantity: row.quantity,
        unit: row.unit.isEmpty ? targetProduct.unit : row.unit,
        unitCost: row.cost,
        costCode: costCodeMapping.encode(row.cost),
      ));
    }

    return ResolvedImport(items: items, createdProducts: createdProducts);
  }
}
