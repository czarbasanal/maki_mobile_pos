import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_zone.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('a zone ends with the one line it resolves to', (tester) async {
    // The whole point of the pattern: scanning vertically gives you the four
    // result numbers before you read any detail.
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.arrowDownLeft,
      heading: 'SALES',
      rows: [
        ZoneRow(label: 'Gross sales (parts)', value: 7960),
        ZoneRow(label: 'Labor (service)', value: 800),
      ],
      result: ZoneRow(label: 'Cash sales', value: 8335, sign: ZoneSign.plus),
    )));

    expect(find.text('SALES'), findsOneWidget);
    expect(find.text('Gross sales (parts)'), findsOneWidget);
    expect(find.text('Cash sales'), findsOneWidget);
    expect(find.text('+₱8,335.00'), findsOneWidget);
  });

  testWidgets('only cash-on-hand terms carry a sign', (tester) async {
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.scale,
      heading: 'CASH RECONCILIATION',
      rows: [
        ZoneRow(label: 'Opening float', value: 500, sign: ZoneSign.plus),
        ZoneRow(label: 'Plate No Delivery', value: 250, sign: ZoneSign.minus),
        ZoneRow(label: 'Expected cash', value: 5491),
      ],
      result: ZoneRow(label: 'Counted cash', value: 5491),
    )));

    expect(find.text('+₱500.00'), findsOneWidget);
    // U+2212, not a hyphen.
    expect(find.text('−₱250.00'), findsOneWidget);
    // Reference figures and results are unsigned.
    expect(find.text('₱5,491.00'), findsNWidgets(2));
  });

  testWidgets('indented rows render under the row they break down',
      (tester) async {
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.arrowDownLeft,
      heading: 'SALES',
      rows: [
        ZoneRow(label: 'Non-cash sales', value: 685),
        ZoneRow(label: 'GCash', value: 400, indented: true),
        ZoneRow(label: 'Maya', value: 285, indented: true),
      ],
      result: ZoneRow(label: 'Cash sales', value: 8335, sign: ZoneSign.plus),
    )));

    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
  });

  testWidgets('a zone with no reference rows still shows its result',
      (tester) async {
    // SHOP FEES on a closing sealed before the breakdown existed: the total
    // survives, the per-type rows never will.
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.receipt,
      heading: 'SHOP FEES',
      rows: [],
      result: ZoneRow(label: 'Shop fees', value: 0),
    )));

    expect(find.text('SHOP FEES'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
  });

  testWidgets('a trailing widget rides on the result line', (tester) async {
    // Used by CASH RECONCILIATION to sit the variance chip beside the value.
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.scale,
      heading: 'CASH RECONCILIATION',
      rows: [],
      result: ZoneRow(label: 'Counted cash', value: 5491),
      resultLeading: Text('Balanced'),
    )));

    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('₱5,491.00'), findsOneWidget);
  });

  testWidgets('amounts share a right edge, whatever the label length',
      (tester) async {
    // A column of figures is only scannable if it lines up. Labels vary a lot
    // in length here — "GCash" against "Gross sales (parts)".
    await tester.pumpWidget(_host(const SizedBox(
      width: 340,
      child: ClosingZone(
        icon: LucideIcons.arrowDownLeft,
        heading: 'SALES',
        rows: [
          ZoneRow(label: 'Gross sales (parts)', value: 7960),
          ZoneRow(label: 'GCash', value: 400, indented: true),
        ],
        result: ZoneRow(label: 'Cash sales', value: 8335, sign: ZoneSign.plus),
      ),
    )));

    final gross = tester.getRect(find.text('₱7,960.00')).right;
    final gcash = tester.getRect(find.text('₱400.00')).right;
    final result = tester.getRect(find.text('+₱8,335.00')).right;

    expect(gcash, moreOrLessEquals(gross, epsilon: 0.5));
    expect(result, moreOrLessEquals(gross, epsilon: 0.5));
  });

  testWidgets('the variance chip stays beside its amount, not adrift',
      (tester) async {
    await tester.pumpWidget(_host(const SizedBox(
      width: 340,
      child: ClosingZone(
        icon: LucideIcons.scale,
        heading: 'CASH RECONCILIATION',
        rows: [ZoneRow(label: 'Expected cash', value: 5491)],
        result: ZoneRow(label: 'Counted cash', value: 5491),
        resultLeading: Text('Balanced'),
      ),
    )));

    final chip = tester.getRect(find.text('Balanced'));
    final amounts = tester.widgetList(find.text('₱5,491.00'));
    expect(amounts.length, 2);
    // The chip sits immediately left of the result amount, not spread away
    // from it by the row's spacing.
    final resultAmount = tester.getRect(find.text('₱5,491.00').last);
    expect(resultAmount.left - chip.right, lessThan(12));
  });

  testWidgets('a count is rendered verbatim, never as money', (tester) async {
    await tester.pumpWidget(_host(const ClosingZone(
      icon: LucideIcons.arrowDownLeft,
      heading: 'SALES',
      rows: [ZoneRow.text(label: 'Sales count', text: '21')],
      result: ZoneRow(label: 'Cash sales', value: 8335, sign: ZoneSign.plus),
    )));

    expect(find.text('21'), findsOneWidget);
    expect(find.text('₱21.00'), findsNothing);
  });
}
