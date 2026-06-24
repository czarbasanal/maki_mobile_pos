import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/summary_row.dart';

Widget _host(Widget child, {double? width}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: width == null ? child : SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  group('SummaryRow', () {
    testWidgets('renders the label and value', (tester) async {
      await tester.pumpWidget(
        _host(const SummaryRow(label: 'Subtotal', value: '₱200.00')),
      );
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('₱200.00'), findsOneWidget);
    });

    testWidgets('a long label does not overflow a narrow row', (tester) async {
      // The regression guard: in a constrained width a long label must
      // ellipsize rather than throw a RenderFlex overflow.
      await tester.pumpWidget(
        _host(
          const SummaryRow(
            label: 'Subtotal · 1234 items for this very long mechanic name',
            value: '₱99,999.00',
          ),
          width: 180,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('₱99,999.00'), findsOneWidget);
    });

    testWidgets('a long total label ellipsizes so the hero value is never cut',
        (tester) async {
      // The hero amount is the anchor and must stay fully visible; the label
      // yields. Width is a realistic card width where the value fits.
      await tester.pumpWidget(
        _host(
          const SummaryRow(
            label: 'Total (1234 items) for a very long label',
            value: '₱99,999.00',
            isTotal: true,
          ),
          width: 300,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('₱99,999.00'), findsOneWidget);
    });

    testWidgets('renders the total value as a primary-colored hero',
        (tester) async {
      await tester.pumpWidget(
        _host(const SummaryRow(label: 'Total', value: '₱650.00', isTotal: true)),
      );
      final value = tester.widget<Text>(find.text('₱650.00'));
      expect(value.style?.fontSize, 26);
      expect(value.style?.fontWeight, FontWeight.w700);
      final context = tester.element(find.text('₱650.00'));
      expect(value.style?.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('applies valueColor to a non-total value', (tester) async {
      const green = Color(0xFF8FE39A);
      await tester.pumpWidget(
        _host(const SummaryRow(
          label: 'Discount',
          value: '-₱5.00',
          valueColor: green,
        )),
      );
      final value = tester.widget<Text>(find.text('-₱5.00'));
      expect(value.style?.color, green);
    });
  });
}
