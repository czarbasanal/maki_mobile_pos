import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

void main() {
  testWidgets('a huge item list opens as a scrollable, height-capped menu',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppDropdown<int>(
              decoration: const InputDecoration(labelText: 'Model'),
              items: [
                for (var i = 0; i < 500; i++)
                  DropdownMenuItem(value: i, child: Text('Model $i')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppDropdown<int>));
    await tester.pumpAndSettle();

    // No overflow: opening must not throw, and the far end of the list is
    // reachable by scrolling inside the menu.
    expect(tester.takeException(), isNull);
    expect(find.text('Model 0'), findsOneWidget);

    // Height-capped so the menu is an obviously scrollable panel rather
    // than a screen-filling sheet.
    final viewport = tester.getSize(
      find
          .descendant(
            of: find.byType(MenuAnchor),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(viewport.height, lessThanOrEqualTo(320));
    await tester.scrollUntilVisible(
      find.text('Model 499'),
      600,
      scrollable: find.descendant(
        of: find.byType(MenuAnchor),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 200,
    );
    expect(find.text('Model 499'), findsOneWidget);
  });

  testWidgets('opening a dropdown dismisses the active keyboard',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focusNode),
              AppDropdown<int>(
                decoration: const InputDecoration(labelText: 'Model'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Nmax')),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byType(AppDropdown<int>));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });
}
