import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

void main() {
  testWidgets('shows labor→mechanics and items→management rows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ClosingHandoffRows(laborFees: 450, forManagement: 2050),
      ),
    ));
    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱2,050.00'), findsOneWidget);
  });
}
