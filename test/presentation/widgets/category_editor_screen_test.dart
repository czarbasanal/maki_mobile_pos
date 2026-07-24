import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

void main() {
  const kind = CategoryKind.unit;

  UserEntity currentUser(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 7, 24),
      );

  Widget harness(Override override, {UserRole role = UserRole.admin}) =>
      ProviderScope(
        overrides: [
          override,
          currentUserProvider
              .overrideWith((ref) => Stream.value(currentUser(role))),
        ],
        child: const MaterialApp(home: CategoryEditorScreen(kind: kind)),
      );

  testWidgets('loading state renders a ListSkeleton, not a raw spinner',
      (tester) async {
    // A never-completing stream keeps the provider in the loading state.
    final override = allCategoriesProvider(kind).overrideWith(
      (ref) => Stream<List<CategoryEntity>>.fromFuture(
        Completer<List<CategoryEntity>>().future,
      ),
    );

    await tester.pumpWidget(harness(override));
    await tester.pump();

    expect(find.byType(ListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error state renders ErrorStateView with a Retry action',
      (tester) async {
    final override = allCategoriesProvider(kind).overrideWith(
      (ref) => Stream<List<CategoryEntity>>.error(Exception('network down')),
    );

    await tester.pumpWidget(harness(override));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('empty state renders the shared EmptyStateView', (tester) async {
    final override = allCategoriesProvider(kind).overrideWith(
      (ref) => Stream<List<CategoryEntity>>.value(const []),
    );

    await tester.pumpWidget(harness(override));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
  });

  testWidgets('cashier sees edit but no deactivate toggle', (tester) async {
    final override = allCategoriesProvider(kind).overrideWith(
      (ref) => Stream<List<CategoryEntity>>.value([
        CategoryEntity(
          id: '1',
          name: 'pcs',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ]),
    );

    await tester.pumpWidget(harness(override, role: UserRole.cashier));
    await tester.pumpAndSettle();

    // Edit affordance still present on every row…
    expect(find.byIcon(LucideIcons.squarePen), findsWidgets);
    // …but the archive (deactivate) affordance is gone.
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
  });

  testWidgets('void-reasons editor has no seed-defaults overflow menu',
      (tester) async {
    final override = allCategoriesProvider(CategoryKind.voidReason).overrideWith(
      (ref) => Stream.value(const <CategoryEntity>[]),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        override,
        currentUserProvider
            .overrideWith((ref) => Stream.value(currentUser(UserRole.admin))),
      ],
      child: const MaterialApp(
        home: CategoryEditorScreen(kind: CategoryKind.voidReason),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.moreVertical), findsNothing);
  });

  testWidgets('unit editor still offers the seed-defaults overflow menu',
      (tester) async {
    final override = allCategoriesProvider(kind).overrideWith(
      (ref) => Stream.value(const <CategoryEntity>[]),
    );
    await tester.pumpWidget(harness(override));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.moreVertical), findsOneWidget);
  });
}
