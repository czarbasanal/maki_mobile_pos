import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/selling_options_editor.dart';

// No provider is read anywhere in SellingOptionsEditor's tree (it takes
// unitCost/unit as plain constructor args, no Riverpod), so a bare
// MaterialApp harness — no ProviderScope — is sufficient here.

void main() {
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  Widget harness({
    required List<SellingOptionEntity> initial,
    required ValueChanged<List<SellingOptionEntity>> onChanged,
    double unitCost = 60,
    bool showMargin = true,
    String unit = 'pcs',
  }) {
    var current = initial;
    return MaterialApp(
      home: Scaffold(
        // The real host (the product form) already renders this widget
        // inside its own scrollable form — mirror that here so a 9- or
        // 10-row list doesn't overflow the fixed test viewport. Unrelated
        // to the widget's own layout, which is a plain Column meant to be
        // embedded in a scrollable parent rather than provide its own.
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => SellingOptionsEditor(
              value: current,
              onChanged: (next) {
                current = next;
                onChanged(next);
                setState(() {});
              },
              unitCost: unitCost,
              unit: unit,
              showMargin: showMargin,
            ),
          ),
        ),
      ),
    );
  }

  /// Simple pump for tests that only assert on rendered state, not on what
  /// gets passed to onChanged.
  Future<void> pump(WidgetTester tester, List<SellingOptionEntity> initial,
      {double unitCost = 60, bool showMargin = true}) async {
    await tester.pumpWidget(
      harness(
        initial: initial,
        onChanged: (_) {},
        unitCost: unitCost,
        showMargin: showMargin,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one row per option', (tester) async {
    await pump(tester, [by3]);
    expect(find.text('By 3'), findsOneWidget);
    expect(find.byKey(const Key('selling-option-row-0')), findsOneWidget);
  });

  testWidgets(
      'shows the derived per-piece price and the margin against unitCost — '
      'catches an impl that omits the caption or the margin half of it',
      (tester) async {
    // 330 / 3 = 110/pc, a quotient nothing else on screen coincides with.
    // Margin vs unitCost 60: (110 - 60) / 110 = 45% (not round, not 50,
    // so it can't pass by a lucky coincidence with some other number).
    await pump(tester, [by3]);
    expect(find.text('₱110.00/pcs · 45% margin'), findsOneWidget);
  });

  testWidgets(
      'adding a row appends an option with a fresh, non-empty id — '
      'catches a hardcoded/blank/reused id',
      (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: const [],
      onChanged: (next) => captured = next,
    ));
    await tester.tap(find.byKey(const Key('add-selling-option')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selling-option-row-0')), findsOneWidget);
    expect(captured, isNotNull);
    expect(captured!.length, 1);
    expect(captured!.single.id, isNotEmpty);
  });

  testWidgets(
      'adding two rows mints two distinct ids — catches a fixed/counter-reset id',
      (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: const [],
      onChanged: (next) => captured = next,
    ));
    await tester.tap(find.byKey(const Key('add-selling-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-selling-option')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(captured![0].id, isNot(equals(captured![1].id)));
  });

  testWidgets('removing a row drops it', (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.tap(find.byKey(const Key('remove-selling-option-0')));
    await tester.pumpAndSettle();

    expect(find.text('By 3'), findsNothing);
    expect(captured, isNotNull);
    expect(captured, isEmpty);
  });

  testWidgets(
      'shows the add button when under the 10-option cap (9 options) — '
      'paired with the cap test below, so an always-hidden button also fails',
      (tester) async {
    final nine = List.generate(
      9,
      (i) =>
          SellingOptionEntity(id: '$i', label: 'By $i', pieces: i + 1, price: 100),
    );
    await pump(tester, nine);
    expect(find.byKey(const Key('add-selling-option')), findsOneWidget);
  });

  testWidgets(
      'hides the add button at the 10-option cap — '
      'paired with the 9-option test above, so an always-shown button also fails',
      (tester) async {
    final ten = List.generate(
      10,
      (i) =>
          SellingOptionEntity(id: '$i', label: 'By $i', pieces: i + 1, price: 100),
    );
    await pump(tester, ten);
    expect(find.byKey(const Key('add-selling-option')), findsNothing);
  });

  testWidgets('shows no validation message for an already-valid list',
      (tester) async {
    await pump(tester, [by3]);
    expect(
      find.text(validateSellingOptions([by3, by3.copyWith(id: 'o9')])!),
      findsNothing,
    );
  });

  testWidgets(
      'shows the exact validation message for a duplicate label — '
      'catches a generic/placeholder error string',
      (tester) async {
    final options = [by3, by3.copyWith(id: 'o9')];
    await pump(tester, options);
    expect(
      find.text(validateSellingOptions(options)!),
      findsOneWidget,
    );
    // Pin the literal text too, so a change to validateSellingOptions'
    // wording is visible here rather than only passing through indirection.
    expect(
      find.text('Option labels must be unique — "By 3" is used twice.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows the exact validation message for a non-positive price — '
      'catches a validator call site that ignores this branch',
      (tester) async {
    final options = [by3.copyWith(price: 0)];
    await pump(tester, options);
    expect(
      find.text('"By 3" needs a price above zero.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'editing the label field propagates the new label without minting a '
      'new id', (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.enterText(
      find.byKey(const Key('selling-option-label-0')),
      'By Six',
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.label, 'By Six');
    expect(captured!.single.id, by3.id);
  });

  testWidgets(
      'editing the pieces field updates pieces and the recomputed caption',
      (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.enterText(
      find.byKey(const Key('selling-option-pieces-0')),
      '6',
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.pieces, 6);
    // 330 / 6 = 55/pc — distinct from the original 110/pc.
    expect(find.textContaining('₱55.00/pc'), findsOneWidget);
  });

  testWidgets('editing the price field updates price and the recomputed caption',
      (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.enterText(
      find.byKey(const Key('selling-option-price-0')),
      '360',
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.price, 360);
    // 360 / 3 = 120/pc — distinct from the original 110/pc.
    expect(find.textContaining('₱120.00/pc'), findsOneWidget);
  });

  testWidgets(
      'shows the margin segment when showMargin is true, alongside the '
      'per-piece price', (tester) async {
    await pump(tester, [by3], showMargin: true);
    expect(find.text('₱110.00/pcs · 45% margin'), findsOneWidget);
  });

  testWidgets(
      'hides the margin segment when showMargin is false, but keeps the '
      'per-piece price — catches gating the whole caption (or nothing at '
      'all) instead of just the cost-derived half', (tester) async {
    await pump(tester, [by3], showMargin: false);
    expect(find.text('₱110.00/pcs'), findsOneWidget);
    expect(find.textContaining('margin'), findsNothing);
  });

  testWidgets(
      'clearing the pieces field zeroes pieces (not the stale value) and '
      'surfaces the "must cover" error — catches silently keeping the old '
      'value when parsing fails', (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.enterText(
      find.byKey(const Key('selling-option-pieces-0')),
      '',
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.pieces, 0);
    expect(
      find.textContaining('must cover at least 1 piece'),
      findsOneWidget,
    );
  });

  testWidgets(
      'clearing the price field zeroes price (not the stale value) and '
      'surfaces the "needs a price" error — catches silently keeping the '
      'old value when parsing fails', (tester) async {
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (next) => captured = next,
    ));
    await tester.enterText(
      find.byKey(const Key('selling-option-price-0')),
      '',
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.price, 0);
    expect(
      find.textContaining('needs a price above zero'),
      findsOneWidget,
    );
  });

  testWidgets(
      'removing the first of two rows keeps the second option and '
      'renumbers its row/remove keys', (tester) async {
    const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
    List<SellingOptionEntity>? captured;
    await tester.pumpWidget(harness(
      initial: [by6, by3],
      onChanged: (next) => captured = next,
    ));
    await tester.tap(find.byKey(const Key('remove-selling-option-0')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.single.id, by3.id);
    expect(find.text('By 6'), findsNothing);
    expect(find.text('By 3'), findsOneWidget);
    expect(find.byKey(const Key('selling-option-row-0')), findsOneWidget);
    expect(find.byKey(const Key('remove-selling-option-1')), findsNothing);
  });

  testWidgets(
      'uses the product\'s own unit as the per-piece suffix, not a hardcoded "pc"',
      (tester) async {
    await tester.pumpWidget(harness(
      initial: [by3],
      onChanged: (_) {},
      unit: 'box',
    ));
    await tester.pumpAndSettle();
    // 330 / 3 = 110/box. A hardcoded "pc" suffix would show "/pc" here
    // regardless of the product's own unit.
    expect(find.textContaining('₱110.00/box'), findsOneWidget);
    expect(find.textContaining('/pc'), findsNothing);
  });
}
