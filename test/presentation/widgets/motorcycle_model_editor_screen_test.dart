import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  UserEntity currentUser(UserRole role) => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  MotorcycleModelEntity m(String id, String name, {bool active = true}) =>
      MotorcycleModelEntity(
        id: id,
        name: name,
        isActive: active,
        createdAt: DateTime(2026, 1, 1),
      );

  Widget host(
    List<MotorcycleModelEntity> models, {
    UserRole role = UserRole.admin,
  }) =>
      ProviderScope(
        overrides: [
          allMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value(models)),
          currentUserProvider
              .overrideWith((ref) => Stream.value(currentUser(role))),
        ],
        child: const MaterialApp(home: MotorcycleModelEditorScreen()),
      );

  testWidgets('renders the model list (active + inactive)', (tester) async {
    await tester.pumpWidget(host([m('1', 'Nmax'), m('2', 'Aerox', active: false)]));
    await tester.pumpAndSettle();
    expect(find.text('Motorcycle Models'), findsOneWidget); // AppBar title
    expect(find.text('Nmax'), findsOneWidget);
    expect(find.text('Aerox'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no models', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text('No motorcycle models yet'), findsOneWidget);
  });

  testWidgets('cashier sees edit but no deactivate toggle', (tester) async {
    await tester.pumpWidget(
      host([m('1', 'Nmax')], role: UserRole.cashier),
    );
    await tester.pumpAndSettle();

    // Edit affordance still present on every row…
    expect(find.byIcon(LucideIcons.squarePen), findsWidgets);
    // …but the archive (deactivate) affordance is gone.
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
  });
}
