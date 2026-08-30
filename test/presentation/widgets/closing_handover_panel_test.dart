import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_handover_panel.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('leads with counted cash and names both destinations',
      (tester) async {
    await tester.pumpWidget(_host(const ClosingHandoverPanel(
      countedCash: 5241,
      laborFees: 1000,
      forManagement: 4241,
    )));

    expect(find.text('CASH HAND-OVER'), findsOneWidget);
    // The counted total is the anchor: the two parts must visibly add up to it.
    expect(find.text('Counted'), findsOneWidget);
    expect(find.text('₱5,241.00'), findsOneWidget);
    expect(find.text('To mechanics'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsOneWidget);
    expect(find.text('To management'), findsOneWidget);
    expect(find.text('₱4,241.00'), findsOneWidget);
  });

  testWidgets('lists each mechanic when shares are supplied', (tester) async {
    await tester.pumpWidget(_host(const ClosingHandoverPanel(
      countedCash: 5241,
      laborFees: 1000,
      forManagement: 4241,
      shares: [
        HandoverShare(name: 'Jeric', amount: 200),
        HandoverShare(name: 'Rey', amount: 800),
      ],
    )));

    expect(find.text('Jeric'), findsOneWidget);
    expect(find.text('₱200.00'), findsOneWidget);
    expect(find.text('Rey'), findsOneWidget);
    expect(find.text('₱800.00'), findsOneWidget);
    // They agree with the frozen total, so no caveat.
    expect(find.textContaining('what was frozen'), findsNothing);
  });

  testWidgets('omits the breakdown entirely when no shares are given',
      (tester) async {
    await tester.pumpWidget(_host(const ClosingHandoverPanel(
      countedCash: 5241,
      laborFees: 1000,
      forManagement: 4241,
    )));

    expect(find.textContaining('what was frozen'), findsNothing);
    expect(find.text('To mechanics'), findsOneWidget);
  });

  testWidgets('says so when the named shares disagree with the snapshot',
      (tester) async {
    // A sale voided after close moves live labor without touching the frozen
    // closing — exactly what happened on 2026-08-28. Showing both numbers
    // without explanation would read as an arithmetic error.
    await tester.pumpWidget(_host(const ClosingHandoverPanel(
      countedCash: 5241,
      laborFees: 800,
      forManagement: 4441,
      shares: [
        HandoverShare(name: 'Jeric', amount: 200),
        HandoverShare(name: 'Rey', amount: 800),
      ],
    )));

    expect(find.textContaining('Named shares total ₱1,000.00'), findsOneWidget);
    expect(find.textContaining('frozen'), findsOneWidget);
  });

  testWidgets('a rounding-level difference is not treated as a mismatch',
      (tester) async {
    await tester.pumpWidget(_host(const ClosingHandoverPanel(
      countedCash: 5241,
      laborFees: 1000,
      forManagement: 4241,
      shares: [HandoverShare(name: 'Jeric', amount: 1000.004)],
    )));

    expect(find.textContaining('frozen'), findsNothing);
  });

  group('after a day is closed early and trading continues', () {
    // The shop closes the drawer, then last-minute customers arrive. That is
    // routine here, so the panel must lead with what to hand over NOW, not
    // what was true when the drawer was sealed.
    PostCloseActivity activity({
      double cashDelta = 2950,
      double snapshotLabor = 400,
      double currentLabor = 550,
      double counted = 2140,
    }) =>
        PostCloseActivity(
          extraSales: 3,
          grossDelta: 2800,
          cashSalesDelta: cashDelta,
          cashExpensesDelta: 0,
          updatedCashOnHand: counted + cashDelta,
          laborDelta: currentLabor - snapshotLabor,
          currentLaborRevenue: currentLabor,
        );

    testWidgets('hands over the whole-day labor, not the sealed figure',
        (tester) async {
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2140,
        laborFees: 400,
        forManagement: 1740,
        activity: activity(),
      )));

      // 550 owed, leaving 4,540 — the two add up to the footer, not to the
      // sealed count still shown at the top.
      expect(find.text('₱550.00'), findsOneWidget);
      expect(find.text('₱4,540.00'), findsOneWidget);
      expect(find.text('Updated cash on hand'), findsOneWidget);
      expect(find.text('₱5,090.00'), findsOneWidget);
      // The sealed split must not read as the instruction.
      expect(find.text('₱1,740.00'), findsNothing);
    });

    testWidgets('keeps the sealed count visible as the anchor', (tester) async {
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2140,
        laborFees: 400,
        forManagement: 1740,
        activity: activity(),
      )));

      expect(find.text('Counted'), findsOneWidget);
      expect(find.text('₱2,140.00'), findsOneWidget);
    });

    testWidgets('per-mechanic shares reconcile against the updated total',
        (tester) async {
      // Shares are read from live sales, so once the panel also shows the
      // live total the mismatch note has nothing left to report.
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2140,
        laborFees: 400,
        forManagement: 1740,
        activity: activity(),
        shares: const [
          HandoverShare(name: 'Jun', amount: 400),
          HandoverShare(name: 'Rico', amount: 150),
        ],
      )));

      expect(find.text('Jun'), findsOneWidget);
      expect(find.text('Rico'), findsOneWidget);
      expect(find.textContaining('Named shares total'), findsNothing);
    });

    testWidgets('an unchanged day still shows the sealed figures',
        (tester) async {
      await tester.pumpWidget(_host(ClosingHandoverPanel(
        countedCash: 2140,
        laborFees: 400,
        forManagement: 1740,
        activity: const PostCloseActivity(
          extraSales: 0,
          grossDelta: 0,
          cashSalesDelta: 0,
          cashExpensesDelta: 0,
          updatedCashOnHand: 2140,
          laborDelta: 0,
          currentLaborRevenue: 400,
        ),
      )));

      expect(find.text('₱2,140.00'), findsOneWidget);
      expect(find.text('₱400.00'), findsOneWidget);
      expect(find.text('₱1,740.00'), findsOneWidget);
      // No sales after close, so nothing to update — no footer.
      expect(find.text('Updated cash on hand'), findsNothing);
    });
  });
}
