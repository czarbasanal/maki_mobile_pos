import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_password_dialog.dart';

Future<void> _open(WidgetTester tester, void Function(BuildContext) tap) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
              onPressed: () => tap(context), child: const Text('open')),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('verifies and returns true', (tester) async {
    bool? result;
    await _open(tester, (c) {
      showAppPasswordDialog(c,
          title: 'Confirm void',
          onVerify: (pw) async => pw == 'good').then((v) => result = v);
    });

    expect(find.byIcon(LucideIcons.lock), findsWidgets);
    await tester.enterText(find.byType(TextField), 'good');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('locks out after maxAttempts', (tester) async {
    await _open(tester, (c) {
      showAppPasswordDialog(c,
          title: 'Verify identity',
          onVerify: (_) async => false,
          maxAttempts: 2);
    });

    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 attempts remaining'), findsOneWidget);

    // Second wrong attempt hits the lockout and auto-dismisses the dialog.
    await tester.enterText(find.byType(TextField), 'y');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Confirm'), findsNothing);
  });
}
