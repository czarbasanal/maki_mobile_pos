import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_filter_card.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

void main() {
  final now = DateTime(2026, 7, 28, 10, 0);

  group('activityFilterSummary', () {
    test('whole-day today with no type filter omits the time part', () {
      final s = activityFilterSummary(
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 7, 28, 23, 59, 59, 999),
        typeCount: 0,
        now: now,
      );
      expect(s, 'Today · All operations');
    });

    test('yesterday is labelled rather than dated', () {
      final s = activityFilterSummary(
        start: DateTime(2026, 7, 27),
        end: DateTime(2026, 7, 27, 23, 59, 59, 999),
        typeCount: 0,
        now: now,
      );
      expect(s, 'Yesterday · All operations');
    });

    test('a partial-day window includes the time span', () {
      final s = activityFilterSummary(
        start: DateTime(2026, 7, 28, 8, 0),
        end: DateTime(2026, 7, 28, 17, 0, 59, 999),
        typeCount: 3,
        now: now,
      );
      expect(s, 'Today · 8:00 AM–5:00 PM · 3 operations');
    });

    test('a multi-day window shows both dates', () {
      final s = activityFilterSummary(
        start: DateTime(2026, 7, 20),
        end: DateTime(2026, 7, 28, 23, 59, 59, 999),
        typeCount: 1,
        now: now,
      );
      expect(s, 'Jul 20 – Jul 28 · 1 operation');
    });
  });

  group('ActivityLogFilterCard', () {
    Widget host({
      required bool expanded,
      List<ActivityType> selected = const [],
      bool dirty = false,
      VoidCallback? onSearch,
      VoidCallback? onToggleExpanded,
      DateTime? startDate,
      DateTime? endDate,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ActivityLogFilterCard(
            expanded: expanded,
            selectedTypes: selected,
            preset: DateRangePreset.today,
            startDate: startDate ?? DateTime(2026, 7, 28),
            endDate: endDate ?? DateTime(2026, 7, 28),
            startTime: startTime ?? const TimeOfDay(hour: 0, minute: 0),
            endTime: endTime ?? const TimeOfDay(hour: 23, minute: 59),
            dirty: dirty,
            onToggleExpanded: onToggleExpanded ?? () {},
            onTypesChanged: (_) {},
            onPresetChanged: (_) {},
            onCustomRangeSelected: (_, __) {},
            onStartTimeChanged: (_) {},
            onEndTimeChanged: (_) {},
            onSearch: onSearch ?? () {},
          ),
        ),
      );
    }

    testWidgets('expanded shows the Search button', (tester) async {
      await tester.pumpWidget(host(expanded: true));
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('collapsed hides Search and shows the summary line',
        (tester) async {
      await tester.pumpWidget(host(expanded: false));
      expect(find.text('Search'), findsNothing);
      expect(find.textContaining('All operations'), findsOneWidget);
    });

    testWidgets('tapping Search fires the callback once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(expanded: true, onSearch: () => taps++));
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('dirty shows the stale-results hint', (tester) async {
      await tester.pumpWidget(host(expanded: true, dirty: true));
      expect(find.text('Filters changed — tap Search.'), findsOneWidget);
    });

    testWidgets('tapping the collapsed summary asks to expand',
        (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
          host(expanded: false, onToggleExpanded: () => toggles++));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(toggles, 1);
    });

    testWidgets('Search is disabled when the range is invalid',
        (tester) async {
      await tester.pumpWidget(host(
        expanded: true,
        startDate: DateTime(2026, 7, 29),
        endDate: DateTime(2026, 7, 28),
      ));
      expect(find.text('Start must be before end.'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'toggling chips out of order still emits canonical enum order',
        (tester) async {
      List<ActivityType> emitted = const [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ActivityLogFilterCard(
                  expanded: true,
                  selectedTypes: emitted,
                  preset: DateRangePreset.today,
                  startDate: DateTime(2026, 7, 28),
                  endDate: DateTime(2026, 7, 28),
                  startTime: const TimeOfDay(hour: 0, minute: 0),
                  endTime: const TimeOfDay(hour: 23, minute: 59),
                  dirty: false,
                  onToggleExpanded: () {},
                  onTypesChanged: (v) => setState(() => emitted = v),
                  onPresetChanged: (_) {},
                  onCustomRangeSelected: (_, __) {},
                  onStartTimeChanged: (_) {},
                  onEndTimeChanged: (_) {},
                  onSearch: () {},
                );
              },
            ),
          ),
        ),
      );

      // dayClosed is declared near the end of ActivityType.values;
      // authentication is declared first. Tap the later-declared type
      // first, then the earlier-declared one, and confirm the emitted
      // list still comes back in canonical enum order rather than
      // click order.
      final lateChip = find.widgetWithText(
          FilterChip, ActivityType.dayClosed.displayName);
      final earlyChip = find.widgetWithText(
          FilterChip, ActivityType.authentication.displayName);

      await tester.ensureVisible(lateChip);
      await tester.tap(lateChip);
      await tester.pump();

      await tester.ensureVisible(earlyChip);
      await tester.tap(earlyChip);
      await tester.pump();

      expect(emitted, [ActivityType.authentication, ActivityType.dayClosed]);
    });
  });
}
