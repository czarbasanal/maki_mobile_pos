import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/theme_mode_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  testWidgets('Lists section shows a Motorcycle Models tile for admins',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Motorcycle Models'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Motorcycle Models'), findsOneWidget);
    expect(find.text('Models picked on job orders'), findsOneWidget);
  });
}
