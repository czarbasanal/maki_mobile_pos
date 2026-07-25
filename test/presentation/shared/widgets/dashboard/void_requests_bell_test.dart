import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/void_requests_bell.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int unread,
    List<VoidRequestEntity> requests = const [],
  }) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        unreadVoidRequestCountProvider.overrideWith((ref) => unread),
        voidRequestsProvider.overrideWith((ref) => Stream.value(requests)),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [VoidRequestsBell()]),
        ),
      ),
    ));
  }

  testWidgets('shows the bell without a badge when nothing is unread',
      (tester) async {
    await pump(tester, unread: 0);
    expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('tapping the bell opens the void-request notification sheet',
      (tester) async {
    await pump(tester, unread: 3);
    await tester.tap(find.byIcon(LucideIcons.bell));
    await tester.pumpAndSettle();
    expect(find.text('Void requests'), findsOneWidget);
    expect(find.text('No void requests'), findsOneWidget);
  });

  testWidgets(
      'tapping the unread BADGE also opens the sheet (#11)', (tester) async {
    await pump(tester, unread: 3);
    // Tap directly on the badge text — before the #11 fix the badge
    // swallowed the tap and the bell never fired.
    await tester.tap(find.text('3'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Void requests'), findsOneWidget);
  });
}
