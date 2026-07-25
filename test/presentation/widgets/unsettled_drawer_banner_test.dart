import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/unsettled_drawer_banner.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required DateTime? unsettled,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unsettledBusinessDayProvider.overrideWith((ref) async => unsettled),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UnsettledDrawerBanner()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing while there is nothing unsettled',
      (tester) async {
    await pump(tester, unsettled: null);
    expect(find.byType(UnsettledDrawerBanner), findsOneWidget);
    expect(find.text('Close Day'), findsNothing);
  });

  testWidgets('shows the dated warning + Close Day button when unsettled',
      (tester) async {
    final target = DateTime(2026, 7, 20);
    await pump(tester, unsettled: target);

    expect(
      find.text(
        "The drawer for ${DateFormat('MMM d').format(target)} hasn't "
        'been closed. Close it before new sales.',
      ),
      findsOneWidget,
    );
    expect(find.text('Close Day'), findsOneWidget);
  });

  testWidgets('Close Day routes to the End of Day screen for that date',
      (tester) async {
    final target = DateTime(2026, 7, 20);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: UnsettledDrawerBanner()),
        ),
        GoRoute(
          path: RoutePaths.endOfDay,
          name: RouteNames.endOfDay,
          builder: (context, state) =>
              EndOfDayScreen(targetDate: state.extra as DateTime?),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unsettledBusinessDayProvider.overrideWith((ref) async => target),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Close Day'));
    await tester.pumpAndSettle();

    // Real EOD screen renders its dated title, proving it received the date.
    expect(
      find.text('Closing ${DateFormat('MMM d').format(target)}'),
      findsOneWidget,
    );
  });
}
