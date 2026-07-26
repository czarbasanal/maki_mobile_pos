import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';

void main() {
  group('SettingsCrudRow', () {
    testWidgets('onDelete renders a trash action that fires the callback',
        (tester) async {
      var deleted = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsCrudRow(
            name: 'Brakes',
            isActive: true,
            onEdit: () {},
            onToggleActive: () {},
            onDelete: () => deleted = true,
          ),
        ),
      ));
      await tester.tap(find.byIcon(LucideIcons.trash2));
      expect(deleted, isTrue);
    });

    testWidgets('no trash action when onDelete is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsCrudRow(name: 'Brakes', isActive: true, onEdit: () {}),
        ),
      ));
      expect(find.byIcon(LucideIcons.trash2), findsNothing);
    });

    testWidgets('badge renders with RobotoMono font when provided',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsCrudRow(
            name: 'Parts',
            isActive: true,
            onEdit: () {},
            badge: '0007',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Find text with RobotoMono fontFamily
      final textFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0007' &&
            (widget.style?.fontFamily ?? '').contains('RobotoMono'),
      );
      expect(textFinder, findsOneWidget);
    });

    testWidgets('no badge renders when badge is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsCrudRow(
            name: 'Parts',
            isActive: true,
            onEdit: () {},
            badge: null,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Ensure no '0007' text exists
      expect(find.text('0007'), findsNothing);
    });

    testWidgets('badge strikethrough is preserved on inactive row',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsCrudRow(
            name: 'Parts',
            isActive: false,
            onEdit: () {},
            badge: '0007',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify badge still renders
      final badgeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0007' &&
            (widget.style?.fontFamily ?? '').contains('RobotoMono'),
      );
      expect(badgeFinder, findsOneWidget);

      // Verify name is struck through
      final nameFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Parts' &&
            widget.style?.decoration == TextDecoration.lineThrough,
      );
      expect(nameFinder, findsOneWidget);
    });
  });
}
