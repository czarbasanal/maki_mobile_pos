import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/drafts_list_screen.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  DraftEntity draft() => DraftEntity(
        id: 'd-1',
        name: 'Plate ABC-123',
        items: const [
          SaleItemEntity(
            id: 'i-1',
            productId: 'p-1',
            sku: 'SKU-1',
            name: 'Widget',
            unitPrice: 100,
            unitCost: 60,
            quantity: 1,
          ),
        ],
        createdBy: 'admin-1',
        createdByName: 'Admin',
        createdAt: DateTime(2026, 6, 1, 9),
      );

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/drafts',
      routes: [
        GoRoute(path: '/drafts', builder: (_, __) => const DraftsListScreen()),
        GoRoute(
          path: '/drafts/:id',
          name: RouteNames.draftEdit,
          builder: (_, s) =>
              Scaffold(body: Text('EDITOR-${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDraftsProvider.overrideWith((ref) => Stream.value([draft()])),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          activeMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value(const [])),
          activeMechanicsProvider
              .overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Job Orders title with app-bar create only, no FAB',
      (tester) async {
    await pump(tester);
    expect(find.text('Job Orders'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
  });

  testWidgets('app-bar plus opens the New Job Order dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('New Job Order'), findsOneWidget);
  });

  testWidgets('tapping Open navigates to the ticket editor', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('EDITOR-d-1'), findsOneWidget);
  });
}
