import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

UserEntity _user() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'U',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  testWidgets('AppBar has no reports shortcut icon', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user())),
        salesByDateRangeProvider
            .overrideWith((ref, params) async => <SaleEntity>[]),
      ],
      child: const MaterialApp(home: SalesListScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sales History'), findsOneWidget);
    expect(find.byIcon(LucideIcons.barChart3), findsNothing);
  });
}
