import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expenses_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// N3 — cashiers get a view scoped to today: Week-to-date and Month-to-date
/// summary cards hidden (Today remains) and the "Recent" list shows only
/// today's expenses. Staff/admin see the screen unchanged.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._fixed);
  final DateTime _fixed;

  @override
  DateTime build() => _fixed;
}

void main() {
  final businessToday = DateTime(2026, 7, 26);

  UserEntity user(UserRole role) => UserEntity(
        id: 'u-1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  ExpenseEntity expense({
    required String id,
    required DateTime date,
    String description = 'Diesel',
  }) =>
      ExpenseEntity(
        id: id,
        description: description,
        amount: 500,
        category: 'Fuel',
        date: date,
        createdAt: date,
        createdBy: 'u-1',
        createdByName: 'U',
      );

  Future<void> pump(
    WidgetTester tester, {
    required UserRole role,
    required List<ExpenseEntity> expenses,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
        expensesProvider.overrideWith((ref) => Stream.value(expenses)),
        activeCategoriesProvider(CategoryKind.expense)
            .overrideWith((ref) => Stream.value(const [])),
        totalExpensesProvider.overrideWith((ref, params) async => 0),
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(businessToday)),
      ],
      child: const MaterialApp(home: ExpensesScreen()),
    ));
    await tester.pump(); // streams emit
    await tester.pump();
  }

  group('cashier', () {
    testWidgets('sees only the Today summary card (Week/Month hidden)',
        (tester) async {
      await pump(tester, role: UserRole.cashier, expenses: [
        expense(id: 'e-today', date: businessToday),
      ]);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsNothing);
      expect(find.text('This Month'), findsNothing);
    });

    testWidgets('does not see the View all link into full history',
        (tester) async {
      await pump(tester, role: UserRole.cashier, expenses: [
        expense(id: 'e-today', date: businessToday),
      ]);

      expect(find.textContaining('View all'), findsNothing);
    });

    testWidgets("list omits yesterday's expense but shows today's",
        (tester) async {
      final yesterday = businessToday.subtract(const Duration(days: 1));
      await pump(tester, role: UserRole.cashier, expenses: [
        expense(id: 'e-today', date: businessToday, description: 'Today gas'),
        expense(
            id: 'e-yesterday', description: 'Yesterday gas', date: yesterday),
      ]);

      expect(find.text('Today gas'), findsOneWidget);
      expect(find.text('Yesterday gas'), findsNothing);
    });
  });

  group('staff', () {
    testWidgets('still sees the View all link', (tester) async {
      await pump(tester, role: UserRole.staff, expenses: [
        expense(id: 'e-today', date: businessToday),
      ]);

      expect(find.textContaining('View all'), findsOneWidget);
    });

    testWidgets('still sees all three summary cards', (tester) async {
      await pump(tester, role: UserRole.staff, expenses: [
        expense(id: 'e-today', date: businessToday),
      ]);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets("still sees yesterday's expense in the list", (tester) async {
      final yesterday = businessToday.subtract(const Duration(days: 1));
      await pump(tester, role: UserRole.staff, expenses: [
        expense(id: 'e-today', date: businessToday, description: 'Today gas'),
        expense(
            id: 'e-yesterday', description: 'Yesterday gas', date: yesterday),
      ]);

      expect(find.text('Today gas'), findsOneWidget);
      expect(find.text('Yesterday gas'), findsOneWidget);
    });
  });
}
