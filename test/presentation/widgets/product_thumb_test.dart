import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/common/product_thumb.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('falls back to a neutral tile when there is no image url',
      (tester) async {
    await pump(tester, const ProductThumb(name: 'Motul 3000', imageUrl: null));
    expect(find.byType(Image), findsNothing);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('renders a network image when a url is set', (tester) async {
    await pump(
      tester,
      const ProductThumb(
        name: 'Motul 3000',
        imageUrl: 'https://example.com/x.jpg',
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
