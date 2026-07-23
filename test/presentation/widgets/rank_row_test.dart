import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/rank_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders rank, name, subtitle, qty, revenue and share bar',
      (tester) async {
    await tester.pumpWidget(host(const RankRow(
      index: 0,
      name: 'Brake Pad',
      subtitle: 'SKU-001',
      quantitySold: 8,
      revenue: 500,
      maxQuantity: 10,
    )));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('SKU-001'), findsOneWidget);
    expect(find.text('8 sold'), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);

    final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, 0.8);
  });

  testWidgets('profit pill renders only when profit is provided',
      (tester) async {
    await tester.pumpWidget(host(const RankRow(
      index: 1,
      name: 'Chain',
      subtitle: 'SKU-002',
      quantitySold: 5,
      revenue: 500,
      maxQuantity: 10,
      profit: 250,
    )));
    expect(find.text('+₱250'), findsOneWidget);

    await tester.pumpWidget(host(const RankRow(
      index: 1,
      name: 'Chain',
      subtitle: 'SKU-002',
      quantitySold: 5,
      revenue: 500,
      maxQuantity: 10,
    )));
    expect(find.textContaining('+₱'), findsNothing);
  });

  testWidgets('onTap fires when the row is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(RankRow(
      index: 3,
      name: 'Bulb',
      subtitle: 'SKU-003',
      quantitySold: 1,
      revenue: 50,
      maxQuantity: 10,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.text('Bulb'));
    expect(tapped, true);
  });
}
