import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/void_request_provider.dart';

/// Hand-written fake over an in-memory list — only the two paging/count
/// methods the providers under test call are implemented; everything else
/// throws so an accidental call fails loudly instead of silently no-oping.
class _FakeVoidRequestRepository implements VoidRequestRepository {
  final List<VoidRequestEntity> all;
  _FakeVoidRequestRepository(this.all);

  @override
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  }) async {
    var filtered = all.where((r) =>
        (status == null || r.status == status) &&
        !r.createdAt.isBefore(start) &&
        !r.createdAt.isAfter(end)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (startAfterId != null) {
      final idx = filtered.indexWhere((r) => r.id == startAfterId);
      if (idx != -1) {
        filtered = filtered.sublist(idx + 1);
      }
    }
    return filtered.take(limit).toList();
  }

  @override
  Future<int> countByStatus({
    required VoidRequestStatus status,
    required DateTime start,
    required DateTime end,
  }) async {
    return all
        .where((r) =>
            r.status == status &&
            !r.createdAt.isBefore(start) &&
            !r.createdAt.isAfter(end))
        .length;
  }

  @override
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request) =>
      throw UnimplementedError();

  @override
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50}) =>
      throw UnimplementedError();

  @override
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId) =>
      throw UnimplementedError();

  @override
  Future<bool> hasPendingForSale(String saleId) => throw UnimplementedError();

  @override
  Future<void> resolve({
    required String requestId,
    required String saleId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markRead(String requestId) => throw UnimplementedError();

  @override
  Future<void> markAllRead() => throw UnimplementedError();
}

/// Same paging behaviour as [_FakeVoidRequestRepository], but the
/// *continuation* call (the one `loadMore()` issues, identified by a
/// non-null [startAfterId]) doesn't resolve until [stall] completes — lets a
/// test hold a `loadMore()` fetch in flight while it changes filters out
/// from under it.
class _StallingFakeVoidRequestRepository extends _FakeVoidRequestRepository {
  final Completer<void> stall;
  _StallingFakeVoidRequestRepository(super.all, this.stall);

  @override
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  }) async {
    if (startAfterId != null) {
      await stall.future;
    }
    return super.getRequestsPage(
        status: status,
        start: start,
        end: end,
        limit: limit,
        startAfterId: startAfterId);
  }
}

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@test.com',
      displayName: 'Admin User',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

VoidRequestEntity _req(String id, {
  DateTime? createdAt,
  VoidRequestStatus status = VoidRequestStatus.pending,
}) =>
    VoidRequestEntity(
      id: id,
      saleId: 'sale-$id',
      saleNumber: 'SALE-$id',
      saleGrandTotal: 100,
      requestedBy: 'u-cashier',
      requestedByName: 'cashier user',
      requestedByRole: 'cashier',
      reason: 'wrong item',
      status: status,
      createdAt: createdAt ?? DateTime(2026, 7, 25, 10),
      );

/// Fixed range covering the fixtures' seed dates (all `DateTime(2026, 7,
/// 25, ...)`). Pinning this — instead of relying on
/// [voidRequestDateRangeProvider]'s default, which is derived from
/// `DateTime.now()` — keeps these tests passing on every future run date.
final _fixedSeedDateRange = DateTimeRange(
  start: DateTime(2026, 7, 25),
  end: DateTime(2026, 7, 25, 23, 59, 59, 999),
);

ProviderContainer _container(List<VoidRequestEntity> seed,
    {List<Override> overrides = const []}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
      voidRequestRepositoryProvider
          .overrideWithValue(_FakeVoidRequestRepository(seed)),
      ...overrides,
    ],
  );
}

