import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/data/repositories/job_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/delete_job_order_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/save_job_order_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/update_job_order_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the JobOrderRepository instance.
final jobOrderRepositoryProvider = Provider<JobOrderRepository>((ref) {
  return JobOrderRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== JOB ORDER QUERIES ====================

/// Provides active (non-converted) job orders as a real-time stream.
final activeJobOrdersProvider = StreamProvider<List<JobOrderEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(jobOrderRepositoryProvider).watchActiveJobOrders();
  });
});

/// Provides active job orders for a specific user.
final userActiveJobOrdersProvider =
    StreamProvider.family<List<JobOrderEntity>, String>((ref, userId) {
  return authGatedStream(ref, (_) {
    return ref
        .watch(jobOrderRepositoryProvider)
        .watchActiveJobOrders(createdBy: userId);
  });
});

/// Provides a single job order by ID as a real-time stream.
final jobOrderByIdStreamProvider =
    StreamProvider.family<JobOrderEntity?, String>((ref, jobOrderId) {
  return authGatedStream(ref, (_) {
    return ref.watch(jobOrderRepositoryProvider).watchJobOrder(jobOrderId);
  });
});

/// Provides a single job order by ID (one-time fetch).
final jobOrderByIdProvider =
    FutureProvider.family<JobOrderEntity?, String>((ref, jobOrderId) async {
  final repository = ref.watch(jobOrderRepositoryProvider);
  return repository.getJobOrderById(jobOrderId);
});

/// Provides all job orders including converted ones.
final allJobOrdersProvider =
    FutureProvider.family<List<JobOrderEntity>, AllJobOrdersParams>(
        (ref, params) async {
  final repository = ref.watch(jobOrderRepositoryProvider);
  return repository.getAllJobOrders(
    createdBy: params.createdBy,
    includeConverted: params.includeConverted,
    limit: params.limit,
  );
});

/// Open job-order count for the POS badge, derived from the live
/// [activeJobOrdersProvider] stream so it can never go stale (a one-shot
/// fetch here previously kept showing billed-out tickets until restart).
final activeJobOrderCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(activeJobOrdersProvider)
      .whenData((jobOrders) => jobOrders.length);
});

// ==================== USE CASE PROVIDERS ====================

