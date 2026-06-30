import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

void main() {
  const kind = CategoryKind.unit;

  Widget harness(Override override) => ProviderScope(
        overrides: [override],
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
}
