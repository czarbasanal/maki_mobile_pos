import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed ShopFee operations.
///
/// Backed by the single `shop_fees` collection.
abstract class ShopFeeRepository {
  /// Streams active shop fees ordered A→Z by name.
  Stream<List<ShopFeeEntity>> watchActive();

  /// Streams all shop fees (active + inactive) for admin management.
  Stream<List<ShopFeeEntity>> watchAll();

  /// Reads a single shop fee by ID.
  Future<ShopFeeEntity?> getShopFeeById(String shopFeeId);

  /// Creates a shop fee. Returns the persisted entity with its assigned ID.
  Future<ShopFeeEntity> createShopFee({
    required ShopFeeEntity shopFee,
    required String createdBy,
  });

  /// Updates an existing shop fee.
  Future<ShopFeeEntity> updateShopFee({
    required ShopFeeEntity shopFee,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) or reactivates a shop fee.
  Future<void> setActive({
    required String shopFeeId,
    required bool active,
    required String updatedBy,
  });

  /// Checks whether a shop fee name already exists (case-insensitive).
  Future<bool> nameExists({
    required String name,
    String? excludeShopFeeId,
  });
}
