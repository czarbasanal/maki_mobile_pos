import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/data/repositories/void_request_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY ====================

final voidRequestRepositoryProvider = Provider<VoidRequestRepository>((ref) {
  return VoidRequestRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE CASES ====================

final requestVoidSaleUseCaseProvider = Provider<RequestVoidSaleUseCase>((ref) {
  return RequestVoidSaleUseCase(
    repository: ref.watch(voidRequestRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final rejectVoidRequestUseCaseProvider =
    Provider<RejectVoidRequestUseCase>((ref) {
  return RejectVoidRequestUseCase(
    repository: ref.watch(voidRequestRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final approveVoidRequestUseCaseProvider =
    Provider<ApproveVoidRequestUseCase>((ref) {
  return ApproveVoidRequestUseCase(
    repository: ref.watch(voidRequestRepositoryProvider),
    voidSaleUseCase: VoidSaleUseCase(
      saleRepository: ref.watch(saleRepositoryProvider),
      productRepository: ref.watch(productRepositoryProvider),
      authRepository: ref.watch(authRepositoryProvider),
      logger: ref.watch(activityLoggerProvider),
    ),
  );
});

// ==================== STREAMS ====================

/// All void requests, newest first (admin queue).
final voidRequestsProvider = StreamProvider<List<VoidRequestEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(voidRequestRepositoryProvider).watchRequests();
  });
});

/// Unread void-request count (notification badge).
final unreadVoidRequestCountProvider = Provider<int>((ref) {
  final async = ref.watch(voidRequestsProvider);
  return async.maybeWhen(
    data: (list) => list.where((r) => !r.read).length,
    orElse: () => 0,
  );
});

/// Pending requests for a sale (sale-detail indicator).
final pendingVoidRequestForSaleProvider =
    StreamProvider.autoDispose.family<List<VoidRequestEntity>, String>(
        (ref, saleId) {
  return authGatedStream(ref, (_) {
    return ref
        .watch(voidRequestRepositoryProvider)
        .watchPendingForSale(saleId);
  });
});

// ==================== FILTERS & PAGING ====================

/// Status filter for the admin void-request list. `null` = all statuses.
final voidRequestStatusFilterProvider =
    StateProvider.autoDispose<VoidRequestStatus?>((_) => null);

/// Selected date-range preset for the admin void-request list.
final voidRequestDatePresetProvider =
    StateProvider.autoDispose<DateRangePreset>((_) => DateRangePreset.today);

/// Concrete date range for the admin void-request list, derived from
/// [voidRequestDatePresetProvider]'s default (today) at construction time.
/// `dateRangeForPreset` already returns `end` at true end-of-day
/// (23:59:59.999) so paging/count queries never drop a request created in
/// the last second of the day.
final voidRequestDateRangeProvider = StateProvider.autoDispose<DateTimeRange>(
    (_) => dateRangeForPreset(DateRangePreset.today, DateTime.now()));

/// One page of void requests plus whether another page is available.
class PagedVoidRequests {
  final List<VoidRequestEntity> items;
  final bool hasMore;
  const PagedVoidRequests({required this.items, required this.hasMore});
}

/// Paged, filterable admin void-request list. Rebuilds from page 1 whenever
/// [voidRequestStatusFilterProvider] or [voidRequestDateRangeProvider]
/// changes; call `loadMore()` to append the next page.
class PagedVoidRequestsNotifier
    extends AutoDisposeAsyncNotifier<PagedVoidRequests> {
  static const _pageSize = 20;

  @override
  Future<PagedVoidRequests> build() async {
    final status = ref.watch(voidRequestStatusFilterProvider);
    final range = ref.watch(voidRequestDateRangeProvider);
    final items = await ref.read(voidRequestRepositoryProvider).getRequestsPage(
        status: status, start: range.start, end: range.end, limit: _pageSize);
    return PagedVoidRequests(
        items: items, hasMore: items.length == _pageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    final before = state;
    final status = ref.read(voidRequestStatusFilterProvider);
    final range = ref.read(voidRequestDateRangeProvider);
    final next = await ref.read(voidRequestRepositoryProvider).getRequestsPage(
        status: status,
        start: range.start,
        end: range.end,
        limit: _pageSize,
        startAfterId: current.items.last.id);
    // The filter/range may have changed (or this notifier may have been
    // invalidated/disposed) while the fetch above was in flight. Appending
    // `next` on top of `current` in that case would splice a stale page
    // onto a list the user never asked for. Abandon rather than write.
    try {
      final filterUnchanged =
          ref.read(voidRequestStatusFilterProvider) == status &&
              ref.read(voidRequestDateRangeProvider) == range;
      if (!identical(state, before) || !filterUnchanged) return;
      state = AsyncValue.data(PagedVoidRequests(
          items: [...current.items, ...next],
          hasMore: next.length == _pageSize));
    } on StateError {
      // autoDispose tore this notifier down mid-flight; ref reads/state
      // writes on a disposed notifier throw StateError. Treat as abandoned.
      return;
    }
  }
}

final pagedVoidRequestsProvider = AsyncNotifierProvider.autoDispose<
    PagedVoidRequestsNotifier, PagedVoidRequests>(PagedVoidRequestsNotifier.new);

/// Count of requests for [status] within [voidRequestDateRangeProvider]'s
/// current window (used for status-tab badges).
final voidRequestStatusCountProvider =
    FutureProvider.autoDispose.family<int, VoidRequestStatus>((ref, status) {
  final range = ref.watch(voidRequestDateRangeProvider);
  return ref.watch(voidRequestRepositoryProvider).countByStatus(
      status: status, start: range.start, end: range.end);
});

// ==================== OPERATIONS ====================

class VoidRequestOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  VoidRequestOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user;
  }

  String _messageFor(Object error) =>
      error is AppException ? error.message : error.toString();

  /// Returns null on success, or an error message.
  ///
  /// `_requireUser()` throws on an auth-transition race (null user); each
  /// method catches so the failure comes back through the returned
  /// message rather than as a rejected Future the dialog never observes.
  Future<String?> requestVoid({
    required SaleEntity sale,
    required String reason,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(requestVoidSaleUseCaseProvider)
          .execute(actor: actor, sale: sale, reason: reason);
      _ref.invalidate(voidRequestsProvider);
      _ref.invalidate(pagedVoidRequestsProvider);
      _ref.invalidate(voidRequestStatusCountProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<String?> approve({
    required VoidRequestEntity request,
    required String password,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(approveVoidRequestUseCaseProvider)
          .execute(actor: actor, request: request, password: password);
      _ref.invalidate(voidRequestsProvider);
      _ref.invalidate(pagedVoidRequestsProvider);
      _ref.invalidate(voidRequestStatusCountProvider);
      _ref.invalidate(todaysSalesProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<String?> reject({
    required VoidRequestEntity request,
    required String rejectionReason,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref.read(rejectVoidRequestUseCaseProvider).execute(
          actor: actor,
          request: request,
          rejectionReason: rejectionReason);
      _ref.invalidate(voidRequestsProvider);
      _ref.invalidate(pagedVoidRequestsProvider);
      _ref.invalidate(voidRequestStatusCountProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<void> markAllRead() async {
    await _ref.read(voidRequestRepositoryProvider).markAllRead();
    _ref.invalidate(voidRequestsProvider);
    _ref.invalidate(pagedVoidRequestsProvider);
    _ref.invalidate(voidRequestStatusCountProvider);
  }

  Future<void> markRead(String requestId) async {
    await _ref.read(voidRequestRepositoryProvider).markRead(requestId);
    _ref.invalidate(voidRequestsProvider);
    _ref.invalidate(pagedVoidRequestsProvider);
    _ref.invalidate(voidRequestStatusCountProvider);
  }
}

final voidRequestOperationsProvider =
    StateNotifierProvider<VoidRequestOperationsNotifier, AsyncValue<void>>(
        (ref) => VoidRequestOperationsNotifier(ref));
