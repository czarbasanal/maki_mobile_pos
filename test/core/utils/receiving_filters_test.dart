import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/receiving_month.dart';
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
