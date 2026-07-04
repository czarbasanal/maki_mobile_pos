import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';

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

  Widget harness() => ProviderScope(
        overrides: [
          dailyClosingForDateProvider.overrideWith((ref, date) async => null),
          dailyClosingDataProvider.overrideWith((ref, date) async => data()),
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

  testWidgets('removing an expense recomputes totals and expected cash',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Included: 150 cash + 50 gcash → total ₱200.00 (cash row shows ₱150.00)
    expect(find.text('₱200.00'), findsOneWidget); // Total expenses row
    await tester.tap(find.byIcon(LucideIcons.x).first); // remove e1 (₱150)
    await tester.pumpAndSettle();

    expect(find.text('₱50.00'), findsWidgets); // new total (also e2 row amount)
    expect(find.text('Restore'), findsOneWidget);

    // Restore brings it back
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('₱200.00'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });
}
