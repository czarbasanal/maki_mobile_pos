import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/void_request_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late VoidRequestRepositoryImpl repo;

  // Two-day window: day 1 (in-window) holds 3 pending + 1 approved; day 2
  // (out-of-window) holds a pending request that must never surface.
  final day1Start = DateTime(2026, 7, 20);
  final day2 = DateTime(2026, 7, 21);

  Future<void> seed(String id, {required DateTime at, required String status}) {
    return fake.collection('void_requests').doc(id).set({
      'saleId': 'sale-$id',
      'saleNumber': 'S-$id',
      'saleGrandTotal': 100.0,
      'requestedBy': 'u1',
      'requestedByName': 'Cashier',
      'requestedByRole': 'cashier',
      'reason': 'test',
      'status': status,
      'read': false,
      'createdAt': Timestamp.fromDate(at),
    });
  }

  setUp(() async {
    fake = FakeFirebaseFirestore();
    repo = VoidRequestRepositoryImpl(firestore: fake);

    // Day 1 — in-window: 3 pending (ascending createdAt) + 1 approved.
    await seed('p1', at: day1Start.add(const Duration(hours: 1)), status: 'pending');
    await seed('p2', at: day1Start.add(const Duration(hours: 2)), status: 'pending');
    await seed('p3', at: day1Start.add(const Duration(hours: 3)), status: 'pending');
    await seed('a1', at: day1Start.add(const Duration(hours: 4)), status: 'approved');
    // Day 2 — out-of-window pending request.
    await seed('p4-outside', at: day2.add(const Duration(hours: 1)), status: 'pending');
  });

  final windowStart = day1Start;
  final windowEnd = day1Start.add(const Duration(hours: 23, minutes: 59));

  group('getRequestsPage', () {
    test('filters by status', () async {
      final page = await repo.getRequestsPage(
        status: VoidRequestStatus.approved,
        start: windowStart,
        end: windowEnd,
      );

      expect(page, hasLength(1));
      expect(page.single.id, 'a1');
    });

    test('excludes items outside the date window', () async {
      final page = await repo.getRequestsPage(
        status: VoidRequestStatus.pending,
        start: windowStart,
        end: windowEnd,
      );

      expect(page.map((r) => r.id), isNot(contains('p4-outside')));
      expect(page, hasLength(3));
    });

    test('null status returns all statuses in window, newest first', () async {
      final page = await repo.getRequestsPage(
        start: windowStart,
        end: windowEnd,
      );

      expect(page.map((r) => r.id), ['a1', 'p3', 'p2', 'p1']);
    });

    test('limit + startAfterId pages without duplicates', () async {
      final firstPage = await repo.getRequestsPage(
        status: VoidRequestStatus.pending,
        start: windowStart,
        end: windowEnd,
        limit: 2,
      );
      expect(firstPage.map((r) => r.id), ['p3', 'p2']);

      final secondPage = await repo.getRequestsPage(
        status: VoidRequestStatus.pending,
        start: windowStart,
        end: windowEnd,
        limit: 2,
        startAfterId: firstPage.last.id,
      );

      expect(secondPage.map((r) => r.id), ['p1']);
      final allIds = [...firstPage, ...secondPage].map((r) => r.id).toList();
      expect(allIds.toSet(), hasLength(allIds.length),
          reason: 'no duplicates across pages');
    });
  });

  group('countByStatus', () {
    test('counts requests with the given status in-window', () async {
      final count = await repo.countByStatus(
        status: VoidRequestStatus.pending,
        start: windowStart,
        end: windowEnd,
      );

      expect(count, 3);
    });
  });
}
