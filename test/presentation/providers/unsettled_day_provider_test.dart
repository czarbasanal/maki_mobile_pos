// Task 3: unsettledBusinessDayProvider — oldest unclosed sales-day detector.
//
// Algorithm under test (exact, from the task-3 brief): starting from the day
// after the latest closing (or 14 days back from "today" if there is no
// closing yet, capped at 14 days), scan forward day-by-day up to (but not
// including) "today". A day that already has a closing is a settled gap and
// is skipped. A day with no closing AND at least one completed sale is the
// oldest unsettled day — return it immediately. A day with no closing and no
// sales is skipped (nothing to settle). If nothing qualifies, return null.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';

/// Fake [DailyClosingRepository] — extends [Mock] so unstubbed members
/// (not exercised by this provider) fall back to Mock's `noSuchMethod`,
/// while the two members the algorithm actually calls are given real,
/// mutable in-memory behavior.
class _FakeDailyClosingRepository extends Mock
    implements DailyClosingRepository {
  final Map<String, DailyClosingEntity> _closings = {};

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void addClosing(DateTime date) {
    _closings[_key(date)] = _closingFor(date);
  }

  @override
  Future<DailyClosingEntity?> getClosing(DateTime date) async =>
      _closings[_key(date)];

  @override
  Future<DailyClosingEntity?> latestClosing() async {
    if (_closings.isEmpty) return null;
    final sorted = _closings.values.toList()
      ..sort((a, b) => b.businessDate.compareTo(a.businessDate));
    return sorted.first;
  }
}

/// Fake [SaleRepository] — same "extends Mock, override just what's used"
/// shape as the closing fake above.
class _FakeSaleRepository extends Mock implements SaleRepository {
  final Set<String> _datesWithSales = {};

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void addSaleOn(DateTime date) => _datesWithSales.add(_key(date));

  @override
  Future<bool> hasCompletedSaleOn(DateTime date) async =>
      _datesWithSales.contains(_key(date));
}

DailyClosingEntity _closingFor(DateTime date) => DailyClosingEntity(
      id: _FakeDailyClosingRepository._key(date),
      businessDate: date,
      grossSales: 0,
      netSales: 0,
      totalDiscounts: 0,
      cashSales: 0,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      openingFloat: 0,
      expectedCash: 0,
      countedCash: 0,
      variance: 0,
      salesCount: 0,
      voidedCount: 0,
      closedBy: 'u1',
      closedByName: 'Closer',
      closedAt: date,
    );

class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;
}

void main() {
  final today = DateTime(2026, 7, 25);

  late _FakeDailyClosingRepository closingRepo;
  late _FakeSaleRepository saleRepo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      businessDayProvider
          .overrideWith(() => _FixedBusinessDayNotifier(today)),
      dailyClosingRepositoryProvider.overrideWithValue(closingRepo),
      saleRepositoryProvider.overrideWithValue(saleRepo),
      // dailyClosingHistoryProvider streams from the same repo override —
      // give it a value so the provider doesn't hit real Firestore/auth.
      dailyClosingHistoryProvider
          .overrideWith((ref) => Stream.value(const <DailyClosingEntity>[])),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    closingRepo = _FakeDailyClosingRepository();
    saleRepo = _FakeSaleRepository();
  });

  // The provider watches [dailyClosingHistoryProvider] (a StreamProvider)
  // purely for its invalidation side-effect. If that stream provider is
  // still AsyncLoading — i.e. hasn't delivered its first event yet — at the
  // moment the FutureProvider we're reading finishes its async build,
  // Riverpod's dependency tracking holds the read open forever. Draining the
  // stream provider's `.future` first guarantees it's already AsyncData
  // before `unsettledBusinessDayProvider` is read, sidestepping that timing
  // window. (Pure test-harness plumbing — not a behavior of the algorithm.)
  Future<DateTime?> readUnsettled(ProviderContainer container) async {
    await container.read(dailyClosingHistoryProvider.future);
    return container.read(unsettledBusinessDayProvider.future);
  }

  test('no closings + no sales in the scan window -> null', () async {
    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, isNull);
  });

  test('a gap day with a completed sale is the unsettled day', () async {
    final gapDay = today.subtract(const Duration(days: 3));
    saleRepo.addSaleOn(gapDay);

    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, gapDay);
  });

  test('a gap day with zero sales is skipped, not flagged', () async {
    // No closings, no sales anywhere in the window -> null, even though
    // every day in [today-14, today) is technically "open".
    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, isNull);
  });

  test('two unsettled gaps with sales -> the OLDEST is returned', () async {
    final olderGap = today.subtract(const Duration(days: 6));
    final newerGap = today.subtract(const Duration(days: 2));
    saleRepo.addSaleOn(olderGap);
    saleRepo.addSaleOn(newerGap);

    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, olderGap);
  });

  test('a day beyond the 14-day cap is never scanned, even with sales',
      () async {
    final beyondCap = today.subtract(const Duration(days: 15));
    saleRepo.addSaleOn(beyondCap);

    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, isNull);
  });

  test(
      'closing the unsettled day (repo mutated + closing history '
      'invalidated) advances the detector to the next gap / clears it',
      () async {
    final firstGap = today.subtract(const Duration(days: 5));
    final secondGap = today.subtract(const Duration(days: 2));
    saleRepo.addSaleOn(firstGap);
    saleRepo.addSaleOn(secondGap);

    final container = makeContainer();
    final before = await readUnsettled(container);
    expect(before, firstGap);

    // Simulate closeDay(): the closing lands in the repo and the same
    // invalidation closeDay already fires (dailyClosingHistoryProvider).
    closingRepo.addClosing(firstGap);
    container.invalidate(dailyClosingHistoryProvider);
    container.invalidate(unsettledBusinessDayProvider);

    final after = await readUnsettled(container);
    expect(after, secondGap);
  });

  test('closing the only unsettled day clears the detector to null',
      () async {
    final onlyGap = today.subtract(const Duration(days: 1));
    saleRepo.addSaleOn(onlyGap);

    final container = makeContainer();
    final before = await readUnsettled(container);
    expect(before, onlyGap);

    closingRepo.addClosing(onlyGap);
    container.invalidate(dailyClosingHistoryProvider);
    container.invalidate(unsettledBusinessDayProvider);

    final after = await readUnsettled(container);
    expect(after, isNull);
  });
}
