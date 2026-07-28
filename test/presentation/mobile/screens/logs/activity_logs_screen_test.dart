import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/logs/activity_logs_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

ActivityLogEntity _log(String action) => ActivityLogEntity(
      id: action,
      type: ActivityType.sale,
      action: action,
      userId: 'u1',
      userName: 'Tester',
      userRole: 'admin',
      createdAt: DateTime.now(),
    );

void main() {
  late _MockActivityLogRepository repo;

  setUp(() {
    repo = _MockActivityLogRepository();
    when(() => repo.getActivityLogs(
          types: any(named: 'types'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [_log('Sold something')]);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activityLogRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: ActivityLogsScreen()),
    ));
    await tester.pump();
  }

  testWidgets('opening the screen fetches nothing', (tester) async {
    await pumpScreen(tester);

    verifyNever(() => repo.getActivityLogs(
          types: any(named: 'types'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        ));
    expect(find.text('Pick your filters and tap Search.'), findsOneWidget);
  });

  testWidgets('tapping Search fetches once and renders results',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    verify(() => repo.getActivityLogs(
          types: any(named: 'types'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: kActivityLogSearchLimit,
        )).called(1);
    expect(find.text('Sold something'), findsOneWidget);
  });

  testWidgets('the filter card collapses after a successful search',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsNothing);
    expect(find.textContaining('All operations'), findsOneWidget);
  });

  testWidgets('changing a filter after a search does not refetch',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Reopen the card and tick one operation. The chip list scrolls, so
    // make sure the target is on screen before tapping it.
    await tester.tap(find.textContaining('All operations'));
    await tester.pumpAndSettle();
    final saleChip = find.widgetWithText(FilterChip, 'Sale');
    await tester.ensureVisible(saleChip);
    await tester.pumpAndSettle();
    await tester.tap(saleChip);
    await tester.pumpAndSettle();

    verify(() => repo.getActivityLogs(
          types: any(named: 'types'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).called(1);
    expect(find.text('Filters changed — tap Search.'), findsOneWidget);
  });

  testWidgets('an empty result shows the no-match message', (tester) async {
    when(() => repo.getActivityLogs(
          types: any(named: 'types'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => []);

    await pumpScreen(tester);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('No activity matched these filters'), findsOneWidget);
  });
}
