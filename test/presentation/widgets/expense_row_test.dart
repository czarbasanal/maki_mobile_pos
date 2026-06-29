import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/expense_row.dart';

void main() {
  testWidgets('renders description, subtitle, grouped amount, neutral glyph; taps',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExpenseRow(
          description: 'Shop electricity',
          subtitle: 'Jun 27, 2026 • Utilities',
          amount: 1234,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
    expect(find.text('Shop electricity'), findsOneWidget);
    expect(find.text('Jun 27, 2026 • Utilities'), findsOneWidget);
    expect(find.text('₱1,234.00'), findsOneWidget);

    await tester.tap(find.text('Shop electricity'));
    expect(tapped, true);
  });
}
