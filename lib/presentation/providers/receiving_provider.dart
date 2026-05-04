import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/receiving_month.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:uuid/uuid.dart';

// ==================== REPOSITORY PROVIDER ====================

final receivingRepositoryProvider = Provider<ReceivingRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return ReceivingRepositoryImpl(productRepository: productRepo);
});

// ==================== USE-CASE PROVIDERS ====================

final completeReceivingUseCaseProvider =
    Provider<CompleteReceivingUseCase>((ref) {
  return CompleteReceivingUseCase(
    repository: ref.watch(receivingRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== RECEIVING QUERIES ====================

/// Provides recent receiving records.
final recentReceivingsProvider = StreamProvider<List<ReceivingEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(receivingRepositoryProvider).watchReceivings(limit: 50);
  });
});

/// Provides draft receivings.
///
/// Derived from [recentReceivingsProvider] rather than its own Firestore
/// query so the (status == draft, orderBy createdAt) combination doesn't
/// trigger Firestore's composite-index requirement. Limited to whatever
/// `recentReceivingsProvider` returns (50), which is fine for a drafts
/// surface — drafts older than that are extremely unlikely.
final draftReceivingsProvider =
    Provider<AsyncValue<List<ReceivingEntity>>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData(
    (list) => list.where((r) => r.status == ReceivingStatus.draft).toList(),
  );
});

/// Provides a single receiving by ID.
final receivingByIdProvider =
    FutureProvider.family<ReceivingEntity?, String>((ref, receivingId) async {
  final repository = ref.watch(receivingRepositoryProvider);
  return repository.getReceivingById(receivingId);
});

/// Provides receiving counts by status.
final receivingCountsProvider =
    FutureProvider<Map<ReceivingStatus, int>>((ref) async {
  final repository = ref.watch(receivingRepositoryProvider);
  return repository.getReceivingCounts();
});

/// Month-to-date count of completed receivings.
///
/// Derived client-side from [recentReceivingsProvider] so we don't need a
/// (status == completed, completedAt >= start-of-month) composite index.
/// The 50-record cap on the source stream is fine here — month-to-date
/// counts above that are not realistic for this surface.
final monthToDateCompletedReceivingsProvider =
    Provider<AsyncValue<int>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData(
    (list) => monthToDateCompleted(list, DateTime.now()).length,
  );
});

/// Month-to-date peso total received — sum of [totalCost] across the
/// same set of completed receivings counted by
/// [monthToDateCompletedReceivingsProvider]. Drives the receiving
/// dashboard's "Total Received" card.
final monthToDateReceivingTotalProvider =
    Provider<AsyncValue<double>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData(
    (list) => sumTotalCost(monthToDateCompleted(list, DateTime.now())),
  );
});

// ==================== CURRENT RECEIVING STATE ====================

/// State for the current receiving being created/edited.
class CurrentReceivingState {
  final String? id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<ReceivingItemEntity> items;
  final String? notes;
  final ReceivingStatus status;
  final DateTime? completedAt;
  final bool isProcessing;
  final String? errorMessage;

  const CurrentReceivingState({
    this.id,
    this.referenceNumber = '',
    this.supplierId,
    this.supplierName,
    this.items = const [],
    this.notes,
    this.status = ReceivingStatus.draft,
    this.completedAt,
    this.isProcessing = false,
    this.errorMessage,
  });

  double get totalCost => items.fold(0.0, (sum, item) => sum + item.totalCost);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  int get itemCount => items.length;

  bool get isEmpty => items.isEmpty;

  bool get isValid => items.isNotEmpty;

  /// True when the receiving is finalized — completed receivings are
  /// immutable in the form (stock has already been adjusted, variations
  /// created, price history recorded). The screen renders read-only.
  bool get isReadOnly => status == ReceivingStatus.completed;

