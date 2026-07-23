// Prefixed: core/errors/exceptions.dart also defines a `TimeoutException`
// (a NetworkException), so `dart:async`'s must be referenced qualified.
import 'dart:async' as async;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/receiving_filters.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/batch_import_receiving_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:uuid/uuid.dart';

// ==================== CONFIG ====================

/// Upper bound on a single receiving-detail fetch. A stuck read (flaky network,
/// token refresh stall) must not pin the loading skeleton forever — past this
/// the load surfaces a recoverable error instead. Overridable in tests.
final receivingLoadTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 20));

// ==================== REPOSITORY PROVIDER ====================

final receivingRepositoryProvider = Provider<ReceivingRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return ReceivingRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    productRepository: productRepo,
  );
});

// ==================== USE-CASE PROVIDERS ====================

final completeReceivingUseCaseProvider =
    Provider<CompleteReceivingUseCase>((ref) {
  return CompleteReceivingUseCase(
    repository: ref.watch(receivingRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final receivingImportResolverProvider =
    Provider<ReceivingImportResolver>((ref) {
  return ReceivingImportResolver(
    createProductUseCase: ref.watch(createProductUseCaseProvider),
  );
});

final batchImportReceivingUseCaseProvider =
    Provider<BatchImportReceivingUseCase>((ref) {
  return BatchImportReceivingUseCase(
    receivingRepository: ref.watch(receivingRepositoryProvider),
    resolver: ref.watch(receivingImportResolverProvider),
    completeReceivingUseCase: ref.watch(completeReceivingUseCaseProvider),
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
///
/// Derived client-side from [recentReceivingsProvider] — Firestore's
/// `.count()` aggregations against the `receivings` collection were
/// silently failing without an aggregation/single-field exemption
/// index, which collapsed the receiving dashboard's stats row. The
/// derived view matches the pattern used by [draftReceivingsProvider]
/// and the MTD providers; it caps at the source stream's 50-record
/// limit, which is fine for dashboard counts.
final receivingCountsProvider =
    Provider<AsyncValue<Map<ReceivingStatus, int>>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData((list) {
    final counts = <ReceivingStatus, int>{
      for (final s in ReceivingStatus.values) s: 0,
    };
    for (final r in list) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    return counts;
  });
});

/// Month-to-date peso total received — sum of [totalCost] across
/// receivings completed in the current month. Drives the receiving
/// dashboard's "Total Received" card.
///
/// Derived client-side from [recentReceivingsProvider] so we don't
/// need a (status == completed, completedAt >= start-of-month)
/// composite index.
final monthToDateReceivingTotalProvider =
    Provider<AsyncValue<double>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData(
    (list) => sumTotalCost(monthToDateCompleted(list, DateTime.now())),
  );
});

/// Receivings created in the current Monday→Sunday week, all statuses.
/// Drives the receiving screen's "Recent Receivings" section. Derived
/// from [recentReceivingsProvider] so the list updates live as new
/// drafts and completions land.
final currentWeekReceivingsProvider =
    Provider<AsyncValue<List<ReceivingEntity>>>((ref) {
  final all = ref.watch(recentReceivingsProvider);
  return all.whenData(
    (list) => receivingsInCurrentWeek(list, DateTime.now()),
  );
});

// ==================== CURRENT RECEIVING STATE ====================

/// State for the current receiving being created/edited.
class CurrentReceivingState extends Equatable {
  final String? id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<ReceivingItemEntity> items;
  final String? notes;
  final ReceivingStatus status;
  final DateTime? completedAt;

  /// The purchase order this receiving fulfills, when it was started from
  /// one. Must be carried through every save or the PO link is severed.
  final String? purchaseOrderId;
  final bool isProcessing;

  /// True while an existing receiving is being fetched (detail / draft load),
  /// so consumers can show a loading state instead of the empty form.
  final bool isLoading;
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
    this.purchaseOrderId,
    this.isProcessing = false,
    this.isLoading = false,
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
    String? purchaseOrderId,
    bool? isProcessing,
    bool? isLoading,
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
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      isProcessing: isProcessing ?? this.isProcessing,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        supplierId,
        supplierName,
        items,
        notes,
        status,
        completedAt,
        purchaseOrderId,
        isProcessing,
        isLoading,
        errorMessage,
      ];
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
  ///
  /// Intentionally lets a reference-number failure propagate: the primary
  /// caller (`_startNewReceiving`) catches it to show a snackbar and abort
  /// navigation. Swallowing it here would make that guard dead code.
  Future<void> initNewReceiving() async {
    // Wipe any lingering state BEFORE the async gap — without this, a
    // previous session's abandoned in-progress receiving stays rendered
    // (and interactive) for the whole reference-number round-trip.
    state = const CurrentReceivingState(isLoading: true);
    final refNumber = await _repository.generateReferenceNumber();
    state = CurrentReceivingState(referenceNumber: refNumber);
  }

  /// Loads an existing receiving for editing.
  ///
  /// The `isLoading` flag is flipped INSIDE the try: assigning `state` can throw
  /// if this is ever invoked during a widget build/lifecycle (Riverpod forbids
  /// mutating a provider then). Guarding it means such a failure surfaces as an
  /// error rather than pinning the loading skeleton forever. Callers must still
  /// invoke this off the build phase (the detail screen defers via a
  /// post-frame callback).
  Future<void> loadReceiving(String receivingId) async {
    try {
      // Flag loading up front so the screen shows a skeleton instead of the
      // empty form while the fetch is in flight (or any stale state lingers).
      state = state.copyWith(isLoading: true, clearError: true);
      final receiving = await _repository
          .getReceivingById(receivingId)
          .timeout(_ref.read(receivingLoadTimeoutProvider));
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
          purchaseOrderId: receiving.purchaseOrderId,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on async.TimeoutException {
      // The fetch stalled past the budget. Clear the skeleton and show a
      // recoverable message — re-entering the screen retries the load.
      state = const CurrentReceivingState(
        errorMessage: 'Loading timed out. Check your connection and try again.',
      );
    } catch (e) {
      // Reset to a fresh (editable, non-read-only) state carrying only the
      // error. Two reasons: (1) without clearing isLoading the skeleton
      // would be pinned forever; (2) copyWith would preserve a previously
      // loaded *completed* receiving — its read-only status hides the error
      // banner (gated on !isReadOnly) and shows stale data on a failed load.
      state = CurrentReceivingState(errorMessage: e.toString());
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
  ///
  /// If a line already exists for the same product *and* the same unit
  /// cost, the quantities merge instead of creating a duplicate row.
  /// Different unit costs stay split because they create separate
  /// product variations downstream during completion.
  void addItem(ReceivingItemEntity item) {
    final existingIdx = state.items.indexWhere((existing) =>
        existing.productId != null &&
        existing.productId == item.productId &&
        (existing.unitCost - item.unitCost).abs() < 0.0001);

    final List<ReceivingItemEntity> next;
    if (existingIdx >= 0) {
      final existing = state.items[existingIdx];
      next = [...state.items];
      next[existingIdx] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      next = [...state.items, item.copyWith(id: _uuid.v4())];
    }
    state = state.copyWith(items: next, clearError: true);
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
        purchaseOrderId: state.purchaseOrderId,
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
      // Persist the in-session state first: for a new receiving this creates
      // the draft; for a resumed draft it writes the user's edits — otherwise
      // completion would read the stale stored copy and increment stock by
      // the original quantities, silently ignoring what was actually
      // delivered.
      final draft = await saveAsDraft(
        createdBy: createdBy,
        createdByName: createdByName,
      );
      if (draft == null) return null;
      final receivingId = draft.id;

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