void main() {
  group('pagedVoidRequestsProvider', () {
    test('loads page 1 and reports hasMore true on a full page', () async {
      // 25 pending requests, newest (highest index) first once sorted.
      final seed = List.generate(
        25,
        (i) => _req('r$i', createdAt: DateTime(2026, 7, 25, 10, i)),
      );
      final c = _container(seed, overrides: [
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      final result = await c.read(pagedVoidRequestsProvider.future);

      expect(result.items.length, 20);
      expect(result.hasMore, isTrue);
      // Newest first: r24 has the latest createdAt.
      expect(result.items.first.id, 'r24');
    });

    test('loadMore appends without duplicates and flips hasMore false '
        'on a short page', () async {
      final seed = List.generate(
        25,
        (i) => _req('r$i', createdAt: DateTime(2026, 7, 25, 10, i)),
      );
      final c = _container(seed, overrides: [
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      await c.read(pagedVoidRequestsProvider.future);
      await c.read(pagedVoidRequestsProvider.notifier).loadMore();

      final result = c.read(pagedVoidRequestsProvider).value!;
      expect(result.items.length, 25);
      expect(result.hasMore, isFalse);
      final ids = result.items.map((r) => r.id).toSet();
      expect(ids.length, 25, reason: 'no duplicates across pages');
    });

    test('changing the status filter rebuilds from page 1', () async {
      final seed = [
        ..._pendingBatch(3),
        _req('approved-1', status: VoidRequestStatus.approved),
      ];
      final c = _container(seed, overrides: [
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      await c.read(pagedVoidRequestsProvider.future);
      c.read(voidRequestStatusFilterProvider.notifier).state =
          VoidRequestStatus.approved;
      final result = await c.read(pagedVoidRequestsProvider.future);

      expect(result.items.length, 1);
      expect(result.items.single.id, 'approved-1');
    });

    test('loadMore abandons a stale page when the filter changes '
        'mid-flight', () async {
      final seed = [
        ..._pendingBatch(25),
        _req('approved-1', status: VoidRequestStatus.approved,
            createdAt: DateTime(2026, 7, 25, 11)),
      ];
      final stall = Completer<void>();
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        voidRequestRepositoryProvider.overrideWithValue(
            _StallingFakeVoidRequestRepository(seed, stall)),
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      // Page 1 under the default (all-statuses) filter: 20 of 25 pending.
      await c.read(pagedVoidRequestsProvider.future);

      // Kick off loadMore() — its continuation fetch (startAfterId set)
      // stalls until `stall` completes.
      final loadMoreFuture =
          c.read(pagedVoidRequestsProvider.notifier).loadMore();

      // While that fetch is in flight, switch to the approved filter and
      // let its (unstalled, no startAfterId) fetch resolve.
      c.read(voidRequestStatusFilterProvider.notifier).state =
          VoidRequestStatus.approved;
      final newFilterResult = await c.read(pagedVoidRequestsProvider.future);
      expect(newFilterResult.items.single.id, 'approved-1');

      // Now release the stalled loadMore continuation.
      stall.complete();
      await loadMoreFuture;

      final finalState = c.read(pagedVoidRequestsProvider).value!;
      expect(finalState.items.length, 1,
          reason: 'the stale pending-filter continuation must not be '
              'appended on top of the approved-filter page');
      expect(finalState.items.single.id, 'approved-1');
    });
  });

  group('voidRequestStatusCountProvider', () {
    test('returns the fake repository\'s count', () async {
      final seed = [
        ..._pendingBatch(3),
        _req('approved-1', status: VoidRequestStatus.approved),
      ];
      final c = _container(seed, overrides: [
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      final count = await c
          .read(voidRequestStatusCountProvider(VoidRequestStatus.pending).future);

      expect(count, 3);
    });

    test('re-fetches when the date range provider changes', () async {
      final seed = [
        _req('old', createdAt: DateTime(2020, 1, 1),
            status: VoidRequestStatus.pending),
        _req('new', createdAt: DateTime(2026, 7, 25, 10),
            status: VoidRequestStatus.pending),
      ];
      final c = _container(seed, overrides: [
        voidRequestDateRangeProvider.overrideWith((ref) => _fixedSeedDateRange),
      ]);
      addTearDown(c.dispose);

      final before = await c
          .read(voidRequestStatusCountProvider(VoidRequestStatus.pending).future);
      expect(before, 1,
          reason: 'initial fixed range only covers "new"');

      c.read(voidRequestDateRangeProvider.notifier).state = DateTimeRange(
        start: DateTime(2020, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59, 999),
      );
      final after = await c
          .read(voidRequestStatusCountProvider(VoidRequestStatus.pending).future);

      expect(after, 2);
    });
  });

  group('dateRangeForPreset end-of-day', () {
    test('default voidRequestDateRangeProvider covers requests created at '
        '23:59:59.900 today', () {
      final c = _container([]);
      addTearDown(c.dispose);

      final range = c.read(voidRequestDateRangeProvider);
      // The last moment of the SHOP day, as an instant — the shop clock is
      // what defines "today" now, not the device's.
      final shopToday = DateTime.now().inShopTime;
      final lateToday = instantOf(
          shopWall(shopToday.year, shopToday.month, shopToday.day, 23, 59, 59,
              900),
          ShopTimeConfig.offsetMinutes);

      expect(range.end.isBefore(lateToday), isFalse,
          reason: 'provider default must normalize dateRangeForPreset\'s '
              'end to true end-of-day (23:59:59.999), not 23:59:59.000');
    });
  });
}

List<VoidRequestEntity> _pendingBatch(int n) => List.generate(
      n,
      (i) => _req('pending-$i', createdAt: DateTime(2026, 7, 25, 10, i)),
    );
