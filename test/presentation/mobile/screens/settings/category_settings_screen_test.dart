import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_settings_screen.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
      ],
      child: const MaterialApp(home: CategorySettingsScreen()),
    );

void main() {
  testWidgets('cashier does not see the Product Categories tile',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.text('Product Categories'), findsNothing);
    expect(find.text('Expense Categories'), findsOneWidget);
  });

  testWidgets('staff sees the Product Categories tile', (tester) async {
    await tester.pumpWidget(_harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.text('Product Categories'), findsOneWidget);
  });
}
