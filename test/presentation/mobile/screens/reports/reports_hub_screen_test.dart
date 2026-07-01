import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/reports_hub_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
      ],
      child: const MaterialApp(home: ReportsHubScreen()),
    );

void main() {
  testWidgets('admin sees Sales, Profit, Labor', (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('Labor'), findsOneWidget);
    expect(find.text('Price Changes'), findsOneWidget);
  });

  testWidgets('non-admin does not see Profit', (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Profit'), findsNothing);
    expect(find.text('Labor'), findsOneWidget);
    expect(find.text('Price Changes'), findsNothing);
  });
}
