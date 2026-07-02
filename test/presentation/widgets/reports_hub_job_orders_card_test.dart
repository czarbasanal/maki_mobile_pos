import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/reports_hub_screen.dart';

void main() {
  UserEntity u(UserRole role) => UserEntity(
        id: 'u',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  Widget host(UserRole role) => ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(u(role))),
        ],
        child: const MaterialApp(home: ReportsHubScreen()),
      );

  testWidgets('admin sees the Job Orders card', (tester) async {
    await tester.pumpWidget(host(UserRole.admin));
    await tester.pumpAndSettle();
    expect(find.text('Job Orders'), findsOneWidget);
  });

  testWidgets('cashier does not see the Job Orders card', (tester) async {
    await tester.pumpWidget(host(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.text('Job Orders'), findsNothing);
  });
}
