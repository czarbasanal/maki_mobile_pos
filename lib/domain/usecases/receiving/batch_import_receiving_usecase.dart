import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';

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
  final ReceivingImportResolver _resolver;
  final CompleteReceivingUseCase _completeReceivingUseCase;

  BatchImportReceivingUseCase({
    required ReceivingRepository receivingRepository,
    required ReceivingImportResolver resolver,
    required CompleteReceivingUseCase completeReceivingUseCase,
  })  : _receivingRepository = receivingRepository,
        _resolver = resolver,
        _completeReceivingUseCase = completeReceivingUseCase;

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

      if (classified.isEmpty) {
        return UseCaseResult.failure(
          message: 'No rows to import.',
        );
      }

      // Steps 2–3: create new products + build items (shared resolver, which
      // also asserts addProduct when new-product rows are present).
      final resolved = await _resolver.resolve(
        actor: actor,
        classified: classified,
        costCodeMapping: costCodeMapping,
        supplierId: supplierId,
        supplierName: supplierName,
      );
      final items = resolved.items;

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
