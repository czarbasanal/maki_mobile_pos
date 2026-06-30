import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

void main() {
  // Pumps a host with a button that runs [action] behind the waiting dialog.
  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<void> Function(BuildContext) onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onTap(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('shows the message while pending and removes it after', (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 200)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump(); // show dialog
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250)); // action completes
    await tester.pumpAndSettle();
    expect(find.text('Saving…'), findsNothing);
  });

  testWidgets('propagates the returned value', (tester) async {
    int? captured;
    await pumpHost(tester, onTap: (context) async {
      captured = await context.runWithWaiting<int>(
        () async => 42,
        message: 'Loading…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(captured, 42);
  });

  testWidgets('closes the dialog and rethrows on error', (tester) async {
    Object? caught;
    await pumpHost(tester, onTap: (context) async {
      try {
        await context.runWithWaiting<void>(
          () async => throw StateError('boom'),
          message: 'Deleting…',
        );
      } catch (e) {
        caught = e;
      }
    });

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(caught, isA<StateError>());
    expect(find.text('Deleting…'), findsNothing);
  });
}
