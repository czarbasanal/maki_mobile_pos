import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/password_dialog.dart';

void main() {
  group('PasswordDialog', () {
    testWidgets('displays title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PasswordDialog.show(
                    context: context,
                    title: 'Test Title',
                    subtitle: 'Test Subtitle',
                    onVerify: (_) async => true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
    });

    testWidgets('shows error on empty password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PasswordDialog.show(
                    context: context,
                    title: 'Test',
                    onVerify: (_) async => true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('can toggle password visibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PasswordDialog.show(
                    context: context,
                    title: 'Test',
                    onVerify: (_) async => true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Initially password is obscured.
      expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);

      // Tap to show password.
      await tester.tap(find.byIcon(CupertinoIcons.eye));
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.eye_slash), findsOneWidget);
    });
  });
}
