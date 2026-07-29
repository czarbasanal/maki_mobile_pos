// Proves the Task 2 swap: today-scoped sale providers watch
// [businessDayProvider] instead of taking a `DateTime.now()` snapshot at
// build time, so they recompute their queried range on a midnight flip.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

/// A [businessDayProvider] override whose value can be flipped directly
/// from a test, without waiting on a real [Timer] or the wall clock —
/// mirrors the "flip the overridden day" pattern the brief calls for.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void set(DateTime day) => state = day;
}

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

SaleEntity _sale(String id, DateTime createdAt) => SaleEntity(
      id: id,
      saleNumber: 'SALE-$id',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU',
          name: 'Item',
          unitPrice: 100,
          unitCost: 60,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100,
      changeGiven: 0,
      status: SaleStatus.completed,
      cashierId: 'u1',
      cashierName: 'Cashier',
      createdAt: createdAt,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  group('todaysSalesSummaryProvider', () {
    test('queried range follows businessDayProvider and recomputes on flip',
        () async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty());

      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(todaysSalesSummaryProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(todaysSalesSummaryProvider.future);
      var captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 24));
      expect(captured[1], DateTime(2026, 7, 24, 23, 59, 59, 999));

      // Flip the business day — the provider must re-run with tomorrow's
      // range, not stay pinned to the day it first built on.
      dayNotifier.set(DateTime(2026, 7, 25));
      await Future<void>.delayed(Duration.zero);
      await container.read(todaysSalesSummaryProvider.future);
      captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 25));
      expect(captured[1], DateTime(2026, 7, 25, 23, 59, 59, 999));
    });
  });

  group('monthCompletedDaysSummaryProvider', () {
    test('queries the 1st through end of YESTERDAY, and follows the flip',
        () async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty());

      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(monthCompletedDaysSummaryProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(monthCompletedDaysSummaryProvider.future);
      var captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1));
      // End of the 23rd — today (the 24th) is NOT included.
      expect(captured[1], DateTime(2026, 7, 23, 23, 59, 59, 999));

      dayNotifier.set(DateTime(2026, 7, 25));
      await Future<void>.delayed(Duration.zero);
      await container.read(monthCompletedDaysSummaryProvider.future);
      captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1));
      expect(captured[1], DateTime(2026, 7, 24, 23, 59, 59, 999));
    });

    test('issues NO query on the 1st — there are no completed days', () async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty());

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(DateTime(2026, 7, 1))),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(monthCompletedDaysSummaryProvider, (_, __) {});
      addTearDown(sub.close);

      final summary =
          await container.read(monthCompletedDaysSummaryProvider.future);

      expect(summary.grossAmount, 0);
      verifyNever(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ));
    });
  });

  group('avgDailySalesProvider — completed-days average', () {
    Future<AsyncValue<double?>> readAvg(DateTime day, double gross) async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary(
                totalSalesCount: 0,
                voidedSalesCount: 0,
                grossAmount: gross,
                totalDiscounts: 0,
                netAmount: 0,
                totalCost: 0,
                totalProfit: 0,
                byPaymentMethod: const {},
              ));

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(day)),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(monthCompletedDaysSummaryProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(monthCompletedDaysSummaryProvider.future);
      return container.read(avgDailySalesProvider);
    }

    test('divides by completed days only', () async {
      // The 25th → 24 completed days. 2400 / 24 = 100.
      final avg = await readAvg(DateTime(2026, 7, 25), 2400);
      expect(avg.valueOrNull, 100);
    });

    test('returns null on the 1st rather than a misleading zero', () async {
      final avg = await readAvg(DateTime(2026, 7, 1), 0);
      expect(avg.valueOrNull, isNull);
    });

    // Retained from the pre-existing `avgDailySalesProvider` group (not
    // superseded by the two tests above): proves the provider watches
    // businessDayProvider directly and recomputes on a clock flip, even
    // when the upstream summary provider is held fixed.
    test('daysElapsed follows businessDayProvider and recomputes on flip',
        () async {
      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 15));
      final container = ProviderContainer(overrides: [
        monthCompletedDaysSummaryProvider.overrideWith(
          (ref) async => const SalesSummary(
            totalSalesCount: 1,
            voidedSalesCount: 0,
            grossAmount: 1400,
            totalDiscounts: 0,
            netAmount: 1400,
            totalCost: 0,
            totalProfit: 1400,
            byPaymentMethod: {},
          ),
        ),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);

      // Day 15 → 14 completed days → 1400 / 14 = 100.
      final sub = container.listen(avgDailySalesProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(monthCompletedDaysSummaryProvider.future);
      expect(container.read(avgDailySalesProvider).valueOrNull, 100);

      // Flip to day 8 (still July) → 7 completed days → 1400 / 7 = 200.
      dayNotifier.set(DateTime(2026, 7, 8));
      expect(container.read(avgDailySalesProvider).valueOrNull, 200);
    });
  });

  group('todaysSalesProvider', () {
    test('watched date follows businessDayProvider and re-subscribes on flip',
        () async {
      final repo = _MockSaleRepository();
      when(() => repo.watchSalesForDay(date: any(named: 'date')))
          .thenAnswer((_) => Stream.value(<SaleEntity>[]));

      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(todaysSalesProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(todaysSalesProvider.future);
      verify(() => repo.watchSalesForDay(date: DateTime(2026, 7, 24)))
          .called(1);

      dayNotifier.set(DateTime(2026, 7, 25));
      // Re-subscribing to a new stream settles asynchronously.
      await Future<void>.delayed(Duration.zero);
      verify(() => repo.watchSalesForDay(date: DateTime(2026, 7, 25)))
          .called(1);
    });
  });

  group('topSellingTodayProvider chain', () {
    test('recomputes when todaysSalesProvider re-subscribes on a day flip',
        () async {
      final repo = _MockSaleRepository();
      when(() => repo.watchSalesForDay(date: DateTime(2026, 7, 24)))
          .thenAnswer((_) => Stream.value([_sale('a', DateTime(2026, 7, 24))]));
      when(() => repo.watchSalesForDay(date: DateTime(2026, 7, 25)))
          .thenAnswer((_) => Stream.value([
                _sale('b', DateTime(2026, 7, 25)),
                _sale('c', DateTime(2026, 7, 25)),
              ]));

      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(topSellingTodayProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(todaysSalesProvider.future);
      var top = container.read(topSellingTodayProvider).value!;
      expect(top, hasLength(1));
      expect(top.first.quantitySold, 1);

      dayNotifier.set(DateTime(2026, 7, 25));
      await Future<void>.delayed(Duration.zero);
      top = container.read(topSellingTodayProvider).value!;
      expect(top, hasLength(1));
      expect(top.first.quantitySold, 2, // both new-day sales are the same item
          reason: 'chain must recompute from the new day\'s sales, not the'
              ' old ones');
    });
  });
}
