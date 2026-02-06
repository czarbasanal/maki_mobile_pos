import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/supplier_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the SupplierRepository instance.
final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl();
});

// ==================== SUPPLIER QUERIES ====================

/// Provides all active suppliers as a stream.
final suppliersProvider = StreamProvider<List<SupplierEntity>>((ref) {
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.watchSuppliers();
});

/// Provides all suppliers including inactive ones.
final allSuppliersProvider = FutureProvider<List<SupplierEntity>>((ref) async {
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.getAllSuppliers(includeInactive: true);
});

/// Provides a single supplier by ID.
final supplierByIdProvider =
    FutureProvider.family<SupplierEntity?, String>((ref, supplierId) async {
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.getSupplierById(supplierId);
});

/// Provides a single supplier by ID as a stream.
final supplierStreamProvider =
    StreamProvider.family<SupplierEntity?, String>((ref, supplierId) {
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.watchSupplier(supplierId);
});

/// Provides supplier search results.
final supplierSearchProvider =
    FutureProvider.family<List<SupplierEntity>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.searchSuppliers(query: query);
});

/// Provides supplier count.
final supplierCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(supplierRepositoryProvider);
  return repository.getSupplierCount();
});

// ==================== SUPPLIER OPERATIONS ====================

/// Notifier for supplier operations.
class SupplierOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final SupplierRepository _repository;
  final Ref _ref;

  SupplierOperationsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Creates a new supplier.
  Future<SupplierEntity?> createSupplier({
    required SupplierEntity supplier,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repository.createSupplier(
        supplier: supplier,
        createdBy: createdBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProviders();
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing supplier.
  Future<SupplierEntity?> updateSupplier({
    required SupplierEntity supplier,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateSupplier(
        supplier: supplier,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProviders();
      _ref.invalidate(supplierByIdProvider(supplier.id));
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Deactivates a supplier.
  Future<bool> deactivateSupplier({
    required String supplierId,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deactivateSupplier(
        supplierId: supplierId,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProviders();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Reactivates a supplier.
  Future<bool> reactivateSupplier({
    required String supplierId,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.reactivateSupplier(
        supplierId: supplierId,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProviders();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Checks if supplier name exists.
  Future<bool> nameExists(String name, {String? excludeSupplierId}) async {
    try {
      return await _repository.nameExists(
        name: name,
        excludeSupplierId: excludeSupplierId,
      );
    } catch (e) {
      return false;
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(suppliersProvider);
    _ref.invalidate(allSuppliersProvider);
    _ref.invalidate(supplierCountProvider);
  }
}

/// Provider for supplier operations.
final supplierOperationsProvider =
    StateNotifierProvider<SupplierOperationsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(supplierRepositoryProvider);
  return SupplierOperationsNotifier(repository, ref);
});

// ==================== SELECTED SUPPLIER ====================

/// Currently selected supplier for viewing/editing.
final selectedSupplierProvider = StateProvider<SupplierEntity?>((ref) => null);
