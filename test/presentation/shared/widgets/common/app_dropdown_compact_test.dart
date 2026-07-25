import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

Widget _host({bool compact = false}) => MaterialApp(
      home: Scaffold(
        body: AppDropdown<int>(
          compact: compact,
          initialValue: 1,
          decoration: const InputDecoration(labelText: 'Pick'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('One')),
            DropdownMenuItem(value: 2, child: Text('Two')),
          ],
          onChanged: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('compact renders 13px value text and a dense decoration',
      (tester) async {
    await tester.pumpWidget(_host(compact: true));
    // Closed-button value text inherits the compact DefaultTextStyle.
    final valueStyle =
        DefaultTextStyle.of(tester.element(find.text('One'))).style;
    expect(valueStyle.fontSize, 13);
    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.isDense, isTrue);
  });

  testWidgets('compact menu items render 13px', (tester) async {
    await tester.pumpWidget(_host(compact: true));
    await tester.tap(find.byType(AppDropdown<int>));
    await tester.pumpAndSettle();
    final itemStyle =
        DefaultTextStyle.of(tester.element(find.text('Two').last)).style;
    expect(itemStyle.fontSize, 13);
  });

  testWidgets('non-compact stays default (no dense injection)',
      (tester) async {
    await tester.pumpWidget(_host());
    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.isDense, isNot(isTrue));
    final valueStyle =
        DefaultTextStyle.of(tester.element(find.text('One'))).style;
    expect(valueStyle.fontSize, isNot(13));
  });
}