final saveJobOrderUseCaseProvider = Provider<SaveJobOrderUseCase>((ref) {
  return SaveJobOrderUseCase(
    repository: ref.watch(jobOrderRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateJobOrderUseCaseProvider = Provider<UpdateJobOrderUseCase>((ref) {
  return UpdateJobOrderUseCase(
    repository: ref.watch(jobOrderRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final deleteJobOrderUseCaseProvider = Provider<DeleteJobOrderUseCase>((ref) {
  return DeleteJobOrderUseCase(
    repository: ref.watch(jobOrderRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== JOB ORDER OPERATIONS ====================

/// Notifier for job order operations.
///
/// Mutations (save / update / delete) flow through use cases that own the
/// guards: updates and deletes are owner-or-admin, and a converted ticket
/// is frozen. Convenience methods (updateJobOrderItems, updateJobOrderName)
/// construct the desired JobOrderEntity and route through [updateJobOrder] so
/// guards apply uniformly.
/// `markAsConverted` stays a direct repo call — it's invoked from
/// [ProcessSaleUseCase] which has already gated the operation.
class JobOrderOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final JobOrderRepository _repository;
  final SaveJobOrderUseCase _saveUseCase;
  final UpdateJobOrderUseCase _updateUseCase;
  final DeleteJobOrderUseCase _deleteUseCase;
  final Ref _ref;

  JobOrderOperationsNotifier({
    required JobOrderRepository repository,
    required SaveJobOrderUseCase saveUseCase,
    required UpdateJobOrderUseCase updateUseCase,
    required DeleteJobOrderUseCase deleteUseCase,
    required Ref ref,
  })  : _repository = repository,
        _saveUseCase = saveUseCase,
        _updateUseCase = updateUseCase,
        _deleteUseCase = deleteUseCase,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<JobOrderEntity?> createJobOrder({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
  }) async {
    state = const AsyncValue.loading();
    final result = await _saveUseCase.execute(actor: actor, jobOrder: jobOrder);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateJobOrderProviders();
      return result.data;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to save job order',
        StackTrace.current,
      );
      return null;
    }
  }

  Future<JobOrderEntity?> updateJobOrder({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
  }) async {
    state = const AsyncValue.loading();
    final result =
        await _updateUseCase.execute(actor: actor, jobOrder: jobOrder);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateJobOrderProviders();
      _ref.invalidate(jobOrderByIdProvider(jobOrder.id));
      return result.data;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to update job order',
        StackTrace.current,
      );
      return null;
    }
  }

  /// Convenience: update items via [updateJobOrder] with a fresh JobOrderEntity.
  Future<JobOrderEntity?> updateJobOrderItems({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
    required List<SaleItemEntity> items,
  }) async {
    return updateJobOrder(
        actor: actor, jobOrder: jobOrder.copyWith(items: items));
  }

  /// Convenience: update name via [updateJobOrder] with a fresh JobOrderEntity.
  Future<JobOrderEntity?> updateJobOrderName({
    required UserEntity actor,
    required JobOrderEntity jobOrder,
    required String name,
  }) async {
    return updateJobOrder(
        actor: actor, jobOrder: jobOrder.copyWith(name: name));
  }

  /// Marks a job order as converted. Internal sale-flow side-effect, not user-
  /// driven — process_sale_usecase already gated the operation.
  Future<JobOrderEntity?> markAsConverted({
    required String jobOrderId,
    required String saleId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.markJobOrderAsConverted(
        jobOrderId: jobOrderId,
        saleId: saleId,
      );
      state = const AsyncValue.data(null);
      _invalidateJobOrderProviders();
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteJobOrder({
    required UserEntity actor,
    required String jobOrderId,
  }) async {
    state = const AsyncValue.loading();
    final result =
        await _deleteUseCase.execute(actor: actor, jobOrderId: jobOrderId);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateJobOrderProviders();
      return true;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to delete job order',
        StackTrace.current,
      );
      return false;
    }
  }

  /// Deletes old converted job orders.
  Future<int> deleteOldConvertedJobOrders(DateTime olderThan) async {
    try {
      final count = await _repository.deleteOldConvertedJobOrders(olderThan);
      _invalidateJobOrderProviders();
      return count;
    } catch (e) {
      return 0;
    }
  }

  void _invalidateJobOrderProviders() {
    // The badge count derives from this stream, so it refreshes too.
    _ref.invalidate(activeJobOrdersProvider);
  }
}

/// Provider for job order operations.
final jobOrderOperationsProvider =
    StateNotifierProvider<JobOrderOperationsNotifier, AsyncValue<void>>((ref) {
  return JobOrderOperationsNotifier(
    repository: ref.watch(jobOrderRepositoryProvider),
    saveUseCase: ref.watch(saveJobOrderUseCaseProvider),
    updateUseCase: ref.watch(updateJobOrderUseCaseProvider),
    deleteUseCase: ref.watch(deleteJobOrderUseCaseProvider),
    ref: ref,
  );
});

// ==================== SELECTED DRAFT ====================

/// Currently selected job order for editing.
/// This is used when loading a job order into the cart for editing.
final selectedJobOrderProvider = StateProvider<JobOrderEntity?>((ref) => null);

// ==================== PARAMETER CLASSES ====================

/// Parameters for all job orders query.
class AllJobOrdersParams {
  final String? createdBy;
  final bool includeConverted;
  final int limit;

  const AllJobOrdersParams({
    this.createdBy,
    this.includeConverted = false,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllJobOrdersParams &&
        other.createdBy == createdBy &&
        other.includeConverted == includeConverted &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      createdBy.hashCode ^ includeConverted.hashCode ^ limit.hashCode;
}
