import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// A [businessDayProvider] override with no timer — see
/// end_of_day_plate_amount_submit_test.dart for why a real (unoverridden)
/// build would trip flutter_test's "no pending timers" invariant.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._fixed);
  final DateTime _fixed;

  @override
  DateTime build() => _fixed;
}

/// Same as [_FixedBusinessDayNotifier] but its date can be flipped after the
/// widget has already resolved its target — used to prove the EOD screen
/// locks its target in initState and never re-reads the clock on rebuild.
class _MutableBusinessDayNotifier extends BusinessDayNotifier {
  _MutableBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void setDay(DateTime d) => state = d;
}

/// Day with parts ₱1,000 + labor ₱450, all cash (drawer holds ₱1,450).
SalesSummary _summary({
  int salesCount = 2,
  double cash = 1450,
  double labor = 450,
}) =>
    SalesSummary(
      totalSalesCount: salesCount,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 0,
      totalProfit: 1000,
      byPaymentMethod: {PaymentMethod.cash: cash},
      laborRevenue: labor,
      laborProfit: labor,
    );

DailyClosingData _data(DateTime date, {SalesSummary? summary}) =>
    DailyClosingData(
      businessDate: date,
      summary: summary ?? _summary(),
      expenses: const [],
    );

DailyClosingEntity _closing(DateTime date) => DailyClosingEntity(
      id: 'today',
      businessDate: date,
      grossSales: 1000,
      netSales: 1000,
      totalDiscounts: 0,
      cashSales: 1450,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      laborRevenue: 450,
      openingFloat: 0,
      expectedCash: 1450,
      // 2000 (not 1450) so 'Sale items → management' = ₱1,550.00 is a
      // string no other row on the screen renders (gross is ₱1,000.00).
      countedCash: 2000,
      variance: 550,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 24, 18, 0),
    );

/// Fixed "today" used across this file's default (no-targetDate) harnesses.
final _businessToday = DateTime(2026, 7, 24);

Widget _harness({
  DailyClosingEntity? closing,
  SalesSummary? liveSummary,
  DateTime? targetDate,
  DateTime? businessDay,
  DateTime? unsettled,
  ValueChanged<DateTime>? onDateRequested,
}) =>
    ProviderScope(
      overrides: [
        businessDayProvider.overrideWith(
            () => _FixedBusinessDayNotifier(businessDay ?? _businessToday)),
        unsettledBusinessDayProvider.overrideWith((ref) async => unsettled),
        dailyClosingForDateProvider.overrideWith((ref, date) async {
          onDateRequested?.call(date);
          return closing;
        }),
        dailyClosingDataProvider.overrideWith(
            (ref, date) async => _data(date, summary: liveSummary)),
      ],
      child: MaterialApp(home: EndOfDayScreen(targetDate: targetDate)),
    );

