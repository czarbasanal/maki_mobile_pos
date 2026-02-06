import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Supplier operations.
abstract class SupplierRepository {
  // ==================== CREATE ====================

  /// Creates a new supplier.
  Future<SupplierEntity> createSupplier({
    required SupplierEntity supplier,
    required String createdBy,
  });

  // ==================== READ ====================

  /// Gets a supplier by ID.
  Future<SupplierEntity?> getSupplierById(String supplierId);

  /// Gets all active suppliers.
  Future<List<SupplierEntity>> getSuppliers({int limit = 100});

  /// Gets all suppliers including inactive ones.
  Future<List<SupplierEntity>> getAllSuppliers({
    bool includeInactive = false,
    int limit = 100,
  });

  /// Searches suppliers by name or contact.
  Future<List<SupplierEntity>> searchSuppliers({
    required String query,
    int limit = 20,
  });

  /// Streams all active suppliers.
  Stream<List<SupplierEntity>> watchSuppliers();

  /// Streams a single supplier.
  Stream<SupplierEntity?> watchSupplier(String supplierId);

  // ==================== UPDATE ====================

  /// Updates an existing supplier.
  Future<SupplierEntity> updateSupplier({
    required SupplierEntity supplier,
    required String updatedBy,
  });

  /// Deactivates a supplier.
  Future<void> deactivateSupplier({
    required String supplierId,
    required String updatedBy,
  });

  /// Reactivates a supplier.
  Future<void> reactivateSupplier({
    required String supplierId,
    required String updatedBy,
  });

  // ==================== UTILITY ====================

  /// Checks if a supplier name exists.
  Future<bool> nameExists({
    required String name,
    String? excludeSupplierId,
  });

  /// Gets supplier count.
  Future<int> getSupplierCount({bool activeOnly = true});
}
