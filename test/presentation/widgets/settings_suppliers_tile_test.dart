// Supplier management existed on mobile — screens, form, use-cases, routes and
// guards — but nothing in the app ever navigated to it, so an admin could not
// reach it. The Administration section is the way in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/theme_mode_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u-1',
        email: 'u@x.com',
        displayName: 'User',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  Future<void> pumpSettings(WidgetTester tester, UserRole role) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Administration section shows a Suppliers tile for admins',
      (tester) async {
    await pumpSettings(tester, UserRole.admin);

    await tester.scrollUntilVisible(
      find.text('Suppliers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Suppliers'), findsOneWidget);
    expect(find.text('Add, edit, and manage suppliers'), findsOneWidget);
  });

  testWidgets('staff do not see the Suppliers tile', (tester) async {
    // viewSuppliers is admin-only, so the way in must be too — otherwise the
    // tile leads straight to a route guard rejection.
    await pumpSettings(tester, UserRole.staff);

    expect(find.text('Suppliers'), findsNothing);
  });

  testWidgets('cashiers do not see the Suppliers tile', (tester) async {
    await pumpSettings(tester, UserRole.cashier);

    expect(find.text('Suppliers'), findsNothing);
  });
}
