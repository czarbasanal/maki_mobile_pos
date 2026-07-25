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

  group('monthToDateSummaryProvider', () {
    test('start stays the 1st of the month; end follows the flipped day',
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
      final sub = container.listen(monthToDateSummaryProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(monthToDateSummaryProvider.future);
      var captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1));
      expect(captured[1], DateTime(2026, 7, 24, 23, 59, 59, 999));

      dayNotifier.set(DateTime(2026, 7, 25));
      await Future<void>.delayed(Duration.zero);
      await container.read(monthToDateSummaryProvider.future);
      captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1)); // same month, unchanged
      expect(captured[1], DateTime(2026, 7, 25, 23, 59, 59, 999));
    });
  });

  group('avgDailySalesProvider', () {
    test('daysElapsed follows businessDayProvider and recomputes on flip',
        () async {
      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 15));
      final container = ProviderContainer(overrides: [
        monthToDateSummaryProvider.overrideWith(
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

      // Day 15 → 14 elapsed past days → 1400 / 14 = 100.
      final sub = container.listen(avgDailySalesProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(monthToDateSummaryProvider.future);
      expect(container.read(avgDailySalesProvider).value, 100);

      // Flip to day 8 (still July) → 7 elapsed days → 1400 / 7 = 200.
      dayNotifier.set(DateTime(2026, 7, 8));
      expect(container.read(avgDailySalesProvider).value, 200);
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
