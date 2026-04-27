import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/supplier_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/create_supplier_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/set_supplier_active_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/update_supplier_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the SupplierRepository instance.
final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE-CASE PROVIDERS ====================

final createSupplierUseCaseProvider = Provider<CreateSupplierUseCase>((ref) {
  return CreateSupplierUseCase(
    repository: ref.watch(supplierRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateSupplierUseCaseProvider = Provider<UpdateSupplierUseCase>((ref) {
  return UpdateSupplierUseCase(
    repository: ref.watch(supplierRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final setSupplierActiveUseCaseProvider =
    Provider<SetSupplierActiveUseCase>((ref) {
  return SetSupplierActiveUseCase(
    repository: ref.watch(supplierRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
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

/// Notifier for supplier operations. All mutations route through use-cases,
/// which assert permissions and emit audit logs. The current user is read
/// from [currentUserProvider]; callers no longer pass createdBy/updatedBy.
class SupplierOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SupplierOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  Future<SupplierEntity?> createSupplier({
    required SupplierEntity supplier,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(createSupplierUseCaseProvider)
          .execute(actor: actor, supplier: supplier);
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Create supplier failed',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<SupplierEntity?> updateSupplier({
    required SupplierEntity supplier,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(updateSupplierUseCaseProvider)
          .execute(actor: actor, supplier: supplier);
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        _ref.invalidate(supplierByIdProvider(supplier.id));
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Update supplier failed',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivateSupplier({required String supplierId}) async =>
      _setActive(supplierId: supplierId, active: false);

  Future<bool> reactivateSupplier({required String supplierId}) async =>
      _setActive(supplierId: supplierId, active: true);

  Future<bool> _setActive({
    required String supplierId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(setSupplierActiveUseCaseProvider)
          .execute(actor: actor, supplierId: supplierId, active: active);
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        return true;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Operation failed',
        StackTrace.current,
      );
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Checks if supplier name exists. Read-only — no permission check needed.
  Future<bool> nameExists(String name, {String? excludeSupplierId}) async {
    try {
      return await _ref.read(supplierRepositoryProvider).nameExists(
            name: name,
            excludeSupplierId: excludeSupplierId,
          );
    } catch (e) {
      return false;
    }
  }

  void _invalidate() {
    _ref.invalidate(suppliersProvider);
    _ref.invalidate(allSuppliersProvider);
    _ref.invalidate(supplierCountProvider);
  }
}

/// Provider for supplier operations.
final supplierOperationsProvider =
    StateNotifierProvider<SupplierOperationsNotifier, AsyncValue<void>>((ref) {
  return SupplierOperationsNotifier(ref);
});

// ==================== SELECTED SUPPLIER ====================

/// Currently selected supplier for viewing/editing.
final selectedSupplierProvider = StateProvider<SupplierEntity?>((ref) => null);
