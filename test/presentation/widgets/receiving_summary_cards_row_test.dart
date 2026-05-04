import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/receiving_summary_cards_row.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';

ReceivingEntity _completed({
  required String id,
  required DateTime completedAt,
  double totalCost = 0,
}) {
  return ReceivingEntity(
    id: id,
    referenceNumber: id.toUpperCase(),
    items: const [],
    totalCost: totalCost,
    totalQuantity: 0,
    status: ReceivingStatus.completed,
    createdAt: completedAt,
    completedAt: completedAt,
    createdBy: 'u',
    createdByName: 'User',
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required AsyncValue<Map<ReceivingStatus, int>> counts,
  required List<ReceivingEntity> recent,
  Stream<List<ReceivingEntity>>? recentStream,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        receivingCountsProvider.overrideWith((ref) async {
          // Fail fast for the loading-counts case using a never-completing
          // future.
          if (counts.isLoading) {
            final c = Completer<Map<ReceivingStatus, int>>();
            addTearDown(() {
              if (!c.isCompleted) c.complete({});
            });
            return c.future;
          }
          if (counts.hasError) {
            throw counts.error!;
          }
          return counts.value!;
        }),
        recentReceivingsProvider.overrideWith(
          (ref) => recentStream ?? Stream.value(recent),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ReceivingSummaryCardsRow()),
      ),
    ),
  );
}

void main() {
  group('ReceivingSummaryCardsRow', () {
    testWidgets('shows three labels regardless of state', (tester) async {
      await _pump(
        tester,
        counts: const AsyncValue.data({
          ReceivingStatus.draft: 0,
          ReceivingStatus.completed: 0,
        }),
        recent: const [],
      );
      await tester.pumpAndSettle();

      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Total Received'), findsOneWidget);
    });

    testWidgets(
        'spinners on Drafts + Completed cards while counts are loading; '
        'Total resolves independently from the recent stream',
        (tester) async {
      // Counts provider is the source for Drafts + (with the MTD count)
      // Completed; the recent stream resolves fast → Total Received's
      // peso provider settles immediately while the other two spin.
      await _pump(
        tester,
        counts: const AsyncValue.loading(),
        recent: const [],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });

    testWidgets(
        'spinner on every card while both providers are loading',
        (tester) async {
      // A never-completing recent stream keeps the peso-total provider
      // in the loading state, mirroring a cold-start before any data
      // arrives.
      final completer = Completer<List<ReceivingEntity>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(<ReceivingEntity>[]);
      });

      await _pump(
        tester,
        counts: const AsyncValue.loading(),
        recent: const [],
        recentStream: completer.future.asStream(),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
    });

    testWidgets('renders draft count and MTD completed count when loaded',
        (tester) async {
      // Two completed receivings this month → MTD count = 2.
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 2);
      final recent = [
        _completed(id: 'a', completedAt: monthStart, totalCost: 200),
        _completed(id: 'b', completedAt: monthStart, totalCost: 300),
      ];

      await _pump(
        tester,
        counts: const AsyncValue.data({
          ReceivingStatus.draft: 5,
          ReceivingStatus.completed: 17,
        }),
        recent: recent,
      );
      await tester.pumpAndSettle();

      // Drafts uses the all-time draft count from getReceivingCounts.
      expect(find.text('5'), findsOneWidget);
      // Completed reflects the MTD-derived count, not the all-time 17.
      expect(find.text('2'), findsOneWidget);
      // Total Received = 200 + 300 = ₱500 (formatPesoCompact branch ≤999).
      expect(find.text('₱500'), findsOneWidget);
    });

    testWidgets('peso compact formatter — thousands suffix', (tester) async {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final recent = [
        _completed(id: 'a', completedAt: monthStart, totalCost: 1500),
      ];

      await _pump(
        tester,
        counts: const AsyncValue.data({
          ReceivingStatus.draft: 0,
          ReceivingStatus.completed: 1,
        }),
        recent: recent,
      );
      await tester.pumpAndSettle();

      expect(find.text('₱1.5K'), findsOneWidget);
    });

    testWidgets('hides the row entirely when counts provider errors',
        (tester) async {
      await _pump(
        tester,
        counts: AsyncValue.error('boom', StackTrace.empty),
        recent: const [],
      );
      await tester.pumpAndSettle();

      expect(find.text('Drafts'), findsNothing);
      expect(find.text('Completed'), findsNothing);
      expect(find.text('Total Received'), findsNothing);
    });

    testWidgets('Drafts and Completed cards are tappable when handlers wired',
        (tester) async {
      var draftsTapped = false;
      var completedTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receivingCountsProvider.overrideWith((ref) async => {
                  ReceivingStatus.draft: 1,
                  ReceivingStatus.completed: 1,
                }),
            recentReceivingsProvider.overrideWith((ref) =>
                Stream.value(<ReceivingEntity>[])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReceivingSummaryCardsRow(
                onTapDrafts: () => draftsTapped = true,
                onTapCompleted: () => completedTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Drafts'));
      expect(draftsTapped, isTrue);

      await tester.tap(find.text('Completed'));
      expect(completedTapped, isTrue);
    });
  });
}
