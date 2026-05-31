import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed Mechanic operations.
///
/// Backed by the single `mechanics` collection.
abstract class MechanicRepository {
  /// Streams active mechanics ordered A→Z by name.
  Stream<List<MechanicEntity>> watchActive();

  /// Streams all mechanics (active + inactive) for admin management.
  Stream<List<MechanicEntity>> watchAll();

  /// Reads a single mechanic by ID.
  Future<MechanicEntity?> getMechanicById(String mechanicId);

  /// Creates a mechanic. Returns the persisted entity with its assigned ID.
  Future<MechanicEntity> createMechanic({
    required MechanicEntity mechanic,
    required String createdBy,
  });

  /// Updates an existing mechanic.
  Future<MechanicEntity> updateMechanic({
    required MechanicEntity mechanic,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) or reactivates a mechanic.
  Future<void> setActive({
    required String mechanicId,
    required bool active,
    required String updatedBy,
  });

  /// Checks whether a mechanic name already exists (exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeMechanicId,
  });
}
