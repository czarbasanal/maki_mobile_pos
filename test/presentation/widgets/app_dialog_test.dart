import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

Future<void> _pumpWith(
    WidgetTester tester, void Function(BuildContext) onTap) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onTap(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('confirm returns true on primary, false on cancel', (tester) async {
    bool? result;
    await _pumpWith(tester, (context) {
      showAppConfirmDialog(context,
              title: 'Replace cart?',
              message: 'Loading replaces 3 items.',
              confirmLabel: 'Replace')
          .then((v) => result = v);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Replace cart?'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(result, true);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets('destructive shows a warning line + alert-triangle', (tester) async {
    await _pumpWith(tester, (context) {
      showAppConfirmDialog(context,
          title: 'Delete category?',
          message: 'Spark Plugs will be removed.',
          confirmLabel: 'Delete',
          destructive: true);
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('error dialog shows message + OK and dismisses', (tester) async {
    await _pumpWith(tester, (context) {
      showAppErrorDialog(context, message: 'A stock doc changed elsewhere.');
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
    expect(find.text('A stock doc changed elsewhere.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });
}
