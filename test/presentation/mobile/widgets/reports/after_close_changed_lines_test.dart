import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/after_close_card.dart';

Widget _host(PostCloseActivity activity) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AfterCloseCard(activity: activity)),
      ),
    );

PostCloseActivity activity({
  double grossDelta = 2800,
  double laborDelta = 150,
  double feesDelta = 60,
  double cashExpensesDelta = 0,
  int extraSales = 3,
}) =>
    PostCloseActivity(
      extraSales: extraSales,
      grossDelta: grossDelta,
      cashSalesDelta: 3010,
      cashExpensesDelta: cashExpensesDelta,
      updatedCashOnHand: 5270,
      laborDelta: laborDelta,
      currentLaborRevenue: 400 + laborDelta,
      feesDelta: feesDelta,
      currentFeesRevenue: 120 + feesDelta,
      closingGrossSales: 1740,
      closingLaborRevenue: 400,
      closingFeesRevenue: 120,
    );

void main() {
  group('After close lists only the frozen lines that moved', () {
    testWidgets('a line that did not change is left out entirely',
        (tester) async {
      // Expenses did not move here. The sealed summary above still shows every
      // line including zeros; this card is the one place they are conditional.
      await tester.pumpWidget(_host(activity()));

      expect(find.textContaining('Sales after closing'), findsOneWidget);
      expect(find.textContaining('Labor fees after closing'), findsOneWidget);
      expect(find.textContaining('Shop fees after closing'), findsOneWidget);
      expect(find.textContaining('Expenses after closing'), findsNothing);
    });

    testWidgets('names the unchanged lines rather than staying silent',
        (tester) async {
      await tester.pumpWidget(_host(activity()));

      expect(
        find.textContaining('Only the frozen lines that moved after closing'),
        findsOneWidget,
      );
      expect(find.textContaining('Expenses did not change'), findsOneWidget);
    });

    testWidgets('the note is generated, not hardcoded', (tester) async {
      // Labor and expenses both held; only sales and fees moved.
      await tester.pumpWidget(_host(activity(laborDelta: 0)));

      // No labor ROWS — but the note may (and should) name it.
      expect(find.text('Labor fees at closing'), findsNothing);
      expect(find.text('Labor fees after closing'), findsNothing);
      expect(find.text('Updated labor fees'), findsNothing);
      final note = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('did not change'));
      expect(note, contains('Labor fees'));
      expect(note, contains('Expenses'));
    });

    testWidgets('shows at closing, after closing, and updated for a moved line',
        (tester) async {
      await tester.pumpWidget(_host(activity()));

      expect(find.text('Labor fees at closing'), findsOneWidget);
      expect(find.text('₱400.00'), findsOneWidget);
      expect(find.text('Labor fees after closing'), findsOneWidget);
      expect(find.text('+₱150.00'), findsOneWidget);
      expect(find.text('Updated labor fees'), findsOneWidget);
      expect(find.text('₱550.00'), findsOneWidget);
    });

    testWidgets('keeps the count prefix on the sales movement', (tester) async {
      await tester.pumpWidget(_host(activity()));
      expect(find.text('+3 · +₱2,800.00'), findsOneWidget);
    });
  });
}
