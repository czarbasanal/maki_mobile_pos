import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expense_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/expense_row.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u-1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  ExpenseEntity expense({String? receiptImageUrl}) => ExpenseEntity(
        id: 'e-1',
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'U',
        receiptImageUrl: receiptImageUrl,
      );

  Future<void> pump(
    WidgetTester tester, {
    required UserRole role,
    String? receiptImageUrl,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
        expensesProvider.overrideWith(
            (ref) => Stream.value([expense(receiptImageUrl: receiptImageUrl)])),
        activeCategoriesProvider(CategoryKind.expense)
            .overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: ExpenseHistoryScreen()),
    ));
    await tester.pump(); // streams emit
    await tester.pump();
  }

  testWidgets('admin rows are tappable', (tester) async {
    await pump(tester, role: UserRole.admin);
    final row = tester.widget<ExpenseRow>(find.byType(ExpenseRow));
    expect(row.onTap, isNotNull);
  });

  testWidgets('cashier rows are tappable too (editExpense granted 2026-07-04)',
      (tester) async {
    await pump(tester, role: UserRole.cashier);
    final row = tester.widget<ExpenseRow>(find.byType(ExpenseRow));
    expect(row.onTap, isNotNull);
  });

  testWidgets('paperclip shows when the expense has a receipt',
      (tester) async {
    await pump(tester,
        role: UserRole.admin, receiptImageUrl: 'https://x/r.jpg');
    expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
  });

  testWidgets('no paperclip without a receipt', (tester) async {
    await pump(tester, role: UserRole.admin);
    expect(find.byIcon(LucideIcons.paperclip), findsNothing);
  });
}
