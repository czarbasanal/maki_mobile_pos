import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/void_requests_bell.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int unread,
    required VoidCallback onPressed,
  }) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        unreadVoidRequestCountProvider.overrideWith((ref) => unread),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [VoidRequestsBell(onPressed: onPressed)]),
        ),
      ),
    ));
  }

  testWidgets('shows the bell without a badge when nothing is unread',
      (tester) async {
    await pump(tester, unread: 0, onPressed: () {});
    expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('tapping the bell fires onPressed', (tester) async {
    var pressed = 0;
    await pump(tester, unread: 3, onPressed: () => pressed++);
    await tester.tap(find.byIcon(LucideIcons.bell));
    expect(pressed, 1);
  });

  testWidgets('tapping the unread BADGE also fires onPressed (#11)',
      (tester) async {
    var pressed = 0;
    await pump(tester, unread: 3, onPressed: () => pressed++);
    // Tap directly on the badge text — before the fix the badge swallowed
    // the tap and the bell never fired.
    await tester.tap(find.text('3'), warnIfMissed: false);
    expect(pressed, 1);
  });
}
