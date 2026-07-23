import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

void main() {
  testWidgets('trailing widget renders in the header row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClosingSectionCard(
            icon: LucideIcons.arrowDownCircle,
            title: 'Expenses',
            trailing: OutlinedButton(
              onPressed: () {},
              child: const Text('Add Expense'),
            ),
            children: const [Text('body')],
          ),
        ),
      ),
    );

    expect(find.text('Add Expense'), findsOneWidget);
    // The trailing sits in the same Row as the title (OutlinedButton has no
    // internal Row, so the nearest Row ancestor is the header).
    final headerRow = find
        .ancestor(of: find.text('Add Expense'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: headerRow, matching: find.text('Expenses')),
      findsOneWidget,
    );
  });

  testWidgets('omitting trailing keeps the plain header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClosingSectionCard(
            icon: LucideIcons.receipt,
            title: 'Sales',
            children: [Text('body')],
          ),
        ),
      ),
    );
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}
