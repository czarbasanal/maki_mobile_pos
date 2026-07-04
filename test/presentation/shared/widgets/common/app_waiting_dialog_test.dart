import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

void main() {
  // Pumps a host with a button that runs [action] behind the waiting dialog.
  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<void> Function(BuildContext) onTap,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
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

  Dialog dialogOf(WidgetTester tester) =>
      tester.widget<Dialog>(find.byType(Dialog));

  testWidgets('shows the message while pending and removes it after',
      (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump(); // show dialog
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets); // the progress ring

    await tester.pump(const Duration(milliseconds: 450)); // action completes
    await tester.pumpAndSettle();
    expect(find.text('Saving…'), findsNothing);
  });

  testWidgets('stays up ~300ms minimum so fast calls do not flash it',
      (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(() async {}, message: 'Saving…');
    });

    await tester.tap(find.text('go'));
    await tester.pump(); // show dialog; action already complete
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Saving…'), findsOneWidget); // still inside min display

    await tester.pump(const Duration(milliseconds: 150)); // past 300ms
    await tester.pumpAndSettle();
    expect(find.text('Saving…'), findsNothing);
  });

  testWidgets('renders no subtitle by default', (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    final column = tester.widget<Column>(find.descendant(
      of: find.byType(AppWaitingDialog),
      matching: find.byType(Column),
    ));
    expect(column.children.length, 3); // ring, gap, title — no subtitle
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  });

  testWidgets('renders the subtitle when provided', (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Billing out…',
        subtitle: 'Loading this job order into the register.',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Billing out…'), findsOneWidget);
    expect(find.text('Loading this job order into the register.'),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  });

  testWidgets('light theme: white card, no border, ink title',
      (tester) async {
    await pumpHost(tester, theme: AppTheme.lightTheme, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    final dialog = dialogOf(tester);
    expect(dialog.backgroundColor, AppColors.lightCard);
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(24));
    expect(shape.side, BorderSide.none);
    final title = tester.widget<Text>(find.text('Saving…'));
    expect(title.style?.color, AppColors.lightText);
    expect(title.style?.fontSize, 17);
    expect(title.style?.fontWeight, FontWeight.w600);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  });

  testWidgets('dark theme: dark card with hairline border', (tester) async {
    await pumpHost(tester, theme: AppTheme.darkTheme, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    final dialog = dialogOf(tester);
    expect(dialog.backgroundColor, AppColors.darkCard);
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.darkHairline);
    final title = tester.widget<Text>(find.text('Saving…'));
    expect(title.style?.color, AppColors.darkText);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
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

  testWidgets('back button does not dismiss the dialog', (tester) async {
    await pumpHost(tester, onTap: (context) {
      return context.runWithWaiting(
        () => Future.delayed(const Duration(milliseconds: 400)),
        message: 'Saving…',
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  });
}
