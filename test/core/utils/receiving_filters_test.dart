import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/receiving_filters.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

ReceivingEntity _r({
  required String id,
  required ReceivingStatus status,
  required DateTime createdAt,
  DateTime? completedAt,
  double totalCost = 0,
}) {
  return ReceivingEntity(
    id: id,
    referenceNumber: id.toUpperCase(),
    items: const [],
    totalCost: totalCost,
    totalQuantity: 0,
    status: status,
    createdAt: createdAt,
    completedAt: completedAt,
    createdBy: 'u',
    createdByName: 'User',
  );
}

void main() {
  group('monthToDateCompleted', () {
    final now = DateTime(2026, 5, 15, 12, 0); // mid-May 2026

    test('returns empty for empty input', () {
      expect(monthToDateCompleted(const [], now), isEmpty);
    });

    test('keeps completed receivings completed in this month', () {
      final keep = _r(
        id: 'a',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 1),
        completedAt: DateTime(2026, 5, 10),
      );
      final result = monthToDateCompleted([keep], now);
      expect(result, hasLength(1));
      expect(result.first.id, 'a');
    });

    test('uses completedAt when present, even if createdAt is older', () {
      // Created last month, but completed this month — counts.
      final keep = _r(
        id: 'late',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 4, 28),
        completedAt: DateTime(2026, 5, 2),
      );
      expect(monthToDateCompleted([keep], now), hasLength(1));
    });

    test('falls back to createdAt when completedAt is null', () {
      // No completedAt; createdAt is in this month — count.
      final keep = _r(
        id: 'no-completedAt',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 5),
      );
      expect(monthToDateCompleted([keep], now), hasLength(1));
    });

    test('excludes drafts and cancelled receivings', () {
      final draft = _r(
        id: 'd',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 5, 5),
      );
      final cancelled = _r(
        id: 'c',
        status: ReceivingStatus.cancelled,
        createdAt: DateTime(2026, 5, 5),
      );
      expect(monthToDateCompleted([draft, cancelled], now), isEmpty);
    });

    test('excludes receivings completed before the month boundary', () {
      // Completed Apr 30 — not part of May.
      final old = _r(
        id: 'old',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 4, 28),
        completedAt: DateTime(2026, 4, 30),
      );
      expect(monthToDateCompleted([old], now), isEmpty);
    });

    test('includes receivings completed exactly at month-start midnight', () {
      final boundary = _r(
        id: 'edge',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 1),
        completedAt: DateTime(2026, 5, 1),
      );
      expect(monthToDateCompleted([boundary], now), hasLength(1));
    });
  });

  group('receivingsInCurrentWeek', () {
    // 2026-05-06 is a Wednesday → current week's Monday is 2026-05-04.
    final now = DateTime(2026, 5, 6, 14, 30);

    test('returns empty for empty input', () {
      expect(receivingsInCurrentWeek(const [], now), isEmpty);
    });

    test('keeps receivings created on or after this week\'s Monday', () {
      final monday = _r(
        id: 'mon',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 5, 4, 9),
      );
      final tuesday = _r(
        id: 'tue',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 5, 16),
      );
      final today = _r(
        id: 'wed',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 6, 8),
      );
      final result =
          receivingsInCurrentWeek([monday, tuesday, today], now);
      expect(result.map((r) => r.id), ['mon', 'tue', 'wed']);
    });

    test('excludes receivings created last week', () {
      final lastSunday = _r(
        id: 'last',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 3, 23, 59),
      );
      expect(receivingsInCurrentWeek([lastSunday], now), isEmpty);
    });

    test('includes receivings exactly at Monday-midnight boundary', () {
      final boundary = _r(
        id: 'edge',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 5, 4),
      );
      expect(receivingsInCurrentWeek([boundary], now), hasLength(1));
    });

    test('includes drafts and cancelled, not just completed', () {
      // Recent surface should show in-progress drafts alongside finalized
      // receivings — different filter from monthToDateCompleted.
      final draft = _r(
        id: 'd',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 5, 5),
      );
      final cancelled = _r(
        id: 'c',
        status: ReceivingStatus.cancelled,
        createdAt: DateTime(2026, 5, 5),
      );
      final completed = _r(
        id: 'co',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 5, 5),
      );
      final result =
          receivingsInCurrentWeek([draft, cancelled, completed], now);
      expect(result.map((r) => r.id), ['d', 'c', 'co']);
    });

    test('rolls over correctly when this week starts in a previous month',
        () {
      // 2026-09-02 is a Wednesday → this week's Monday is 2026-08-31.
      final crossNow = DateTime(2026, 9, 2, 10);
      final monday = _r(
        id: 'aug-mon',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 8, 31, 8),
      );
      final julyTail = _r(
        id: 'old',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 8, 30, 23, 59),
      );
      final result =
          receivingsInCurrentWeek([monday, julyTail], crossNow);
      expect(result.map((r) => r.id), ['aug-mon']);
    });
  });

  group('groupByMonthYear', () {
    test('returns empty list for empty input', () {
      expect(groupByMonthYear(const []), isEmpty);
    });

    test('groups by month/year and orders most-recent month first', () {
      final inputs = [
        _r(
          id: 'apr-1',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 4, 5),
          completedAt: DateTime(2026, 4, 5),
        ),
        _r(
          id: 'may-1',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 2),
          completedAt: DateTime(2026, 5, 2),
        ),
        _r(
          id: 'mar-1',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 3, 28),
          completedAt: DateTime(2026, 3, 28),
        ),
      ];

      final groups = groupByMonthYear(inputs);
      expect(groups.map((g) => g.monthStart), [
        DateTime(2026, 5),
        DateTime(2026, 4),
        DateTime(2026, 3),
      ]);
    });

    test('within a group, items are sorted most-recent first', () {
      final inputs = [
        _r(
          id: 'mid',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 10),
          completedAt: DateTime(2026, 5, 10),
        ),
        _r(
          id: 'late',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 20),
          completedAt: DateTime(2026, 5, 20),
        ),
        _r(
          id: 'early',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 1),
          completedAt: DateTime(2026, 5, 1),
        ),
      ];

      final groups = groupByMonthYear(inputs);
      expect(groups, hasLength(1));
      expect(groups.first.items.map((r) => r.id), ['late', 'mid', 'early']);
    });

    test('uses completedAt for the bucket key, falling back to createdAt',
        () {
      // Created in April but completed in May → bucketed under May.
      final lateClose = _r(
        id: 'late-close',
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 4, 30),
        completedAt: DateTime(2026, 5, 2),
      );
      // No completedAt → bucketed by createdAt.
      final draftLikeApr = _r(
        id: 'apr-only',
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 4, 15),
      );

      final groups = groupByMonthYear([lateClose, draftLikeApr]);
      expect(groups.map((g) => g.monthStart), [
        DateTime(2026, 5),
        DateTime(2026, 4),
      ]);
      expect(groups.first.items.single.id, 'late-close');
      expect(groups.last.items.single.id, 'apr-only');
    });

    test('does not mutate the input list ordering', () {
      final input = [
        _r(
          id: 'a',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 10),
          completedAt: DateTime(2026, 5, 10),
        ),
        _r(
          id: 'b',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 20),
          completedAt: DateTime(2026, 5, 20),
        ),
      ];
      final originalOrder = input.map((r) => r.id).toList();
      groupByMonthYear(input);
      expect(input.map((r) => r.id).toList(), originalOrder);
    });
  });

  group('sumTotalCost', () {
    test('returns 0 for empty list', () {
      expect(sumTotalCost(const []), 0);
    });

    test('sums totalCost across receivings', () {
      final list = [
        _r(
          id: '1',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 1),
          totalCost: 100.50,
        ),
        _r(
          id: '2',
          status: ReceivingStatus.completed,
          createdAt: DateTime(2026, 5, 5),
          totalCost: 250.25,
        ),
      ];
      expect(sumTotalCost(list), 350.75);
    });
  });
}
