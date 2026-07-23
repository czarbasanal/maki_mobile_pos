import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/close_day_usecase.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Covers the pre-merge review fix: a Plate No amount TYPED into a field but
/// never committed via its own "Add" button used to be silently dropped when
/// the user tapped Close Day — into an immutable closing doc. Now Close Day
/// auto-commits any valid pending amount first, and blocks (no confirm
/// dialog, no closeDay call) if the pending text doesn't parse to a positive
/// number.
class _MockCloseDayUseCase extends Mock implements CloseDayUseCase {}

class _FakeUserEntity extends Fake implements UserEntity {}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final user = UserEntity(
    id: 'u-cashier',
    email: 'cashier@test',
    displayName: 'Cashier One',
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
  );

  const summary = SalesSummary(
    totalSalesCount: 1,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {PaymentMethod.cash: 700},
  );

  final data = DailyClosingData(
    businessDate: today,
    summary: summary,
    expenses: const [],
  );

  DailyClosingEntity savedClosing() => DailyClosingEntity(
        id: 'closing-1',
        businessDate: today,
        grossSales: 1000,
        netSales: 1000,
        totalDiscounts: 0,
        cashSales: 700,
        nonCashSales: 0,
        gcashSales: 0,
        mayaSales: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        salmonReceivable: 0,
        openingFloat: 2000,
        expectedCash: 2700,
        countedCash: 2700,
        variance: 0,
        salesCount: 1,
        voidedCount: 0,
        closedBy: user.id,
        closedByName: user.displayName,
        closedAt: today,
      );

  late _MockCloseDayUseCase useCase;

  setUpAll(() {
    registerFallbackValue(_FakeUserEntity());
  });

  setUp(() {
    useCase = _MockCloseDayUseCase();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      // A successful closeDay() invalidates several other providers
      // (history, today's live summary, …) — give them a harmless real
      // Firestore stand-in so that fan-out doesn't crash on the
      // uninitialized real FirebaseService.
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      dailyClosingForDateProvider(today).overrideWith((ref) async => null),
      dailyClosingDataProvider(today).overrideWith((ref) async => data),
      closeDayUseCaseProvider.overrideWithValue(useCase),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EndOfDayScreen()),
      ),
    );
    // Warm the user stream — in the app it is always alive via the auth
    // gate, but _requireUser() reads it lazily and a cold first read is
    // loading (would spuriously throw UnauthenticatedException here).
    await container.read(currentUserProvider.future);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a typed-but-not-Added plate amount is auto-committed into the closeDay lists',
      (tester) async {
    List<double>? capturedDp;
    when(() => useCase.execute(
          actor: any(named: 'actor'),
          date: any(named: 'date'),
          openingFloat: any(named: 'openingFloat'),
          countedCash: any(named: 'countedCash'),
          plateNoDpAmounts: any(named: 'plateNoDpAmounts'),
          plateNoDeliveryAmounts: any(named: 'plateNoDeliveryAmounts'),
          excludedExpenseIds: any(named: 'excludedExpenseIds'),
          notes: any(named: 'notes'),
        )).thenAnswer((invocation) async {
      capturedDp =
          invocation.namedArguments[#plateNoDpAmounts] as List<double>;
      return UseCaseResult.successData(savedClosing());
    });

    await pump(tester);

    // Type into the Plate No DP amount field WITHOUT tapping its Add button —
    // the old muscle-memory bug: type-then-close.
    await tester.enterText(find.byType(TextFormField).at(0), '250');
    // Counted cash is required for the form to validate.
    await tester.enterText(find.byType(TextFormField).at(3), '2700');
    await tester.pump();

    await tester.tap(find.text('Close Day'));
    await tester.pumpAndSettle();

    // The typed amount was auto-committed before the confirm dialog opened —
    // it already shows as a row in the (still-open) form underneath.
    expect(find.text('Entry 1'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(AppDialog), matching: find.text('Close Day')));
    await tester.pumpAndSettle();

    expect(capturedDp, [250]);
  });

  testWidgets(
      'invalid typed plate amount blocks Close Day with a snackbar and never opens the confirm dialog',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'abc');
    await tester.enterText(find.byType(TextFormField).at(3), '2700');
    await tester.pump();

    await tester.tap(find.text('Close Day'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(
      find.textContaining('Tap Add to include the typed Plate No amount'),
      findsOneWidget,
    );
    verifyNever(() => useCase.execute(
          actor: any(named: 'actor'),
          date: any(named: 'date'),
          openingFloat: any(named: 'openingFloat'),
          countedCash: any(named: 'countedCash'),
          plateNoDpAmounts: any(named: 'plateNoDpAmounts'),
          plateNoDeliveryAmounts: any(named: 'plateNoDeliveryAmounts'),
          excludedExpenseIds: any(named: 'excludedExpenseIds'),
          notes: any(named: 'notes'),
        ));
  });
}
