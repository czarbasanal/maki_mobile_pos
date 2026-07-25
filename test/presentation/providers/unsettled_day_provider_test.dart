// Task 3: unsettledBusinessDayProvider — oldest unclosed sales-day detector.
//
// Algorithm under test (exact, from the task-3 brief): starting from the day
// after the latest closing (or 14 days back from "today" if there is no
// closing yet, capped at 14 days), scan forward day-by-day up to (but not
// including) "today". A day that already has a closing is a settled gap and
// is skipped. A day with no closing AND at least one completed sale is the
// oldest unsettled day — return it immediately. A day with no closing and no
// sales is skipped (nothing to settle). If nothing qualifies, return null.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';

/// Fake [DailyClosingRepository] — extends [Mock] so unstubbed members
/// (not exercised by this provider) fall back to Mock's `noSuchMethod`,
/// while the members the algorithm (and its reactive re-run wiring) actually
/// call are given real, mutable in-memory behavior.
///
/// [watchClosings] is backed by a real [StreamController] so the tests can
/// drive [dailyClosingHistoryProvider] — and through its
/// `ref.watch(dailyClosingHistoryProvider)` link,
/// [unsettledBusinessDayProvider] — the same way `closeDay` does in
/// production: mutate the repo, then invalidate
/// `dailyClosingHistoryProvider` (never the detector itself).
class _FakeDailyClosingRepository extends Mock
    implements DailyClosingRepository {
  final Map<String, DailyClosingEntity> _closings = {};
  final _controller = StreamController<List<DailyClosingEntity>>.broadcast();

  /// Task 6 / Fix 2b: the raw `drawer_state/state` doc backing
  /// [getDrawerState]. Defaults to "never written" — the same as a fresh
  /// DB — until a test calls [setDrawerState].
  DrawerState _drawerState = const DrawerState.empty();

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void addClosing(DateTime date) {
    _closings[_key(date)] = _closingFor(date);
    _controller.add(_closings.values.toList());
  }

  void setDrawerState({int? lastSaleDay, int? lastClosedDay}) {
    _drawerState =
        DrawerState(lastSaleDay: lastSaleDay, lastClosedDay: lastClosedDay);
  }

  void disposeStream() => _controller.close();

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

  @override
  Future<DrawerState> getDrawerState() async => _drawerState;

  // Mirrors a real Firestore snapshot stream: yields the current state
  // immediately on subscription, then forwards subsequent mutations.
  @override
  Stream<List<DailyClosingEntity>> watchClosings({int limit = 60}) async* {
    yield _closings.values.toList();
    yield* _controller.stream;
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

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

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
      // currentUserProvider needs an active user: dailyClosingHistoryProvider
      // is NOT stubbed here (unlike before) — it's the real provider, gated
      // by authGatedStream on `ref.watch(currentUserProvider.future)`, and
      // it streams from closingRepo.watchClosings() via the
      // dailyClosingRepositoryProvider override above. This is what lets the
      // tests below drive the detector's re-run purely by mutating the fake
      // repo + invalidating dailyClosingHistoryProvider, exactly like
      // closeDay does — instead of invalidating the detector directly.
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    closingRepo = _FakeDailyClosingRepository();
    saleRepo = _FakeSaleRepository();
    addTearDown(() => closingRepo.disposeStream());
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

  test(
      'a gap day with zero sales is skipped, not flagged (mixed scan window)',
      () async {
    // today-3: has sales, unclosed -> the initial unsettled day.
    // today-2: NO sales at all -> must be skipped, not returned.
    // today-1: has sales, unclosed -> becomes unsettled only once today-3
    //          is closed, proving today-2 was scanned past, not flagged.
    final saleDay1 = today.subtract(const Duration(days: 3));
    final zeroSaleDay = today.subtract(const Duration(days: 2));
    final saleDay2 = today.subtract(const Duration(days: 1));
    saleRepo.addSaleOn(saleDay1);
    saleRepo.addSaleOn(saleDay2);
    // zeroSaleDay deliberately gets no sale — confirm that, then confirm
    // it's never what the detector reports below.
    expect(await saleRepo.hasCompletedSaleOn(zeroSaleDay), isFalse);

    final container = makeContainer();
    final before = await readUnsettled(container);
    expect(before, saleDay1);
    expect(before, isNot(zeroSaleDay));

    // Simulate closeDay(): mutate the repo, then invalidate
    // dailyClosingHistoryProvider only (never the detector directly).
    closingRepo.addClosing(saleDay1);
    container.invalidate(dailyClosingHistoryProvider);

    final after = await readUnsettled(container);
    expect(after, isNot(zeroSaleDay));
    expect(after, saleDay2,
        reason: 'zeroSaleDay (today-2) has no sales at all and must be '
            'skipped by the scan, never returned as unsettled');
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

  test('a closing already exists for TODAY -> detector returns null',
      () async {
    // An earlier day has an unclosed completed sale — it would normally
    // be flagged as unsettled — but latestClosing() resolves to `today`,
    // which pushes the scan's start date to today+1 (past the < today scan
    // window entirely), so nothing is ever scanned.
    final earlierDay = today.subtract(const Duration(days: 2));
    saleRepo.addSaleOn(earlierDay);
    closingRepo.addClosing(today);

    final container = makeContainer();
    final result = await readUnsettled(container);
    expect(result, isNull);
  });

  test(
      'closing the unsettled day (repo mutated + dailyClosingHistoryProvider '
      'invalidated — detector itself never invalidated) advances the '
      'detector to the next gap', () async {
    // This proves the REACTIVE link: unsettledBusinessDayProvider's own
    // `ref.watch(dailyClosingHistoryProvider)` line is what picks up the
    // change below — production's closeDay never invalidates the detector
    // directly, only dailyClosingHistoryProvider. (Verified manually during
    // RED: commenting out that `ref.watch(dailyClosingHistoryProvider)` line
    // in unsettled_day_provider.dart makes this test fail — `after` stays
    // stuck at `firstGap`.)
    final firstGap = today.subtract(const Duration(days: 5));
    final secondGap = today.subtract(const Duration(days: 2));
    saleRepo.addSaleOn(firstGap);
    saleRepo.addSaleOn(secondGap);

    final container = makeContainer();
    final before = await readUnsettled(container);
    expect(before, firstGap);

    // Simulate closeDay(): the closing lands in the repo (which pushes the
    // updated list through the fake's StreamController) and — exactly like
    // closeDay's own invalidation list — dailyClosingHistoryProvider is
    // invalidated. unsettledBusinessDayProvider is NEVER invalidated here.
    closingRepo.addClosing(firstGap);
    container.invalidate(dailyClosingHistoryProvider);

    final after = await readUnsettled(container);
    expect(after, secondGap);
  });

  test(
      'closing the only unsettled day clears the detector to null — '
      'reactive link only, detector never invalidated directly', () async {
    final onlyGap = today.subtract(const Duration(days: 1));
    saleRepo.addSaleOn(onlyGap);

    final container = makeContainer();
    final before = await readUnsettled(container);
    expect(before, onlyGap);

    closingRepo.addClosing(onlyGap);
    container.invalidate(dailyClosingHistoryProvider);

    final after = await readUnsettled(container);
    expect(after, isNull);
  });

  group('drawer_state fallback (Fix 2b)', () {
    // The 14-day scan can't see everything the rules-authoritative
    // drawer_state doc knows about (older gaps, a stale lastClosedDay from a
    // closing whose own drawer_state write raced/failed). When the scan
    // finds nothing, read drawer_state/state directly as a second signal.

    test(
        'scan finds nothing, but drawer_state says a past day had a sale '
        'and was never closed -> fallback returns that day', () async {
      final staleDay = today.subtract(const Duration(days: 2));
      closingRepo.setDrawerState(lastSaleDay: businessDayInt(staleDay));

      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, staleDay);
    });

    test(
        'fallback reaches a gap OLDER than the 14-day scan cap that the scan '
        'itself can never see', () async {
      final beyondCap = today.subtract(const Duration(days: 20));
      closingRepo.setDrawerState(lastSaleDay: businessDayInt(beyondCap));

      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, beyondCap);
    });

    test(
        'drawer_state says the last sale day is already closed -> fallback '
        'stays null', () async {
      final staleDay = today.subtract(const Duration(days: 2));
      closingRepo.setDrawerState(
        lastSaleDay: businessDayInt(staleDay),
        lastClosedDay: businessDayInt(staleDay),
      );

      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, isNull);
    });

    test(
        'drawer_state says the last sale day is TODAY (still live, nothing '
        'to close yet) -> fallback stays null', () async {
      closingRepo.setDrawerState(lastSaleDay: businessDayInt(today));

      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, isNull);
    });

    test('missing drawer_state doc -> fallback stays null (fresh DB)',
        () async {
      // No setDrawerState call: _drawerState defaults to DrawerState.empty().
      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, isNull);
    });

    test(
        'the 14-day scan result wins even when drawer_state also flags an '
        'unsettled day — the scan is authoritative for OLDEST, the fallback '
        'only fires when the scan itself is empty', () async {
      final scanGap = today.subtract(const Duration(days: 5));
      saleRepo.addSaleOn(scanGap);
      // A different (newer) day per drawer_state — must NOT override the
      // scan's oldest-day answer.
      final newerStaleDay = today.subtract(const Duration(days: 1));
      closingRepo.setDrawerState(lastSaleDay: businessDayInt(newerStaleDay));

      final container = makeContainer();
      final result = await readUnsettled(container);
      expect(result, scanGap);
    });
  });
}
