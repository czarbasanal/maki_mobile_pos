import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/sales/pending_void_banner.dart';

void main() {
  testWidgets('static (no onTap): renders label, no chevron', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PendingVoidBanner()),
    ));
    expect(find.text('Void pending approval'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
  });

  testWidgets('tappable: shows chevron and fires onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PendingVoidBanner(onTap: () => tapped++)),
    ));
    expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
    await tester.tap(find.text('Void pending approval'));
    expect(tapped, 1);
  });
}
