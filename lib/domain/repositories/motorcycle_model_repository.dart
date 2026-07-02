import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Contract for the admin-managed + cashier-addable `motorcycle_models`
/// collection backing the Job Order model picker.
abstract class MotorcycleModelRepository {
  Stream<List<MotorcycleModelEntity>> watchActive();
  Stream<List<MotorcycleModelEntity>> watchAll();
  Future<MotorcycleModelEntity?> getById(String id);
  Future<MotorcycleModelEntity> create({
    required MotorcycleModelEntity model,
    required String createdBy,
  });
  Future<MotorcycleModelEntity> update({
    required MotorcycleModelEntity model,
    required String updatedBy,
  });
  Future<void> setActive({
    required String id,
    required bool active,
    required String updatedBy,
  });

  /// Finds a model by its case-insensitive dedup key (see `normalizedModelKey`).
  /// Returns null when none matches. Used by pick-or-add to reuse a row.
  Future<MotorcycleModelEntity?> findByNormalizedKey(String normalizedKey);
}
