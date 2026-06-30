import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/users/user_list_tile.dart';

UserEntity _user({
  String id = 'u1',
  String name = 'Maria Santos',
  UserRole role = UserRole.staff,
  bool isActive = true,
}) {
  return UserEntity(
    id: id,
    email: 'maria@example.com',
    displayName: name,
    role: role,
    isActive: isActive,
    createdAt: DateTime(2026, 2, 14),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('UserListTile', () {
    testWidgets('current user shows a "You" tag and a chevron (no overflow)',
        (tester) async {
      await tester.pumpWidget(_wrap(UserListTile(
        user: _user(),
        isCurrentUser: true,
        onTap: () {},
        // current user → screen passes null (no self-deactivate)
        onToggleActive: null,
      )));

      expect(find.text('You'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
      expect(find.byIcon(LucideIcons.moreVertical), findsNothing);
    });

    testWidgets('other user shows the overflow menu, not a chevron',
        (tester) async {
      await tester.pumpWidget(_wrap(UserListTile(
        user: _user(),
        isCurrentUser: false,
        onTap: () {},
        onToggleActive: () {},
      )));

      expect(find.byIcon(LucideIcons.moreVertical), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
      expect(find.text('You'), findsNothing);
    });

    testWidgets('inactive user renders an "Inactive" tag and strikethrough name',
        (tester) async {
      await tester.pumpWidget(_wrap(UserListTile(
        user: _user(isActive: false),
        isCurrentUser: false,
        onTap: () {},
        onToggleActive: () {},
      )));

      expect(find.text('Inactive'), findsOneWidget);
      final nameText = tester.widget<Text>(find.text('Maria Santos'));
      expect(nameText.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('shows the role label', (tester) async {
      await tester.pumpWidget(_wrap(UserListTile(
        user: _user(role: UserRole.admin),
        isCurrentUser: false,
        onTap: () {},
        onToggleActive: () {},
      )));

      expect(find.text('Admin'), findsOneWidget);
    });
  });
}
