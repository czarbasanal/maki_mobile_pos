import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_tile.dart';

void main() {
  const line = LaborLineEntity(
    id: 'l1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  Widget host({
    void Function(String, double)? onEdited,
    VoidCallback? onRemove,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: LaborLineTile(
            line: line,
            onEdited: onEdited ?? (_, __) {},
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  group('LaborLineTile', () {
    testWidgets('renders description and fee, no discount affordance',
        (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Engine tune-up'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget);
      // Labor never carries a discount control.
      expect(find.byIcon(CupertinoIcons.tag), findsNothing);
    });

    testWidgets('calls onRemove when dismissed', (tester) async {
      var removed = false;
      await tester.pumpWidget(host(onRemove: () => removed = true));

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(removed, true);
    });

    testWidgets('edit dialog reports new description and fee', (tester) async {
      String? newDesc;
      double? newFee;
      await tester.pumpWidget(host(onEdited: (d, f) {
        newDesc = d;
        newFee = f;
      }));

      await tester.tap(find.byIcon(CupertinoIcons.pencil));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Brake bleed');
      await tester.enterText(
          find.byKey(const Key('labor-fee-field')), '300');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(newDesc, 'Brake bleed');
      expect(newFee, 300.0);
    });
  });
}
