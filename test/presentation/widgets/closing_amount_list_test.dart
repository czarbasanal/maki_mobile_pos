import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<double> amounts,
    required ValueChanged<List<double>> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClosingAmountList(
              label: 'Plate No DP',
              amounts: amounts,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('adding an amount reports the appended list', (tester) async {
    List<double>? changed;
    await pump(tester, amounts: const [100], onChanged: (v) => changed = v);

    await tester.enterText(find.byType(TextFormField), '250');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();

    expect(changed, [100, 250]);
  });

  testWidgets('invalid or zero input is ignored', (tester) async {
    List<double>? changed;
    await pump(tester, amounts: const [], onChanged: (v) => changed = v);

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();
    expect(changed, isNull);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();
    expect(changed, isNull);
  });

  testWidgets('rows are removable and the sum line totals the entries',
      (tester) async {
    List<double>? changed;
    await pump(tester,
        amounts: const [100, 250], onChanged: (v) => changed = v);

    expect(find.text('Entry 1'), findsOneWidget);
    expect(find.text('Entry 2'), findsOneWidget);
    // Live sum line: label carries the entry count, value the total.
    expect(find.textContaining('2 entries'), findsOneWidget);
    expect(find.text('₱350.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove amount').first);
    await tester.pump();
    expect(changed, [250]);
  });
}