  CurrentReceivingState copyWith({
    String? id,
    String? referenceNumber,
    String? supplierId,
    String? supplierName,
    List<ReceivingItemEntity>? items,
    String? notes,
    ReceivingStatus? status,
    DateTime? completedAt,
    bool? isProcessing,
    String? errorMessage,
    bool clearId = false,
    bool clearSupplierId = false,
    bool clearSupplierName = false,
    bool clearNotes = false,
    bool clearCompletedAt = false,
    bool clearError = false,
  }) {
    return CurrentReceivingState(
      id: clearId ? null : (id ?? this.id),
      referenceNumber: referenceNumber ?? this.referenceNumber,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      supplierName:
          clearSupplierName ? null : (supplierName ?? this.supplierName),
      items: items ?? this.items,
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier for current receiving state.
class CurrentReceivingNotifier extends StateNotifier<CurrentReceivingState> {
  final ReceivingRepository _repository;
  final ProductRepository _productRepository;
  final Ref _ref;
  final _uuid = const Uuid();

  CurrentReceivingNotifier(
    this._repository,
    this._productRepository,
    this._ref,
  ) : super(const CurrentReceivingState());

  /// Initializes a new receiving.
  Future<void> initNewReceiving() async {
    final refNumber = await _repository.generateReferenceNumber();
    state = CurrentReceivingState(referenceNumber: refNumber);
  }

  /// Loads an existing receiving for editing.
  Future<void> loadReceiving(String receivingId) async {
    final receiving = await _repository.getReceivingById(receivingId);
    if (receiving != null) {
      state = CurrentReceivingState(
        id: receiving.id,
        referenceNumber: receiving.referenceNumber,
        supplierId: receiving.supplierId,
        supplierName: receiving.supplierName,
        items: receiving.items,
        notes: receiving.notes,
        status: receiving.status,
        completedAt: receiving.completedAt,
      );
    }
  }

  /// Sets the supplier.
  void setSupplier(String? supplierId, String? supplierName) {
    state = state.copyWith(
      supplierId: supplierId,
      supplierName: supplierName,
      clearSupplierId: supplierId == null,
      clearSupplierName: supplierName == null,
    );
  }

  /// Adds an item to the receiving.
  void addItem(ReceivingItemEntity item) {
    final items = [...state.items, item.copyWith(id: _uuid.v4())];
    state = state.copyWith(items: items, clearError: true);
  }

  /// Adds an item from a product.
  Future<void> addProductItem({
    required String productId,
    required int quantity,
    required double unitCost,
    required String costCode,
  }) async {
    final product = await _productRepository.getProductById(productId);
    if (product == null) return;

    final item = ReceivingItemEntity(
      id: _uuid.v4(),
      productId: product.id,
      sku: product.sku,
      name: product.name,
      quantity: quantity,
      unit: product.unit,
      unitCost: unitCost,
      costCode: costCode,
    );

    addItem(item);
  }

  /// Updates an item quantity.
  void updateItemQuantity(String itemId, int quantity) {
    final items = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    state = state.copyWith(items: items);
  }

  /// Updates an item cost.
  void updateItemCost(String itemId, double unitCost, String costCode) {
    final items = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(unitCost: unitCost, costCode: costCode);
      }
      return item;
    }).toList();
    state = state.copyWith(items: items);
  }

  /// Removes an item.
  void removeItem(String itemId) {
    final items = state.items.where((item) => item.id != itemId).toList();
    state = state.copyWith(items: items);
  }

  /// Clears all items.
  void clearItems() {
    state = state.copyWith(items: []);
  }

  /// Sets notes.
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes, clearNotes: notes == null);
  }

  /// Saves as draft.
  Future<ReceivingEntity?> saveAsDraft({
    required String createdBy,
    required String createdByName,
  }) async {
    if (state.isEmpty) {
      state = state.copyWith(errorMessage: 'No items to save');
      return null;
    }

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final receiving = ReceivingEntity(
        id: state.id ?? '',
        referenceNumber: state.referenceNumber,
        supplierId: state.supplierId,
        supplierName: state.supplierName,
        items: state.items,
        totalCost: state.totalCost,
        totalQuantity: state.totalQuantity,
        status: ReceivingStatus.draft,
        notes: state.notes,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
      );

      ReceivingEntity result;
      if (state.id != null) {
        result = await _repository.updateReceiving(receiving);
      } else {
        result = await _repository.createReceiving(receiving);
      }

      state = state.copyWith(id: result.id, isProcessing: false);
      _invalidateProviders();
      return result;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Completes the receiving.
  Future<ReceivingEntity?> complete({
    required String createdBy,
    required String createdByName,
  }) async {
    if (state.isEmpty) {
      state = state.copyWith(errorMessage: 'No items to receive');
      return null;
    }

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      // First save as draft if not already saved
      String receivingId = state.id ?? '';
      if (receivingId.isEmpty) {
        final draft = await saveAsDraft(
          createdBy: createdBy,
          createdByName: createdByName,
        );
        if (draft == null) return null;
        receivingId = draft.id;
      }

      // Complete the receiving via the use-case (asserts permission, audit-logs).
      final actor = _ref.read(currentUserProvider).valueOrNull;
      if (actor == null) {
        throw const UnauthenticatedException();
      }
      final useCaseResult = await _ref
          .read(completeReceivingUseCaseProvider)
          .execute(actor: actor, receivingId: receivingId);

      if (!useCaseResult.success) {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: useCaseResult.errorMessage ?? 'Failed to complete',
        );
        return null;
      }

      state = const CurrentReceivingState();
      _invalidateProviders();
      return useCaseResult.data;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Resets the current receiving.
  void reset() {
    state = const CurrentReceivingState();
  }

  void _invalidateProviders() {
    _ref.invalidate(recentReceivingsProvider);
    _ref.invalidate(draftReceivingsProvider);
    _ref.invalidate(receivingCountsProvider);
    _ref.invalidate(productsProvider);
  }
}

/// Provider for current receiving state.
final currentReceivingProvider =
    StateNotifierProvider<CurrentReceivingNotifier, CurrentReceivingState>(
        (ref) {
  final receivingRepo = ref.watch(receivingRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  return CurrentReceivingNotifier(receivingRepo, productRepo, ref);
});
