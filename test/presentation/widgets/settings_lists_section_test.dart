import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/theme_mode_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 7, 24),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  testWidgets('cashier sees the three list tiles but no admin tiles',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Motorcycle Models'), 200);
    expect(find.text('Manage Lists'), findsOneWidget);
    expect(find.text('Mechanics'), findsOneWidget);
    expect(find.text('Motorcycle Models'), findsOneWidget);
    expect(find.text('User Management'), findsNothing);
    expect(find.text('Cost Code Settings'), findsNothing);
  });

  testWidgets('admin keeps admin tiles and also sees the list tiles',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Motorcycle Models'), 200);
    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Manage Lists'), findsOneWidget);
    expect(find.text('Mechanics'), findsOneWidget);
    expect(find.text('Motorcycle Models'), findsOneWidget);
  });
}
