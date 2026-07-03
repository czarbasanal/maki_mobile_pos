import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))));

  testWidgets('PoQtyBadge shows Nx and switches locked style', (tester) async {
    await pump(tester, const PoQtyBadge(quantity: 10, locked: false));
    expect(find.text('10x'), findsOneWidget);
    await pump(tester, const PoQtyBadge(quantity: 4, locked: true));
    expect(find.text('4x'), findsOneWidget);
  });

  testWidgets('PoStepperButton fires onTap only when enabled', (tester) async {
    var taps = 0;
    await pump(tester,
        PoStepperButton(icon: LucideIcons.plus, onTap: () => taps++));
    await tester.tap(find.byIcon(LucideIcons.plus));
    expect(taps, 1);
    await pump(tester, const PoStepperButton(icon: LucideIcons.minus));
    await tester.tap(find.byIcon(LucideIcons.minus));
    expect(taps, 1, reason: 'disabled button must not fire');
  });

  testWidgets('PoAmberNote renders the warning text with the alert glyph',
      (tester) async {
    await pump(tester, const PoAmberNote(text: 'Careful now'));
    expect(find.text('Careful now'), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
  });

  testWidgets('PoSectionHeader shows label and trailing', (tester) async {
    await pump(
        tester,
        const PoSectionHeader(
            icon: LucideIcons.trendingUp, label: 'Recommended', trailing: '3'));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
