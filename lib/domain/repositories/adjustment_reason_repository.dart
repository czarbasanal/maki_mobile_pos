import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed AdjustmentReason operations.
///
/// Backed by the single `adjustment_reasons` collection.
abstract class AdjustmentReasonRepository {
  /// Streams active adjustment reasons ordered A→Z by name.
  Stream<List<AdjustmentReasonEntity>> watchActive();

  /// Streams all adjustment reasons (active + inactive) for admin management.
  Stream<List<AdjustmentReasonEntity>> watchAll();

  /// Reads a single adjustment reason by ID.
  Future<AdjustmentReasonEntity?> getReasonById(String reasonId);

  /// Creates an adjustment reason. Returns the persisted entity with its assigned ID.
  Future<AdjustmentReasonEntity> createAdjustmentReason({
    required AdjustmentReasonEntity reason,
    required String createdBy,
  });

  /// Updates an existing adjustment reason.
  Future<AdjustmentReasonEntity> updateAdjustmentReason({
    required AdjustmentReasonEntity reason,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) or reactivates an adjustment reason.
  Future<void> setActive({
    required String reasonId,
    required bool active,
    required String updatedBy,
  });

  /// Permanently deletes the entry. Orphaned ids left on adjustments are
  /// tolerated — unresolvable ids simply never render; prefer
  /// setActive(false) to merely hide a reason.
  Future<void> deleteReason(String reasonId);

  /// Checks whether an adjustment reason name already exists (exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeReasonId,
  });

  /// Seeds the default adjustment reasons (Delivery, Count correction, etc.)
  /// with a WriteBatch. Called once on app startup or first open after schema migration.
  Future<void> seedDefaults(String createdBy);
}
