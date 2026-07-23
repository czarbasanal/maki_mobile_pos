import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';

void main() {
  testWidgets('drops focus when the software keyboard collapses',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductSearchField(
              controller: controller,
              focusNode: focusNode,
              onProductSelected: (_) {},
              onBarcodeScanned: (_) {},
            ),
          ),
        ),
      ),
    );

    // Focus the field, then simulate the keyboard opening…
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // …then closing (system back / swipe-down). Focus must drop so the
    // cursor and any results overlay dismiss with the keyboard.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);

    // Unfocusing fires the field's own focus listener, which schedules a
    // 200ms delayed overlay-removal check — flush it so no timer is left
    // pending when the widget tree is torn down.
    await tester.pump(const Duration(milliseconds: 250));
  });
}
