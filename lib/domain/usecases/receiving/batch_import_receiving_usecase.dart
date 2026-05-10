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
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';

/// Orchestrates the receiving batch-import flow.
///
/// Given a list of [ClassifiedRow]s and a target supplier, this use case:
///
/// 1. Validates the actor's permissions. `bulkReceive` + `receiveStock`
///    are required for everyone; `addProduct` is only required when the
///    classification contains at least one [NewProductRow].
/// 2. Creates a fresh product (via [CreateProductUseCase]) for every
///    `NewProductRow`. The product starts at quantity 0; the receiving
///    line will add stock during completion. SKU is honored as-typed,
///    or generated from the name when the row uses the `GENERATE` literal.
/// 3. Builds [ReceivingItemEntity]s for every classified row. Existing
///    products receive against their stored `productId`; new products
///    receive against the just-created id. Cost-mismatch rows pass the
///    new (CSV) cost — the receiving completion pipeline already spawns
///    a SKU variation for that case (see receiving_repository_impl).
/// 4. Persists a draft receiving with all items.
/// 5. Calls [CompleteReceivingUseCase] which adjusts stock, emits price
///    history, and writes the audit log.
class BatchImportReceivingUseCase {
  final ReceivingRepository _receivingRepository;
  final CreateProductUseCase _createProductUseCase;
  final CompleteReceivingUseCase _completeReceivingUseCase;
  final Uuid _uuid;

  BatchImportReceivingUseCase({
    required ReceivingRepository receivingRepository,
    required CreateProductUseCase createProductUseCase,
    required CompleteReceivingUseCase completeReceivingUseCase,
    Uuid? uuid,
  })  : _receivingRepository = receivingRepository,
        _createProductUseCase = createProductUseCase,
        _completeReceivingUseCase = completeReceivingUseCase,
        _uuid = uuid ?? const Uuid();

  /// Runs the import. Failure modes:
  /// - `Permission.bulkReceive`/`receiveStock` missing → permission error.
  /// - Any new-product row + actor lacking `Permission.addProduct` →
  ///   permission error (no products created, no receiving written).
  /// - Any product creation fails → returns the underlying error. Already-
  ///   created products in this run are left in place (admin can keep or
  ///   deactivate them) — the receiving is NOT created.
  /// - Receiving creation/completion fails → the underlying error
  ///   surfaces; products created in step 2 remain in inventory.
  Future<UseCaseResult<ReceivingEntity>> execute({
    required UserEntity actor,
    required List<ClassifiedRow> classified,
    required CostCodeEntity costCodeMapping,
    String? supplierId,
    String? supplierName,
    String? notes,
  }) async {
    try {
      assertPermission(actor, Permission.bulkReceive);
      assertPermission(actor, Permission.receiveStock);

      final hasNewProducts = classified.whereType<NewProductRow>().isNotEmpty;
      if (hasNewProducts) {
        assertPermission(actor, Permission.addProduct);
      }

      if (classified.isEmpty) {
        return UseCaseResult.failure(
          message: 'No rows to import.',
        );
      }

      // Step 2: materialize new products. Track by row number so step 3
      // can join them back without relying on identity.
      final createdByRow = <int, ProductEntity>{};
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
          return UseCaseResult.failure(
            message:
                'Could not create product for row ${row.rowNumber} (${row.name}): '
                '${result.errorMessage ?? "unknown error"}',
          );
        }
        createdByRow[row.rowNumber] = result.data!;
      }

      // Step 3: build receiving items.
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
          // Defensive — classification base class is open in case more
          // subclasses are added; an unknown subclass should fail loudly.
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

      // Step 4: persist draft.
      final referenceNumber =
          await _receivingRepository.generateReferenceNumber();
      final totalCost = items.fold<double>(
        0,
        (sum, i) => sum + i.unitCost * i.quantity,
      );
      final totalQuantity = items.fold<int>(0, (sum, i) => sum + i.quantity);

      final draft = ReceivingEntity(
        id: '',
        referenceNumber: referenceNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        items: items,
        totalCost: totalCost,
        totalQuantity: totalQuantity,
        status: ReceivingStatus.draft,
        notes: notes,
        createdAt: DateTime.now(),
        createdBy: actor.id,
        createdByName: actor.displayName,
      );

      final saved = await _receivingRepository.createReceiving(draft);

      // Step 5: complete the receiving (stock + price history + audit).
      return await _completeReceivingUseCase.execute(
        actor: actor,
        receivingId: saved.id,
      );
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Batch import failed: $e');
    }
  }
}
