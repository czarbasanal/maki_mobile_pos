import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