void main() {
  testWidgets('review: handoff rows appear only once counted cash is entered',
      (tester) async {
    await tester.pumpWidget(_harness(closing: null));
    await tester.pump();
    await tester.pump();
    // Fix 1: the target now resolves via the (async) unsettled-day detector
    // first, one extra hop before the closing/live-data providers even get
    // watched — needs one more pump than before that fix.
    await tester.pump();

    expect(find.text('To mechanics'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('counted-cash')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('counted-cash')),
        matching: find.byType(TextFormField),
      ),
      '3000',
    );
    await tester.pump();

    expect(find.text('To mechanics'), findsOneWidget);
    // ₱450.00 appears twice: 'Labor revenue (service)' in the Sales card
    // plus the mechanics line of the hand-over panel.
    expect(find.text('₱450.00'), findsNWidgets(2));
    expect(find.text('To management'), findsOneWidget);
    expect(find.text('₱2,550.00'), findsOneWidget); // 3000 − 450
  });

  testWidgets('closed view: handoff rows from the frozen record; no drift '
      'section when nothing changed', (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    await tester.pumpWidget(_harness(closing: closing));
    await tester.pump();
    await tester.pump();

    expect(find.text('To mechanics'), findsOneWidget);
    expect(find.text('To management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('closed view: drift shows the shared AfterCloseCard with split',
      (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    // One more cash labor-only sale (₱300) after close.
    await tester.pumpWidget(_harness(
      closing: closing,
      liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750),
    ));
    await tester.pump();
    await tester.pump();
    // Fix 1: the target now resolves via the (async) unsettled-day detector
    // first, one extra hop before the closing/live-data providers even get
    // watched — needs one more pump than before that fix.
    await tester.pump();

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Sale items'), findsOneWidget);
    expect(find.text('Labor fees'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });

  group('target-day resolution (Task 5b)', () {
    testWidgets('default (no targetDate, unsettled not yet loaded): title '
        'is generic and the closing providers are watched with the '
        "business day's date", (tester) async {
      final requested = <DateTime>[];
      await tester.pumpWidget(_harness(
        closing: null,
        businessDay: _businessToday,
        onDateRequested: requested.add,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('End-of-Day Closing'), findsOneWidget);
      expect(find.text('Closing Jul 24'), findsNothing);
      expect(requested, [_businessToday]);
    });

    testWidgets(
        'targetDate provided: shows the dated title and the closing '
        "providers are watched with the target's date, not today's",
        (tester) async {
      final target = DateTime(2026, 7, 20);
      final requested = <DateTime>[];
      await tester.pumpWidget(_harness(
        closing: null,
        businessDay: _businessToday,
        targetDate: target,
        onDateRequested: requested.add,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('End-of-Day Closing'), findsNothing);
      expect(find.text('Closing Jul 20'), findsOneWidget);
      expect(requested, [target]);
    });

    testWidgets(
        'unsettled day already loaded at open: defaults the target to it '
        'rather than today', (tester) async {
      final unsettled = DateTime(2026, 7, 22);
      final requested = <DateTime>[];
      final container = ProviderContainer(overrides: [
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(_businessToday)),
        unsettledBusinessDayProvider.overrideWith((ref) async => unsettled),
        dailyClosingForDateProvider.overrideWith((ref, date) async {
          requested.add(date);
          return null;
        }),
        dailyClosingDataProvider
            .overrideWith((ref, date) async => _data(date)),
      ]);
      addTearDown(container.dispose);
      // Warm the unsettled-day future so it's already loaded (has a value)
      // by the time initState reads it synchronously — matching the brief's
      // "if already loaded" resolution path.
      await container.read(unsettledBusinessDayProvider.future);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EndOfDayScreen()),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Closing Jul 22'), findsOneWidget);
      expect(requested, [unsettled]);
    });

    testWidgets(
        'a businessDayProvider flip after pump does not retarget the '
        'already-open form', (tester) async {
      final requested = <DateTime>[];
      final notifier = _MutableBusinessDayNotifier(_businessToday);
      final container = ProviderContainer(overrides: [
        businessDayProvider.overrideWith(() => notifier),
        unsettledBusinessDayProvider.overrideWith((ref) async => null),
        dailyClosingForDateProvider.overrideWith((ref, date) async {
          requested.add(date);
          return null;
        }),
        dailyClosingDataProvider
            .overrideWith((ref, date) async => _data(date)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EndOfDayScreen()),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('End-of-Day Closing'), findsOneWidget);
      expect(requested, [_businessToday]);

      // Simulate a midnight flip (or a detector change) after the form is
      // already open.
      notifier.setDay(DateTime(2026, 7, 25));
      await tester.pump();
      await tester.pump();

      // Title and watched date are unchanged — the form stayed locked on
      // the day it opened for.
      expect(find.text('End-of-Day Closing'), findsOneWidget);
      expect(find.text('Closing Jul 25'), findsNothing);
      expect(requested, [_businessToday]);
    });

    testWidgets(
        'default (no targetDate), detector STILL LOADING at open: shows the '
        'skeleton (never defaults to today) and locks onto the unsettled '
        "day once the detector's first value arrives (Fix 1)",
        (tester) async {
      final unsettled = DateTime(2026, 7, 20);
      final completer = Completer<DateTime?>();
      final requested = <DateTime>[];
      final container = ProviderContainer(overrides: [
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(_businessToday)),
        // Never resolved until the test completes it below — simulates the
        // detector still being AsyncLoading when initState runs.
        unsettledBusinessDayProvider.overrideWith((ref) => completer.future),
        dailyClosingForDateProvider.overrideWith((ref, date) async {
          requested.add(date);
          return null;
        }),
        dailyClosingDataProvider
            .overrideWith((ref, date) async => _data(date)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EndOfDayScreen()),
      ));
      await tester.pump();

      // Still loading: generic title + skeleton, and NEITHER closing
      // provider has been watched with any date yet — proves the screen did
      // not silently lock onto today while the detector was still pending.
      expect(find.text('End-of-Day Closing'), findsOneWidget);
      expect(find.byType(FormSkeleton), findsOneWidget);
      expect(requested, isEmpty);

      // The detector resolves AFTER the first frame, reporting a past
      // unsettled day.
      completer.complete(unsettled);
      await tester.pump();
      await tester.pump();

      expect(find.text('Closing Jul 20'), findsOneWidget);
      expect(requested, [unsettled]);
    });
  });
}
