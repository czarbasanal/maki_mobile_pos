import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_handover_panel.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

PostCloseActivity drift({double cashDelta = 3010}) => PostCloseActivity(
      extraSales: 3,
      grossDelta: 2800,
      cashSalesDelta: cashDelta,
      cashExpensesDelta: 0,
      updatedCashOnHand: 2260 + cashDelta,
      laborDelta: 150,
      currentLaborRevenue: 550,
      feesDelta: 60,
      currentFeesRevenue: 180,
    );

void main() {
  group('the panel states what it divides in a caption', () {
    testWidgets('no longer repeats counted cash as a row', (tester) async {
      // The reconciliation zone directly above already ends in Counted cash.
      // Repeating it as the panel's first row stated one figure twice.
      await tester.pumpWidget(_host(const ClosingHandoverPanel(
        countedCash: 5491,
        laborFees: 800,
        forManagement: 4691,
      )));

      expect(find.text('Counted'), findsNothing);
      expect(find.textContaining('Dividing ₱5,491.00'), findsOneWidget);
      // The figure itself appears once, in the caption.
      expect(find.text('₱5,491.00'), findsNothing);
    });

    testWidgets('says it is superseding the sealed count once a day drifted',
        (tester) async {
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2260,
        laborFees: 400,
        forManagement: 1860,
        activity: drift(),
      )));

      expect(find.textContaining('Superseding the sealed count of ₱2,260.00'),
          findsOneWidget);
      expect(find.textContaining('see After close'), findsOneWidget);
    });

    testWidgets('the two destinations add up to the footer, not the caption',
        (tester) async {
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2260,
        laborFees: 400,
        forManagement: 1860,
        activity: drift(),
      )));

      // 550 owed + 4,720 to management = 5,270 updated cash on hand.
      expect(find.text('₱550.00'), findsOneWidget);
      expect(find.text('₱4,720.00'), findsOneWidget);
      expect(find.text('Updated cash on hand'), findsOneWidget);
      expect(find.text('₱5,270.00'), findsOneWidget);
    });
  });
}
