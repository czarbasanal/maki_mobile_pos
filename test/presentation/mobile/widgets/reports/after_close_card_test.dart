import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

Widget _harness(PostCloseActivity activity) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AfterCloseCard(activity: activity)),
      ),
    );

void main() {
  testWidgets('splits after-close cash into sale items vs labor and shows '
      'handoff totals', (tester) async {
    // One cash sale after close: parts ₱200 + labor ₱300 (cash +500).
    // Whole-day labor is 750. All expected strings below are unique in the
    // card — the 'Sales after close' row renders a combined '+1 · +₱200.00'
    // string, so '+₱200.00' matches only the Sale items sub-line.
    const activity = PostCloseActivity(
      extraSales: 1,
      grossDelta: 200,
      cashSalesDelta: 500,
      cashExpensesDelta: 0,
      updatedCashOnHand: 1950,
      laborDelta: 300,
      currentLaborRevenue: 750,
    );
    await tester.pumpWidget(_harness(activity));

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Cash collected after close'), findsOneWidget);
    expect(find.text('+₱500.00'), findsOneWidget);
    expect(find.text('Sale items'), findsOneWidget);
    expect(find.text('+₱200.00'), findsOneWidget); // 500 cash − 300 labor
    expect(find.text('Labor fees'), findsOneWidget);
    expect(find.text('+₱300.00'), findsOneWidget);
    expect(find.text('Updated cash on hand'), findsOneWidget);
    expect(find.text('₱1,950.00'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('₱1,200.00'), findsOneWidget); // 1950 − 750
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });

  testWidgets('hides the split sub-lines when no labor drifted',
      (tester) async {
    const activity = PostCloseActivity(
      extraSales: 1,
      grossDelta: 240,
      cashSalesDelta: 240,
      cashExpensesDelta: 0,
      updatedCashOnHand: 2740,
      laborDelta: 0,
      currentLaborRevenue: 450,
    );
    await tester.pumpWidget(_harness(activity));

    expect(find.text('Sale items'), findsNothing);
    expect(find.text('Labor fees'), findsNothing);
    // Bottom handoff rows still shown.
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('₱2,290.00'), findsOneWidget); // 2740 − 450
  });
}
