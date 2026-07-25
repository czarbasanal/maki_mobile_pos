import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/expense_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';

/// A [businessDayProvider] override with no timer — see
/// end_of_day_plate_amount_submit_test.dart for why a real (unoverridden)
/// build would trip flutter_test's "no pending timers" invariant.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._fixed);
  final DateTime _fixed;

  @override
  DateTime build() => _fixed;
}

/// Records deleteExpense calls instead of hitting the real use-case chain.
class _FakeExpenseOps extends ExpenseOperationsNotifier {
  _FakeExpenseOps(super.ref);
  final deleted = <String>[];

  @override
  Future<bool> deleteExpense(String expenseId) async {
    deleted.add(expenseId);
    return true;
  }
}

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

ExpenseEntity _exp(String id, double amount, DateTime d,
        {PaymentMethod paidVia = PaymentMethod.cash}) =>
    ExpenseEntity(
      id: id,
      description: 'Expense $id',
      amount: amount,
      category: 'c',
      date: d,
      paidVia: paidVia,
      createdAt: d,
      createdBy: '',
      createdByName: '',
    );

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  DailyClosingData data() => DailyClosingData(
        businessDate: dayStart,
        summary: const SalesSummary(
          totalSalesCount: 2,
          voidedSalesCount: 0,
          grossAmount: 1000,
          totalDiscounts: 0,
          netAmount: 1000,
          totalCost: 0,
          totalProfit: 1000,
          byPaymentMethod: {PaymentMethod.cash: 700},
        ),
        expenses: [
          _exp('e1', 150, dayStart),
          _exp('e2', 50, dayStart, paidVia: PaymentMethod.gcash),
        ],
      );

  Widget harness({List<Override> extraOverrides = const []}) => ProviderScope(
        overrides: [
          businessDayProvider
              .overrideWith(() => _FixedBusinessDayNotifier(dayStart)),
          unsettledBusinessDayProvider.overrideWith((ref) async => null),
          dailyClosingForDateProvider.overrideWith((ref, date) async => null),
          dailyClosingDataProvider.overrideWith((ref, date) async => data()),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      );

  testWidgets('review lists the day expenses itemized with an Add button',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(ClosingExpenseList), findsOneWidget);
    expect(find.text('Expense e1'), findsOneWidget);
    expect(find.text('Expense e2'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Close Day'), findsOneWidget);
  });

  testWidgets('removing an expense via the menu recomputes totals',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Included: 150 cash + 50 gcash → total ₱200.00 (cash row shows ₱150.00)
    expect(find.text('₱200.00'), findsOneWidget); // Total expenses row
    await tester.tap(find.byIcon(LucideIcons.x).first); // e1 (₱150) menu
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from closing'));
    await tester.pumpAndSettle();

    expect(find.text('₱50.00'), findsWidgets); // new total (also e2 row amount)
    expect(find.text('Restore'), findsOneWidget);

    // Restore brings it back
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('₱200.00'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('Delete expense asks for confirmation, then deletes',
      (tester) async {
    _FakeExpenseOps? ops;
    await tester.pumpWidget(harness(extraOverrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
      expenseOperationsProvider
          .overrideWith((ref) => ops = _FakeExpenseOps(ref)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.x).first); // e1 menu
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete expense'));
    await tester.pumpAndSettle();

    expect(find.text('Delete expense?'), findsOneWidget);
    // Nothing deleted before confirm — the ops notifier hasn't even been
    // instantiated yet (it's created lazily on first read at delete time).
    expect(ops?.deleted ?? const [], isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ops!.deleted, ['e1']);
    expect(find.text('Expense deleted'), findsOneWidget); // success snackbar
  });

  testWidgets('cancelling the delete confirmation deletes nothing',
      (tester) async {
    _FakeExpenseOps? ops;
    await tester.pumpWidget(harness(extraOverrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
      expenseOperationsProvider
          .overrideWith((ref) => ops = _FakeExpenseOps(ref)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Never read → never created → nothing deleted.
    expect(ops?.deleted ?? const [], isEmpty);
  });
}
