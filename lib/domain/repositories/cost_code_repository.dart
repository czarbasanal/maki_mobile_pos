import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for CostCode operations.
abstract class CostCodeRepository {
  /// Gets the current cost code mapping.
  Future<CostCodeEntity> getCostCodeMapping();

  /// Streams the cost code mapping for real-time updates.
  Stream<CostCodeEntity> watchCostCodeMapping();

  /// Updates the cost code mapping.
  Future<void> updateCostCodeMapping(CostCodeEntity mapping);

  /// Resets to the default mapping.
  Future<void> resetToDefaultMapping();
}
