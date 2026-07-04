import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';

ExpenseEntity _exp(String id, double amount,
        {PaymentMethod paidVia = PaymentMethod.cash}) =>
    ExpenseEntity(
      id: id,
      description: 'Expense $id',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 7, 4),
      paidVia: paidVia,
      createdAt: DateTime(2026, 7, 4),
      createdBy: '',
      createdByName: '',
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<ExpenseEntity> expenses,
    Set<String> excludedIds = const {},
    void Function(String)? onToggle,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClosingExpenseList(
          expenses: expenses,
          excludedIds: excludedIds,
          onToggle: onToggle ?? (_) {},
        ),
      ),
    ));
  }

  testWidgets('renders one row per expense with description and amount',
      (tester) async {
    await pump(tester, expenses: [_exp('e1', 150), _exp('e2', 50)]);
    expect(find.text('Expense e1'), findsOneWidget);
    expect(find.text('Expense e2'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNWidgets(2));
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('excluded row shows Restore instead of the remove button',
      (tester) async {
    await pump(tester,
        expenses: [_exp('e1', 150), _exp('e2', 50)],
        excludedIds: const {'e2'});
    expect(find.byIcon(LucideIcons.x), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('tapping remove and Restore both fire onToggle with the id',
      (tester) async {
    final toggled = <String>[];
    await pump(tester,
        expenses: [_exp('e1', 150), _exp('e2', 50)],
        excludedIds: const {'e2'},
        onToggle: toggled.add);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.tap(find.text('Restore'));
    expect(toggled, ['e1', 'e2']);
  });
}
