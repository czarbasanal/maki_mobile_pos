import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

ReceivingEntity _completed({
  required String id,
  required DateTime completedAt,
  String? supplierName,
}) {
  return ReceivingEntity(
    id: id,
    referenceNumber: id.toUpperCase(),
    items: const [],
    totalCost: 100,
    totalQuantity: 1,
    status: ReceivingStatus.completed,
    createdAt: completedAt,
    completedAt: completedAt,
    supplierName: supplierName,
    createdBy: 'u',
    createdByName: 'User',
  );
}

ReceivingEntity _draft({
  required String id,
  required DateTime createdAt,
}) {
  return ReceivingEntity(
    id: id,
    referenceNumber: id.toUpperCase(),
    items: const [],
    totalCost: 0,
    totalQuantity: 0,
    status: ReceivingStatus.draft,
    createdAt: createdAt,
    createdBy: 'u',
    createdByName: 'User',
  );
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/receiving/history',
    routes: [
      GoRoute(
        path: '/receiving/history',
        builder: (_, __) => const ReceivingHistoryScreen(),
      ),
      // Placeholder routes the screen pushes onto — keeping them as
      // empty Scaffolds so go_router can resolve the deep link without
      // pulling in the rest of the app.
      GoRoute(
        path: '/receiving',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/receiving/bulk/:id',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<ReceivingEntity> sales,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        recentReceivingsProvider.overrideWith((ref) => Stream.value(sales)),
      ],
      child: MaterialApp.router(routerConfig: _buildTestRouter()),
    ),
  );
}

void main() {
  group('ReceivingHistoryScreen', () {
    testWidgets('renders the empty state when no completed receivings',
        (tester) async {
      await _pump(tester, const []);
      await tester.pumpAndSettle();

      expect(find.text('No Receiving History'), findsOneWidget);
    });

    testWidgets('shows month headers most-recent first when records span months',
        (tester) async {
      final receivings = [
        _completed(id: 'apr-1', completedAt: DateTime(2026, 4, 5)),
        _completed(id: 'may-1', completedAt: DateTime(2026, 5, 2)),
        _completed(id: 'mar-1', completedAt: DateTime(2026, 3, 28)),
      ];
      await _pump(tester, receivings);
      await tester.pumpAndSettle();

      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('April 2026'), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);

      // Each month header carries a count badge — three single-item
      // groups means three "1" labels rendered alongside the headers.
      expect(find.text('1'), findsNWidgets(3));
    });

    testWidgets('multiple receivings in a month show under one header',
        (tester) async {
      final receivings = [
        _completed(id: 'a', completedAt: DateTime(2026, 5, 1)),
        _completed(id: 'b', completedAt: DateTime(2026, 5, 15)),
        _completed(id: 'c', completedAt: DateTime(2026, 5, 28)),
      ];
      await _pump(tester, receivings);
      await tester.pumpAndSettle();

      expect(find.text('May 2026'), findsOneWidget);
      // Group's count badge reflects all three items.
      expect(find.text('3'), findsOneWidget);
      // All three reference numbers render.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('drafts in the source stream are not shown in history',
        (tester) async {
      final receivings = [
        _completed(id: 'completed', completedAt: DateTime(2026, 5, 5)),
        _draft(id: 'draft', createdAt: DateTime(2026, 5, 10)),
      ];
      await _pump(tester, receivings);
      await tester.pumpAndSettle();

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('DRAFT'), findsNothing);
    });
  });
}
