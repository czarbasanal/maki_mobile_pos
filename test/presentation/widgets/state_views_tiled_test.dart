import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('default EmptyStateView renders a bare 64px icon',
      (tester) async {
    await pump(
      tester,
      const EmptyStateView(
        icon: LucideIcons.clipboardList,
        title: 'No job orders yet',
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.clipboardList));
    expect(icon.size, 64);
  });

  testWidgets('tiled EmptyStateView renders a soft square tile with 40px icon',
      (tester) async {
    await pump(
      tester,
      const EmptyStateView(
        icon: LucideIcons.clipboardList,
        title: 'No job orders yet',
        tiled: true,
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.clipboardList));
    expect(icon.size, 40);

    // The icon sits inside an 86x86 rounded tile.
    final tile = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(LucideIcons.clipboardList),
        matching: find.byType(Container),
      ),
    );
    expect(tile.constraints?.maxWidth, 86);
    expect(tile.constraints?.maxHeight, 86);
  });
}
