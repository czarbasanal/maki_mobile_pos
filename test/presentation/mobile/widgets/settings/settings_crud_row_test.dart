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
  });
}
