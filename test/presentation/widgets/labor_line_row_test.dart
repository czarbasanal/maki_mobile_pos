import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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
          body: LaborLineRow(
            line: line,
            onEdited: onEdited ?? (_, __) {},
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  group('LaborLineRow', () {
    testWidgets('renders description and fee; Job Order style (no swipe, no pencil)',
        (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Engine tune-up'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget);
      // Job Order style: whole card is the tap target, trailing ✕ removes.
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(LucideIcons.pencil), findsNothing);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('tapping the card opens the edit dialog and reports edits',
        (tester) async {
      String? newDesc;
      double? newFee;
      await tester.pumpWidget(host(onEdited: (d, f) {
        newDesc = d;
        newFee = f;
      }));

      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();

      expect(find.text('Edit Labor'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Brake bleed');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '300');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(newDesc, 'Brake bleed');
      expect(newFee, 300.0);
    });

    testWidgets('the trailing x calls onRemove without opening the dialog',
        (tester) async {
      var removed = false;
      await tester.pumpWidget(host(onRemove: () => removed = true));

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(removed, true);
      expect(find.text('Edit Labor'), findsNothing);
    });
  });

  group('showLaborLineDialog', () {
    Widget dialogHost(void Function(LaborLineInput?) onResult) {
      return ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      onResult(await showLaborLineDialog(ctx)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('add mode titles Add Labor and validates both fields',
        (tester) async {
      LaborLineInput? result;
      await tester.pumpWidget(dialogHost((r) => result = r));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add Labor'), findsOneWidget);

      // Empty description + empty fee → blocked, dialog stays open.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Fee must be greater than 0'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Tune-up');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '450');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.description, 'Tune-up');
      expect(result!.fee, 450.0);
    });

    testWidgets('zero fee is rejected', (tester) async {
      LaborLineInput? result;
      await tester.pumpWidget(dialogHost((r) => result = r));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Tune-up');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '0');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Fee must be greater than 0'), findsOneWidget);
      expect(result, isNull);
    });
  });
}
