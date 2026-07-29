# Activity Logs Filter-then-Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop both activity-log screens from fetching on open; make the admin pick operations + a date/time range and tap Search before any read happens.

**Architecture:** Both surfaces drop their live Firestore subscription and issue a single one-shot read on button press. The screen holds "submitted filters" separately from "filters being edited" — while nothing is submitted, no query provider/hook is watched at all, so no read is issued. Filter UI is extracted into its own widget/component so the screen and page files stay focused on state and results.

**Tech Stack:** Flutter + Riverpod + `fake_cloud_firestore`/`mocktail` (mobile); React + Vite + TypeScript + Vitest + Testing Library (web); Firestore.

**Spec:** `docs/superpowers/specs/2026-07-28-activity-logs-search-gate-design.md`

## Global Constraints

- Collection is `user_logs` (`FirestoreCollections.userLogs`), admin-read-only per `firestore.rules:273`.
- Result cap is **500** on both surfaces. Constant name: `kActivityLogSearchLimit` (Dart) / `ACTIVITY_LOG_SEARCH_LIMIT` (TS).
- Date range is **one continuous window**, not a per-day window. Start bound inclusive at the chosen start time; end bound inclusive at the chosen end time with `:59.999` seconds appended.
- Default filters: **all operations, Today, whole day**. Nothing is fetched until Search is pressed.
- Selected operation lists must be built by filtering over the canonical enum order (`ActivityType.values` / `ALL_ACTIVITY_TYPES`), never by user click order — two identical selections must be `==` so Riverpod families and React deps don't refetch spuriously.
- When **every** type is selected, emit **no** type constraint (equivalent result, and it avoids needing the composite index).
- Never fetch from `initState` or during `build` — search is triggered from button callbacks only.
- Mobile: `flutter test` and `flutter analyze` must pass. Web (from `web_admin/`): `npm run typecheck`, `npm run test`, `npm run build` must pass.
- Do not deploy the Firestore index, hosting, or an APK as part of implementation. Those are the user's call.

## File Structure

**Mobile**

| File | Responsibility |
|---|---|
| `lib/domain/repositories/activity_log_repository.dart` | Modify — trim to `logActivity` + multi-type `getActivityLogs` |
| `lib/data/repositories/activity_log_repository_impl.dart` | Modify — same trim, `whereIn` + date bounds |
| `lib/presentation/providers/activity_log_provider.dart` | Modify — `ActivityLogParams.types`, single surviving provider |
| `lib/presentation/providers/session_reset_provider.dart` | Modify — drop three invalidates |
| `lib/presentation/mobile/widgets/logs/activity_log_filter_card.dart` | **Create** — filter panel + summary formatter |
| `lib/presentation/mobile/screens/logs/activity_logs_screen.dart` | Modify — search-gated state + results |

**Web**

| File | Responsibility |
|---|---|
| `web_admin/src/domain/entities/ActivityLog.ts` | Modify — add `dayClosed`, export `ALL_ACTIVITY_TYPES` |
| `web_admin/src/domain/repositories/ActivityLogRepository.ts` | Modify — `types[]`, drop `watch` |
| `web_admin/src/data/repositories/FirestoreActivityLogRepository.ts` | Modify — `in` constraint, drop `watch` |
| `web_admin/src/presentation/hooks/useActivityLogs.ts` | **Delete** |
| `web_admin/src/presentation/hooks/useActivityLogSearch.ts` | **Create** — on-demand one-shot read |
| `web_admin/src/presentation/components/common/DateRangePicker.tsx` | Modify — optional `defaultPreset` |
| `web_admin/src/presentation/features/logs/ActivityLogFilterBar.tsx` | **Create** — operations + range + time + Search |
| `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx` | Modify — search-gated |

**Shared:** `firestore.indexes.json` — add the `user_logs` composite index.

---

### Task 1: Firestore composite index for `user_logs`

The operations filter combined with a `createdAt` range needs `type ASC, createdAt DESC`. `firestore.indexes.json` has no `user_logs` entry today.

**Files:**
- Modify: `firestore.indexes.json`

**Interfaces:**
- Consumes: nothing.
- Produces: the index the multi-type + date-range query needs at runtime. Not deployed by this plan.

- [ ] **Step 1: Add the index entry**

Insert this object into the `"indexes"` array (order within the array does not matter; put it after the `price_history` entry to keep the diff small):

```json
    {
      "collectionGroup": "user_logs",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "type",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
```

- [ ] **Step 2: Verify the file is still valid JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('firestore.indexes.json','utf8')); console.log('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add firestore.indexes.json
git commit -m "chore(firestore): add user_logs type+createdAt composite index"
```

---

### Task 2: Mobile — remove the dead log providers and repository methods

Verified unreferenced: `securityLogsProvider`, `userActivityLogsProvider`, `entityLogsProvider` are touched only by `session_reset_provider.dart`; their backing repository methods are called only by those providers. `deleteOldLogs` has no caller at all and cannot work — `firestore.rules:273` sets `allow update, delete: if false` on `user_logs`.

This task leaves the screen untouched and compiling: it still uses `activityLogsStreamProvider`, which survives until Task 4.

**Files:**
- Modify: `lib/presentation/providers/activity_log_provider.dart:73-99`
- Modify: `lib/presentation/providers/session_reset_provider.dart:22-24`
- Modify: `lib/domain/repositories/activity_log_repository.dart:26-50`
- Modify: `lib/data/repositories/activity_log_repository_impl.dart:112-207`

**Interfaces:**
- Consumes: nothing.
- Produces: an `ActivityLogRepository` reduced to `logActivity`, `getActivityLogs`, `watchActivityLogs`.

- [ ] **Step 1: Run the suite to capture a green baseline**

Run: `flutter test`
Expected: PASS. Note the test count — Task 2 must not change it except where stated.

- [ ] **Step 2: Delete the three providers**

In `lib/presentation/providers/activity_log_provider.dart`, delete `securityLogsProvider`, `userActivityLogsProvider`, and `entityLogsProvider` entirely (everything from the `/// Provides recent security logs.` comment to the end of the file). The file then ends after `activityLogsStreamProvider`.

- [ ] **Step 3: Drop the three invalidate lines**

In `lib/presentation/providers/session_reset_provider.dart`, delete these three lines (currently 22-24):

```dart
      ref.invalidate(securityLogsProvider);
      ref.invalidate(userActivityLogsProvider);
      ref.invalidate(entityLogsProvider);
```

Then delete the now-unused import:

```dart
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
```

Leave every other reset in that listener alone.

- [ ] **Step 4: Delete the four repository methods from the interface**

In `lib/domain/repositories/activity_log_repository.dart`, delete the `getEntityLogs`, `getSecurityLogs`, `getUserLogs`, and `deleteOldLogs` declarations. Also delete the now-unused `entityId` and `entityType` parameters from `getActivityLogs` — nothing passes them once `getEntityLogs` is gone. The interface becomes:

```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for ActivityLog operations.
abstract class ActivityLogRepository {
  /// Logs an activity.
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log);

  /// Gets activity logs with optional filters.
  Future<List<ActivityLogEntity>> getActivityLogs({
    ActivityType? type,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  /// Streams activity logs for real-time updates.
  Stream<List<ActivityLogEntity>> watchActivityLogs({
    ActivityType? type,
    String? userId,
    int limit = 50,
  });
}
```

- [ ] **Step 5: Delete the same four methods from the implementation**

In `lib/data/repositories/activity_log_repository_impl.dart`, delete `getEntityLogs`, `getSecurityLogs`, `getUserLogs`, and `deleteOldLogs`, plus the `entityId`/`entityType` parameters and their two `if` blocks inside `getActivityLogs`. The file keeps `logActivity`, `getActivityLogs`, `watchActivityLogs`.

- [ ] **Step 6: Verify nothing still references the removed symbols**

Run:

```bash
grep -rn "securityLogsProvider\|userActivityLogsProvider\|entityLogsProvider\|getSecurityLogs\|getUserLogs\|getEntityLogs\|deleteOldLogs" --include="*.dart" lib test integration_test
```

Expected: no output.

- [ ] **Step 7: Analyze and test**

Run: `flutter analyze && flutter test`
Expected: analyze clean, tests PASS at the same count as Step 1.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/repositories/activity_log_repository.dart lib/data/repositories/activity_log_repository_impl.dart lib/presentation/providers/activity_log_provider.dart lib/presentation/providers/session_reset_provider.dart
git commit -m "refactor(logs): drop unused activity-log providers and repository methods"
```

---

### Task 3: Mobile — filter card widget and summary formatter

A new widget owning no state (the screen owns it), plus a pure summary function that is unit-testable without pumping a widget.

**Files:**
- Create: `lib/presentation/mobile/widgets/logs/activity_log_filter_card.dart`
- Test: `test/presentation/mobile/widgets/logs/activity_log_filter_card_test.dart`

**Interfaces:**
- Consumes: `DateRangePicker` and `DateRangePreset` from `lib/presentation/mobile/widgets/reports/date_range_picker.dart`; `AppCard` from `lib/presentation/shared/widgets/common/common_widgets.dart`.
- Produces:
  - `String activityFilterSummary({required DateTime start, required DateTime end, required int typeCount, DateTime? now})`
  - `class ActivityLogFilterCard extends StatelessWidget` with named params `expanded`, `selectedTypes`, `preset`, `startDate`, `endDate`, `startTime`, `endTime`, `dirty`, `onToggleExpanded`, `onTypesChanged`, `onPresetChanged`, `onCustomRangeSelected`, `onStartTimeChanged`, `onEndTimeChanged`, `onSearch`.

- [ ] **Step 1: Write the failing tests**

Create `test/presentation/mobile/widgets/logs/activity_log_filter_card_test.dart`:

```dart
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
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ActivityLogFilterCard(
            expanded: expanded,
            selectedTypes: selected,
            preset: DateRangePreset.today,
            startDate: DateTime(2026, 7, 28),
            endDate: DateTime(2026, 7, 28),
            startTime: const TimeOfDay(hour: 0, minute: 0),
            endTime: const TimeOfDay(hour: 23, minute: 59),
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
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/logs/activity_log_filter_card_test.dart`
Expected: FAIL — `activity_log_filter_card.dart` does not exist (compile error / URI does not exist).

- [ ] **Step 3: Write the widget**

Create `lib/presentation/mobile/widgets/logs/activity_log_filter_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

final _timeFmt = DateFormat('h:mm a');
final _dayFmt = DateFormat('MMM d');

/// One-line description of the active filters, shown when the card is
/// collapsed. The time span is omitted when the window covers whole days,
/// which is the common case and would otherwise be noise.
String activityFilterSummary({
  required DateTime start,
  required DateTime end,
  required int typeCount,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  String datePart;
  if (sameDay) {
    final yesterday = today.subtract(const Duration(days: 1));
    if (start.year == today.year &&
        start.month == today.month &&
        start.day == today.day) {
      datePart = 'Today';
    } else if (start.year == yesterday.year &&
        start.month == yesterday.month &&
        start.day == yesterday.day) {
      datePart = 'Yesterday';
    } else {
      datePart = _dayFmt.format(start);
    }
  } else {
    datePart = '${_dayFmt.format(start)} – ${_dayFmt.format(end)}';
  }

  final wholeDays = start.hour == 0 &&
      start.minute == 0 &&
      end.hour == 23 &&
      end.minute == 59;
  final timePart =
      wholeDays ? null : '${_timeFmt.format(start)}–${_timeFmt.format(end)}';

  final opsPart = typeCount == 0
      ? 'All operations'
      : typeCount == 1
          ? '1 operation'
          : '$typeCount operations';

  return [datePart, if (timePart != null) timePart, opsPart].join(' · ');
}

/// Filter panel for the activity-log screen. Holds no state — the screen owns
/// every value and every change is reported through a callback.
class ActivityLogFilterCard extends StatelessWidget {
  const ActivityLogFilterCard({
    super.key,
    required this.expanded,
    required this.selectedTypes,
    required this.preset,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.dirty,
    required this.onToggleExpanded,
    required this.onTypesChanged,
    required this.onPresetChanged,
    required this.onCustomRangeSelected,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onSearch,
  });

  final bool expanded;
  final List<ActivityType> selectedTypes;
  final DateRangePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool dirty;
  final VoidCallback onToggleExpanded;
  final ValueChanged<List<ActivityType>> onTypesChanged;
  final ValueChanged<DateRangePreset> onPresetChanged;
  final void Function(DateTime start, DateTime end) onCustomRangeSelected;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final VoidCallback onSearch;

  bool get _rangeValid {
    final s = _at(startDate, startTime);
    final e = _at(endDate, endTime);
    return !s.isAfter(e);
  }

  static DateTime _at(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline(isDark))),
      ),
      child: expanded ? _expandedView(context) : _collapsedView(context),
    );
  }

  Widget _collapsedView(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggleExpanded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(LucideIcons.slidersHorizontal,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                activityFilterSummary(
                  start: _at(startDate, startTime),
                  end: _at(endDate, endTime),
                  typeCount: selectedTypes.length,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _expandedView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The operations list is two dozen chips. Capping and scrolling the
        // control area keeps the card from crowding the results off a short
        // phone, and keeps Search pinned and always tappable below it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangePicker(
                  startDate: startDate,
                  endDate: endDate,
                  selectedPreset: preset,
                  onPresetChanged: onPresetChanged,
                  onCustomRangeSelected: onCustomRangeSelected,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimePill(
                          label: 'From',
                          value: startTime,
                          onChanged: onStartTimeChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TimePill(
                          label: 'To',
                          value: endTime,
                          onChanged: onEndTimeChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _OperationsPicker(
                    selected: selectedTypes,
                    onChanged: onTypesChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (dirty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Filters changed — tap Search.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!_rangeValid)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Start must be before end.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rangeValid ? onSearch : null,
              child: const Text('Search'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tap-to-pick time pill. Uses the platform time picker.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.md,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          final picked =
              await showTimePicker(context: context, initialTime: value);
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                value.format(context),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select over every activity type. Selection is always rebuilt in
/// canonical enum order so two identical selections compare equal.
class _OperationsPicker extends StatelessWidget {
  const _OperationsPicker({required this.selected, required this.onChanged});

  final List<ActivityType> selected;
  final ValueChanged<List<ActivityType>> onChanged;

  void _toggle(ActivityType type) {
    final next = selected.contains(type)
        ? selected.where((t) => t != type).toSet()
        : {...selected, type};
    onChanged(
      ActivityType.values.where(next.contains).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'OPERATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(const []),
                child: const Text('All'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ActivityType.values)
              FilterChip(
                label: Text(type.displayName),
                selected: selected.contains(type),
                onSelected: (_) => _toggle(type),
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/presentation/mobile/widgets/logs/activity_log_filter_card_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/logs/activity_log_filter_card.dart test/presentation/mobile/widgets/logs/activity_log_filter_card_test.dart
git commit -m "feat(logs): add activity-log filter card widget"
```

---

### Task 4: Mobile — multi-type query and search-gated screen

Atomic: the params type, the repository signature, the provider, and the screen all flip together. Splitting them would leave the tree uncompilable between commits.

**Files:**
- Modify: `lib/domain/repositories/activity_log_repository.dart`
- Modify: `lib/data/repositories/activity_log_repository_impl.dart`
- Modify: `lib/presentation/providers/activity_log_provider.dart`
- Modify: `lib/presentation/mobile/screens/logs/activity_logs_screen.dart`
- Test: `test/data/repositories/activity_log_repository_query_test.dart`
- Test: `test/presentation/providers/activity_log_params_test.dart`
- Test: `test/presentation/mobile/screens/logs/activity_logs_screen_test.dart`

**Interfaces:**
- Consumes: `ActivityLogFilterCard` and `activityFilterSummary` from Task 3; `dateRangeForPreset` from `lib/core/utils/report_date_range.dart`.
- Produces:
  - `const int kActivityLogSearchLimit = 500;` (in `activity_log_provider.dart`)
  - `ActivityLogParams({List<ActivityType> types = const [], DateTime? startDate, DateTime? endDate, int limit = kActivityLogSearchLimit})`
  - `Future<List<ActivityLogEntity>> getActivityLogs({List<ActivityType> types = const [], DateTime? startDate, DateTime? endDate, int limit = 50})`
  - `activityLogsProvider` — `FutureProvider.autoDispose.family<List<ActivityLogEntity>, ActivityLogParams>`

- [ ] **Step 1: Write the failing repository test**

Create `test/data/repositories/activity_log_repository_query_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/activity_log_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  Future<FakeFirebaseFirestore> seeded() async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String id, ActivityType type, DateTime at) =>
        db.collection('user_logs').doc(id).set({
          'type': type.value,
          'action': id,
          'userId': 'u1',
          'userName': 'Tester',
          'userRole': 'admin',
          'createdAt': Timestamp.fromDate(at),
        });

    await add('sale-early', ActivityType.sale, DateTime(2026, 7, 28, 8, 30));
    await add('void-mid', ActivityType.voidSale, DateTime(2026, 7, 28, 12, 0));
    await add('login-late', ActivityType.login, DateTime(2026, 7, 28, 20, 0));
    await add('sale-other-day', ActivityType.sale, DateTime(2026, 7, 27, 9, 0));
    return db;
  }

  test('no types selected returns everything in the window', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.map((l) => l.action),
        containsAll(<String>['sale-early', 'void-mid', 'login-late']));
    expect(logs.map((l) => l.action), isNot(contains('sale-other-day')));
  });

  test('selected types restrict the result', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      types: const [ActivityType.sale, ActivityType.voidSale],
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.map((l) => l.action).toSet(), {'sale-early', 'void-mid'});
  });

  test('the time window excludes records outside it', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 28, 9, 0),
      endDate: DateTime(2026, 7, 28, 17, 0, 59, 999),
    );

    expect(logs.map((l) => l.action).toSet(), {'void-mid'});
  });

  test('selecting every type behaves like no filter', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      types: ActivityType.values,
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.length, 3);
  });

  test('results come back newest first', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.first.action, 'login-late');
    expect(logs.last.action, 'sale-other-day');
  });
}
```

- [ ] **Step 2: Write the failing params test**

Create `test/presentation/providers/activity_log_params_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';

void main() {
  test('two identical selections compare equal and hash alike', () {
    final a = ActivityLogParams(
      types: const [ActivityType.sale, ActivityType.login],
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );
    final b = ActivityLogParams(
      types: const [ActivityType.sale, ActivityType.login],
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a different type selection is not equal', () {
    const a = ActivityLogParams(types: [ActivityType.sale]);
    const b = ActivityLogParams(types: [ActivityType.login]);

    expect(a, isNot(b));
  });

  test('a different window is not equal', () {
    final a = ActivityLogParams(startDate: DateTime(2026, 7, 28));
    final b = ActivityLogParams(startDate: DateTime(2026, 7, 27));

    expect(a, isNot(b));
  });

  test('the default limit is the search cap', () {
    const params = ActivityLogParams();
    expect(params.limit, kActivityLogSearchLimit);
    expect(kActivityLogSearchLimit, 500);
  });
}
```

- [ ] **Step 3: Write the failing screen test**

Create `test/presentation/mobile/screens/logs/activity_logs_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/logs/activity_logs_screen.dart';
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
```

- [ ] **Step 4: Run all three to verify they fail**

Run:

```bash
flutter test test/data/repositories/activity_log_repository_query_test.dart test/presentation/providers/activity_log_params_test.dart test/presentation/mobile/screens/logs/activity_logs_screen_test.dart
```

Expected: FAIL — `getActivityLogs` has no `types` parameter, `kActivityLogSearchLimit` is undefined.

- [ ] **Step 5: Update the repository interface**

In `lib/domain/repositories/activity_log_repository.dart`, replace `getActivityLogs` and delete `watchActivityLogs` (its only caller disappears in Step 7):

```dart
  /// Gets activity logs. An empty [types] means "every operation".
  Future<List<ActivityLogEntity>> getActivityLogs({
    List<ActivityType> types = const [],
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });
```

- [ ] **Step 6: Update the repository implementation**

In `lib/data/repositories/activity_log_repository_impl.dart`, replace `getActivityLogs` and delete `watchActivityLogs`:

```dart
  @override
  Future<List<ActivityLogEntity>> getActivityLogs({
    List<ActivityType> types = const [],
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _logsRef;

      // Selecting every type is the same as selecting none, and skipping the
      // constraint keeps the query off the composite index.
      if (types.isNotEmpty && types.length < ActivityType.values.length) {
        query = query.where('type',
            whereIn: types.map((t) => t.value).toList(growable: false));
      }

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ActivityLogModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get activity logs: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] **Step 7: Rewrite the provider file**

Replace the whole of `lib/presentation/providers/activity_log_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Ceiling on a single activity-log search. Hitting it means the range was
/// too wide, and the screen says so rather than silently truncating.
const int kActivityLogSearchLimit = 500;

/// The filters an admin submitted with the Search button. An empty [types]
/// means "every operation".
class ActivityLogParams {
  final List<ActivityType> types;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const ActivityLogParams({
    this.types = const [],
    this.startDate,
    this.endDate,
    this.limit = kActivityLogSearchLimit,
  });

  // Riverpod keys families by ==; a plain list field would compare by
  // identity and refetch on every rebuild.
  static bool _sameTypes(List<ActivityType> a, List<ActivityType> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityLogParams &&
        _sameTypes(other.types, types) &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(types), startDate, endDate, limit);
}

/// One-shot activity-log search. Nothing subscribes to this until the screen
/// has submitted params, so opening the screen issues no read.
final activityLogsProvider = FutureProvider.autoDispose
    .family<List<ActivityLogEntity>, ActivityLogParams>((ref, params) async {
  final repository = ref.watch(activityLogRepositoryProvider);
  return repository.getActivityLogs(
    types: params.types,
    startDate: params.startDate,
    endDate: params.endDate,
    limit: params.limit,
  );
});
```

- [ ] **Step 8: Rewrite the screen**

Replace `lib/presentation/mobile/screens/logs/activity_logs_screen.dart` lines 1-311 (the `_ActivityLogsScreenState` class and its imports) so the state and body read as below. Keep `_groupLogsByDate`, `_buildDateGroup`, `_isToday`, `_isYesterday` and the trailing `_FilterChip` class **only** if still referenced — `_FilterChip` and `_buildActiveFilter` and `_getCommonActivityTypes` are now dead and must be deleted.

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_filter_card.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_row.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying activity logs for audit trail. Nothing is read from
/// Firestore until the admin submits filters with the Search button.
class ActivityLogsScreen extends ConsumerStatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  ConsumerState<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends ConsumerState<ActivityLogsScreen> {
  List<ActivityType> _selectedTypes = const [];
  DateRangePreset _preset = DateRangePreset.today;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  bool _expanded = true;
  bool _dirty = false;

  /// Null until Search is pressed. While null the screen watches no provider,
  /// which is what keeps the screen from fetching on open.
  ActivityLogParams? _submitted;

  @override
  void initState() {
    super.initState();
    // Plain local state from a pure helper — no provider is read or written
    // here, which would trip Riverpod's modify-during-build assertion.
    final range = dateRangeForPreset(DateRangePreset.today, DateTime.now());
    _startDate = range.start;
    _endDate = range.end;
  }

  void _markDirty() {
    if (_submitted != null && !_dirty) _dirty = true;
  }

  ActivityLogParams _buildParams() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute);
    // Seconds are pushed to the end of the chosen minute so the bound is
    // genuinely inclusive of everything logged in that minute.
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day,
        _endTime.hour, _endTime.minute, 59, 999);
    return ActivityLogParams(
      types: _selectedTypes,
      startDate: start,
      endDate: end,
      limit: kActivityLogSearchLimit,
    );
  }

  void _onSearch() {
    setState(() {
      _submitted = _buildParams();
      _expanded = false;
      _dirty = false;
    });
  }

  void _onRefresh() {
    final params = _submitted;
    if (params != null) ref.invalidate(activityLogsProvider(params));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final params = _submitted;
    final logsAsync =
        params == null ? null : ref.watch(activityLogsProvider(params));
    final hasError = logsAsync?.hasError ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Activity Logs'),
        actions: [
          if (params != null)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: _onRefresh,
            ),
        ],
      ),
      body: Column(
        children: [
          ActivityLogFilterCard(
            // A failed search leaves the card open so the filters can be
            // corrected without an extra tap.
            expanded: _expanded || hasError,
            selectedTypes: _selectedTypes,
            preset: _preset,
            startDate: _startDate,
            endDate: _endDate,
            startTime: _startTime,
            endTime: _endTime,
            dirty: _dirty,
            onToggleExpanded: () => setState(() => _expanded = !_expanded),
            onTypesChanged: (types) => setState(() {
              _selectedTypes = types;
              _markDirty();
            }),
            onPresetChanged: (preset) => setState(() {
              _preset = preset;
              final range = dateRangeForPreset(preset, DateTime.now());
              _startDate = range.start;
              _endDate = range.end;
              _markDirty();
            }),
            onCustomRangeSelected: (start, end) => setState(() {
              _preset = DateRangePreset.custom;
              _startDate = start;
              _endDate = end;
              _markDirty();
            }),
            onStartTimeChanged: (t) => setState(() {
              _startTime = t;
              _markDirty();
            }),
            onEndTimeChanged: (t) => setState(() {
              _endTime = t;
              _markDirty();
            }),
            onSearch: _onSearch,
          ),
          Expanded(
            child: logsAsync == null
                ? _buildPreSearchState()
                : logsAsync.when(
                    data: (logs) => _buildLogsList(logs, isDark),
                    loading: () => const ListSkeleton(),
                    error: (error, _) => ErrorStateView(
                      message: 'Error: $error',
                      onRetry: _onRefresh,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreSearchState() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 30, 44, 90),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.search, size: 34, color: muted),
            const SizedBox(height: 16),
            Text(
              'Pick your filters and tap Search.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the operations and the date and time range you want to '
              'review, then tap Search.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(height: 1.45, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(List<ActivityLogEntity> logs, bool isDark) {
    if (logs.isEmpty) return _buildEmptyState(isDark);

    final groupedLogs = _groupLogsByDate(logs);
    final capped = logs.length >= kActivityLogSearchLimit;

    return Column(
      children: [
        if (capped) _buildCapNotice(),
        Expanded(
          child: ListView.builder(
            itemCount: groupedLogs.length,
            padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.md),
            itemBuilder: (context, index) {
              final dateGroup = groupedLogs.entries.elementAt(index);
              return _buildDateGroup(dateGroup.key, dateGroup.value, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCapNotice() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(
        'Showing the newest $kActivityLogSearchLimit — narrow your range.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 30, 44, 90),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0x0DFFFFFF)
                    : AppColors.brandSlate.withValues(alpha: 0.06),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.clock, size: 34, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              'No activity matched these filters',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a wider date range, or fewer operations.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(height: 1.45, color: muted),
            ),
          ],
        ),
      ),
    );
  }
```

Keep the existing `_groupLogsByDate`, `_buildDateGroup`, `_isToday` and `_isYesterday` methods exactly as they are, then close the class. Delete `_buildActiveFilter`, `_getCommonActivityTypes`, and the entire trailing `_FilterChip` class.

- [ ] **Step 9: Run the three test files**

Run:

```bash
flutter test test/data/repositories/activity_log_repository_query_test.dart test/presentation/providers/activity_log_params_test.dart test/presentation/mobile/screens/logs/activity_logs_screen_test.dart
```

Expected: PASS.

- [ ] **Step 10: Run the whole mobile suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: analyze clean, all tests PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/domain/repositories/activity_log_repository.dart lib/data/repositories/activity_log_repository_impl.dart lib/presentation/providers/activity_log_provider.dart lib/presentation/mobile/screens/logs/activity_logs_screen.dart test/data/repositories/activity_log_repository_query_test.dart test/presentation/providers/activity_log_params_test.dart test/presentation/mobile/screens/logs/activity_logs_screen_test.dart
git commit -m "feat(logs): gate mobile activity logs behind filter-then-Search"
```

---

### Task 5: Web — add the missing `day_closed` activity type

The Dart enum has `dayClosed('day_closed', 'Day Closed', ...)` at `lib/domain/entities/activity_log_entity.dart:168`; the web mirror does not, so day-close entries currently render as "Other" and cannot be filtered for. This feature is "filter by operation", so the list must be complete.

**Files:**
- Modify: `web_admin/src/domain/entities/ActivityLog.ts`
- Modify: `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx:48-119`
- Test: `web_admin/src/domain/entities/ActivityLog.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `ActivityType.dayClosed === 'day_closed'`; `export const ALL_ACTIVITY_TYPES: ActivityType[]`.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/entities/ActivityLog.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import {
  ALL_ACTIVITY_TYPES,
  ActivityType,
  activityTypeDisplayName,
  activityTypeFromString,
} from './ActivityLog';

describe('ActivityType', () => {
  it('mirrors the Dart enum value for a closed business day', () => {
    expect(ActivityType.dayClosed).toBe('day_closed');
    expect(activityTypeFromString('day_closed')).toBe(ActivityType.dayClosed);
  });

  it('gives every type a display name', () => {
    for (const t of ALL_ACTIVITY_TYPES) {
      expect(activityTypeDisplayName[t], `missing name for ${t}`).toBeTruthy();
    }
  });

  it('lists every enum value in ALL_ACTIVITY_TYPES', () => {
    expect(new Set(ALL_ACTIVITY_TYPES)).toEqual(new Set(Object.values(ActivityType)));
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `web_admin/`): `npm run test -- ActivityLog.test`
Expected: FAIL — `ActivityType.dayClosed` is undefined and `ALL_ACTIVITY_TYPES` is not exported.

- [ ] **Step 3: Add the type**

In `web_admin/src/domain/entities/ActivityLog.ts`, add to the `ActivityType` object immediately after `supplier: 'supplier',`:

```ts
  dayClosed: 'day_closed',
```

Add to `activityTypeDisplayName` immediately after `supplier: 'Supplier',`:

```ts
  day_closed: 'Day Closed',
```

Append after the `activityTypeDisplayName` declaration:

```ts
/** Canonical order for filter lists — mirrors the Dart enum's declaration order. */
export const ALL_ACTIVITY_TYPES: ActivityType[] = Object.values(ActivityType);
```

- [ ] **Step 4: Give it an icon and a tone**

In `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx`, add `BookOpenIcon` to the `@heroicons/react/24/outline` import list (alphabetically, after `ArrowUturnLeftIcon`), add to the `ICONS` record after `supplier: BuildingStorefrontIcon,`:

```ts
  day_closed: BookOpenIcon,
```

and add to `toneFor`, before the `default:` arm:

```ts
    case ActivityType.dayClosed:
      return 'orange';
```

- [ ] **Step 5: Run the test and typecheck**

Run (from `web_admin/`): `npm run test -- ActivityLog.test && npm run typecheck`
Expected: PASS, typecheck clean. `ICONS` is `Record<ActivityType, …>`, so a missing entry would have failed typecheck — that is the intended safety net.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/domain/entities/ActivityLog.ts web_admin/src/domain/entities/ActivityLog.test.ts web_admin/src/presentation/features/logs/ActivityLogsPage.tsx
git commit -m "fix(web): mirror the day_closed activity type from the Dart enum"
```

---

### Task 6: Web — filter bar component

**Files:**
- Create: `web_admin/src/presentation/features/logs/ActivityLogFilterBar.tsx`
- Modify: `web_admin/src/presentation/components/common/DateRangePicker.tsx:26-33`
- Test: `web_admin/src/presentation/features/logs/ActivityLogFilterBar.test.tsx`

**Interfaces:**
- Consumes: `ALL_ACTIVITY_TYPES`, `activityTypeDisplayName` from Task 5; `DateRangePicker`, `DateRange`, `resolvePreset` from `@/domain/reports/dateRange`.
- Produces:
  - `DateRangePicker` gains optional `defaultPreset?: Exclude<RangePreset, 'custom'>` (default `'last7'` — unchanged for its six existing callers).
  - `export function ActivityLogFilterBar(props: { types: ActivityType[]; onTypes: (next: ActivityType[]) => void; onRange: (next: DateRange) => void; startTime: string; endTime: string; onStartTime: (v: string) => void; onEndTime: (v: string) => void; dirty: boolean; disabled: boolean; onSearch: () => void })`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/presentation/features/logs/ActivityLogFilterBar.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ActivityLogFilterBar } from './ActivityLogFilterBar';
import { ActivityType } from '@/domain/entities';

function harness(overrides: Partial<Parameters<typeof ActivityLogFilterBar>[0]> = {}) {
  const props = {
    types: [] as ActivityType[],
    onTypes: vi.fn(),
    onRange: vi.fn(),
    startTime: '00:00',
    endTime: '23:59',
    onStartTime: vi.fn(),
    onEndTime: vi.fn(),
    dirty: false,
    disabled: false,
    onSearch: vi.fn(),
    ...overrides,
  };
  render(<ActivityLogFilterBar {...props} />);
  return props;
}

describe('ActivityLogFilterBar', () => {
  it('summarises an empty selection as all operations', () => {
    harness();
    expect(screen.getByRole('button', { name: /All operations/ })).toBeInTheDocument();
  });

  it('reports a ticked operation in canonical enum order', async () => {
    const props = harness({ types: [ActivityType.login] });
    await userEvent.click(screen.getByRole('button', { name: /1 operation/ }));
    await userEvent.click(screen.getByLabelText('Sale'));

    // 'login' is declared before 'sale' in the enum, so order is preserved
    // regardless of click order.
    expect(props.onTypes).toHaveBeenCalledWith([ActivityType.login, ActivityType.sale]);
  });

  it('fires onSearch when Search is clicked', async () => {
    const props = harness();
    await userEvent.click(screen.getByRole('button', { name: 'Search' }));
    expect(props.onSearch).toHaveBeenCalledTimes(1);
  });

  it('disables Search when the range is invalid', () => {
    harness({ disabled: true });
    expect(screen.getByRole('button', { name: 'Search' })).toBeDisabled();
  });

  it('shows the stale hint when dirty', () => {
    harness({ dirty: true });
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `web_admin/`): `npm run test -- ActivityLogFilterBar`
Expected: FAIL — module not found.

- [ ] **Step 3: Add `defaultPreset` to DateRangePicker**

In `web_admin/src/presentation/components/common/DateRangePicker.tsx`, change the signature and initial state:

```tsx
export function DateRangePicker({
  onChange,
  defaultPreset = 'last7',
}: {
  onChange: (range: DateRange) => void;
  defaultPreset?: Exclude<RangePreset, 'custom'>;
}) {
  const [preset, setPreset] = useState<RangePreset>(defaultPreset);
```

Update the doc comment's last sentence to: `default preset is 'last7' unless overridden with defaultPreset, and must match the parent's initial.`

- [ ] **Step 4: Write the component**

Create `web_admin/src/presentation/features/logs/ActivityLogFilterBar.tsx`:

```tsx
// Filter controls for /admin/logs. Owns only its dropdown's open/closed
// state — every filter value lives in the page so Search can snapshot them.

import { useState } from 'react';
import { ChevronDownIcon, FunnelIcon } from '@heroicons/react/24/outline';
import {
  ALL_ACTIVITY_TYPES,
  activityTypeDisplayName,
  type ActivityType,
} from '@/domain/entities';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import type { DateRange } from '@/domain/reports/dateRange';
import { cn } from '@/core/utils/cn';

const inputCls =
  'rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text';

export function ActivityLogFilterBar({
  types,
  onTypes,
  onRange,
  startTime,
  endTime,
  onStartTime,
  onEndTime,
  dirty,
  disabled,
  onSearch,
}: {
  types: ActivityType[];
  onTypes: (next: ActivityType[]) => void;
  onRange: (next: DateRange) => void;
  startTime: string;
  endTime: string;
  onStartTime: (v: string) => void;
  onEndTime: (v: string) => void;
  dirty: boolean;
  disabled: boolean;
  onSearch: () => void;
}) {
  const [open, setOpen] = useState(false);

  // Rebuilt in enum order, never click order, so an identical selection is
  // always the same array shape.
  function toggle(t: ActivityType) {
    const next = new Set(types);
    if (next.has(t)) next.delete(t);
    else next.add(t);
    onTypes(ALL_ACTIVITY_TYPES.filter((x) => next.has(x)));
  }

  const label =
    types.length === 0
      ? 'All operations'
      : types.length === 1
        ? '1 operation'
        : `${types.length} operations`;

  return (
    <div className="flex flex-wrap items-center gap-tk-sm">
      <div className="relative">
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="flex items-center gap-tk-xs rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          <FunnelIcon className="h-3.5 w-3.5" />
          {label}
          <ChevronDownIcon className="h-3.5 w-3.5" />
        </button>
        {open ? (
          <>
            <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
            <div className="absolute left-0 z-20 mt-tk-xs max-h-80 w-64 overflow-y-auto rounded-md border border-light-hairline bg-light-card p-tk-sm shadow-lg">
              <button
                type="button"
                onClick={() => onTypes([])}
                className="mb-tk-xs w-full rounded-md px-tk-sm py-tk-xs text-left text-bodySmall text-light-text-secondary hover:bg-light-subtle"
              >
                Clear — all operations
              </button>
              {ALL_ACTIVITY_TYPES.map((t) => (
                <label
                  key={t}
                  className="flex cursor-pointer items-center gap-tk-sm rounded-md px-tk-sm py-tk-xs text-bodySmall text-light-text hover:bg-light-subtle"
                >
                  <input
                    type="checkbox"
                    aria-label={activityTypeDisplayName[t]}
                    checked={types.includes(t)}
                    onChange={() => toggle(t)}
                  />
                  {activityTypeDisplayName[t]}
                </label>
              ))}
            </div>
          </>
        ) : null}
      </div>

      <DateRangePicker defaultPreset="today" onChange={onRange} />

      <input
        type="time"
        aria-label="Start time"
        className={inputCls}
        value={startTime}
        onChange={(e) => onStartTime(e.target.value)}
      />
      <span className="text-light-text-hint">–</span>
      <input
        type="time"
        aria-label="End time"
        className={inputCls}
        value={endTime}
        onChange={(e) => onEndTime(e.target.value)}
      />

      <button
        type="button"
        disabled={disabled}
        onClick={onSearch}
        className={cn(
          'rounded-md px-tk-lg py-tk-sm text-bodySmall font-semibold',
          disabled
            ? 'cursor-not-allowed bg-light-subtle text-light-text-hint'
            : 'bg-light-text text-light-background hover:opacity-90',
        )}
      >
        Search
      </button>

      {dirty ? (
        <span className="text-bodySmall text-light-text-secondary">
          Filters changed — tap Search.
        </span>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 5: Run the tests**

Run (from `web_admin/`): `npm run test -- ActivityLogFilterBar && npm run typecheck`
Expected: PASS, typecheck clean.

- [ ] **Step 6: Confirm the six other DateRangePicker callers still behave**

Run (from `web_admin/`): `npm run test`
Expected: PASS — `defaultPreset` is optional and defaults to the previous `'last7'`, so `ExpensesPage`, `ReceivingHistoryPage`, `PriceChangeReportPage`, `ProfitReportPage`, `SalesReportPage` and `LaborReportPage` are unaffected.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/features/logs/ActivityLogFilterBar.tsx web_admin/src/presentation/features/logs/ActivityLogFilterBar.test.tsx web_admin/src/presentation/components/common/DateRangePicker.tsx
git commit -m "feat(web): add activity-log filter bar with multi-select operations"
```

---

### Task 7: Web — search-gated page, on-demand hook, dead `watch` removal

Atomic for the same reason as Task 4: the query type, the repository, the hook and the page change together.

**Files:**
- Modify: `web_admin/src/domain/repositories/ActivityLogRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreActivityLogRepository.ts`
- Delete: `web_admin/src/presentation/hooks/useActivityLogs.ts`
- Create: `web_admin/src/presentation/hooks/useActivityLogSearch.ts`
- Modify: `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx`
- Test: `web_admin/src/presentation/features/logs/ActivityLogsPage.test.tsx` (rewrite)

**Interfaces:**
- Consumes: `ActivityLogFilterBar` from Task 6; `ALL_ACTIVITY_TYPES` from Task 5.
- Produces:
  - `ActivityLogQuery { types?: ActivityType[]; start?: Date; end?: Date; limit?: number }`
  - `ActivityLogRepository { list; log }` — no `watch`
  - `useActivityLogSearch(): { data: ActivityLog[] | null; error: Error | null; isLoading: boolean; run: (q: ActivityLogQuery) => Promise<void> }`
  - `export const ACTIVITY_LOG_SEARCH_LIMIT = 500` (in `useActivityLogSearch.ts`)

- [ ] **Step 1: Write the failing page test**

Replace `web_admin/src/presentation/features/logs/ActivityLogsPage.test.tsx` entirely:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ActivityLogsPage } from './ActivityLogsPage';
import { ActivityType, type ActivityLog } from '@/domain/entities';

const log = (o: Partial<ActivityLog> = {}): ActivityLog => ({
  id: 'l1',
  type: ActivityType.login,
  action: 'Signed in',
  details: null,
  userId: 'u1',
  userName: 'Tester',
  userRole: 'admin',
  entityId: null,
  entityType: null,
  metadata: null,
  deviceInfo: null,
  createdAt: new Date(2026, 6, 20, 9, 0),
  ...o,
});

// 15 logs on day 1 (July 20) and 15 on day 2 (July 21), newest first — 30
// total, spanning two date groups, so page 1 (first 25) covers all of day 2
// (15) plus 10 of day 1, and page 2 (last 5) covers the remaining 5 of day 1.
const logs: ActivityLog[] = [
  ...Array.from({ length: 15 }, (_, i) =>
    log({ id: `d2-${i + 1}`, action: `Day2 action ${i + 1}`, createdAt: new Date(2026, 6, 21, 9, i) }),
  ),
  ...Array.from({ length: 15 }, (_, i) =>
    log({ id: `d1-${i + 1}`, action: `Day1 action ${i + 1}`, createdAt: new Date(2026, 6, 20, 9, i) }),
  ),
];

// The stub ignores the query and always returns the fixture, so the date
// filter's real value doesn't matter to these assertions — only that a
// search was issued at all.
function harness(list: ActivityLog[] = logs) {
  const listFn = vi.fn(async () => list);
  const activityLogRepo = { list: listFn } as unknown as Container['activityLogRepo'];
  const utils = render(
    <DiProvider override={{ activityLogRepo }}>
      <ActivityLogsPage />
    </DiProvider>,
  );
  return { ...utils, listFn };
}

async function search() {
  await userEvent.click(screen.getByRole('button', { name: 'Search' }));
}

describe('ActivityLogsPage search gating', () => {
  it('fetches nothing on mount', () => {
    const { listFn } = harness();
    expect(listFn).not.toHaveBeenCalled();
    expect(screen.getByText('Pick your filters and tap Search.')).toBeInTheDocument();
  });

  it('fetches exactly once when Search is clicked', async () => {
    const { listFn } = harness();
    await search();
    expect(listFn).toHaveBeenCalledTimes(1);
    expect(screen.getByText('Day2 action 1')).toBeInTheDocument();
  });

  it('sends the search cap and a date window', async () => {
    const { listFn } = harness();
    await search();
    const query = listFn.mock.calls[0][0];
    expect(query.limit).toBe(500);
    expect(query.start).toBeInstanceOf(Date);
    expect(query.end).toBeInstanceOf(Date);
    expect(query.start.getTime()).toBeLessThanOrEqual(query.end.getTime());
  });

  it('does not refetch when a filter changes after a search', async () => {
    const { listFn } = harness();
    await search();
    await userEvent.click(screen.getByLabelText('End time'));
    await userEvent.clear(screen.getByLabelText('End time'));
    await userEvent.type(screen.getByLabelText('End time'), '17:00');

    expect(listFn).toHaveBeenCalledTimes(1);
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });

  it('shows the no-match message for an empty result', async () => {
    harness([]);
    await search();
    expect(screen.getByText('No activity matched these filters')).toBeInTheDocument();
  });

  it('warns when the result hits the cap', async () => {
    harness(Array.from({ length: 500 }, (_, i) => log({ id: `c${i}`, action: `Capped ${i}` })));
    await search();
    expect(
      screen.getByText('Showing the newest 500 — narrow your range.'),
    ).toBeInTheDocument();
  });
});

describe('ActivityLogsPage pagination', () => {
  it('groups only its own 25 rows on page 1, leaving the rest for page 2', async () => {
    harness();
    await search();

    expect(screen.getByText('Day2 action 1')).toBeInTheDocument();
    expect(screen.getByText('Day1 action 10')).toBeInTheDocument();
    expect(screen.queryByText('Day1 action 11')).not.toBeInTheDocument();
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();
  });

  it('shows the remaining rows on page 2', async () => {
    harness();
    await search();
    await userEvent.click(screen.getByRole('button', { name: /next/i }));

    expect(screen.getByText('Day1 action 11')).toBeInTheDocument();
    expect(screen.queryByText('Day2 action 1')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `web_admin/`): `npm run test -- ActivityLogsPage`
Expected: FAIL — the page still calls `watch`, so `list` is never invoked and the placeholder text does not exist.

- [ ] **Step 3: Update the repository contract**

Replace `web_admin/src/domain/repositories/ActivityLogRepository.ts`:

```ts
// Mirror of lib/domain/repositories/activity_log_repository.dart's read
// surface. Reads are one-shot: /admin/logs fetches only when the admin
// submits filters, so there is no live-subscription method here.

import type { ActivityLog, ActivityType } from '../entities';

export interface ActivityLogQuery {
  /** Empty or omitted means "every operation". */
  types?: ActivityType[];
  start?: Date;
  end?: Date;
  limit?: number;
}

export interface ActivityLogRepository {
  list(query?: ActivityLogQuery): Promise<ActivityLog[]>;
  log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void>;
}
```

- [ ] **Step 4: Update the Firestore implementation**

In `web_admin/src/data/repositories/FirestoreActivityLogRepository.ts`, replace `constraints` and delete the `watch` method. Remove `onSnapshot` from the `firebase/firestore` import and remove the `Unsubscribe` import. Add `ALL_ACTIVITY_TYPES` to the `@/domain/entities` import.

```ts
  private constraints(q: ActivityLogQuery): QueryConstraint[] {
    const out: QueryConstraint[] = [];
    const types = q.types ?? [];
    // Every type selected is the same as none, and skipping the constraint
    // keeps the query off the type+createdAt composite index.
    if (types.length > 0 && types.length < ALL_ACTIVITY_TYPES.length) {
      out.push(where('type', 'in', types));
    }
    if (q.start) out.push(where('createdAt', '>=', Timestamp.fromDate(q.start)));
    if (q.end) out.push(where('createdAt', '<=', Timestamp.fromDate(q.end)));
    out.push(orderBy('createdAt', 'desc'));
    if (q.limit) out.push(fsLimit(q.limit));
    return out;
  }
```

Also update the file's header comment to drop the "live stream" wording.

- [ ] **Step 5: Create the on-demand hook**

Create `web_admin/src/presentation/hooks/useActivityLogSearch.ts`:

```ts
// One-shot activity-log read, fired by the Search button. Deliberately not
// built on useFirestoreSubscription — /admin/logs must issue no read until
// the admin asks for one.

import { useCallback, useRef, useState } from 'react';
import { useActivityLogRepo } from '@/infrastructure/di/container';
import type { ActivityLogQuery } from '@/domain/repositories/ActivityLogRepository';
import type { ActivityLog } from '@/domain/entities';

/** Ceiling on a single search. Hitting it means the range was too wide. */
export const ACTIVITY_LOG_SEARCH_LIMIT = 500;

export interface ActivityLogSearchState {
  data: ActivityLog[] | null;
  error: Error | null;
  isLoading: boolean;
}

export function useActivityLogSearch() {
  const repo = useActivityLogRepo();
  const [state, setState] = useState<ActivityLogSearchState>({
    data: null,
    error: null,
    isLoading: false,
  });
  // Guards against an out-of-order reply when Search is clicked twice.
  const runId = useRef(0);

  const run = useCallback(
    async (query: ActivityLogQuery) => {
      const id = ++runId.current;
      setState({ data: null, error: null, isLoading: true });
      try {
        const rows = await repo.list(query);
        if (runId.current === id) setState({ data: rows, error: null, isLoading: false });
      } catch (e) {
        if (runId.current === id) {
          setState({
            data: null,
            error: e instanceof Error ? e : new Error(String(e)),
            isLoading: false,
          });
        }
      }
    },
    [repo],
  );

  return { ...state, run };
}
```

- [ ] **Step 6: Delete the old hook**

```bash
git rm web_admin/src/presentation/hooks/useActivityLogs.ts
```

- [ ] **Step 7: Rewrite the page body**

In `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx`, keep `ICONS`, `toneFor`, the `Intl` formatters, `dayKey`, `isToday`, `isYesterday`, `dateLabel`, and `LogRow` unchanged. Delete `COMMON_TYPES` and the whole `TypeFilter` component. Replace the imports of `useActivityLogs`, `FunnelIcon`, `ChevronDownIcon` and `cn` usage in the removed parts, then replace `ActivityLogsPage` with:

```tsx
export function ActivityLogsPage() {
  const [types, setTypes] = useState<ActivityType[]>([]);
  const [range, setRange] = useState<DateRange>(() => resolvePreset('today'));
  const [startTime, setStartTime] = useState('00:00');
  const [endTime, setEndTime] = useState('23:59');
  const [dirty, setDirty] = useState(false);
  const [searched, setSearched] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('activityLogs');
  const { data: logs, isLoading, error, run } = useActivityLogSearch();
  usePageClamp(page, setPage, logs?.length ?? 0, pageSize);

  useEffect(() => {
    document.title = 'Activity logs · MAKI POS Admin';
  }, []);

  const startAt = applyTime(range.start, startTime, false);
  const endAt = applyTime(range.end, endTime, true);
  const rangeInvalid = startAt.getTime() > endAt.getTime();

  function markDirty() {
    if (searched) setDirty(true);
  }

  function onSearch() {
    setSearched(true);
    setDirty(false);
    setPage(1);
    void run({
      types,
      start: startAt,
      end: endAt,
      limit: ACTIVITY_LOG_SEARCH_LIMIT,
    });
  }

  const pagedLogs = useMemo(
    () => (logs ?? []).slice((page - 1) * pageSize, page * pageSize),
    [logs, page, pageSize],
  );

  // Paginate the flat list BEFORE grouping by date, so each page's date
  // groups are coherent (a group never spans across a page boundary).
  const grouped = useMemo(() => {
    const groups = new Map<string, { date: Date; logs: ActivityLog[] }>();
    for (const log of pagedLogs) {
      const key = dayKey(log.createdAt);
      const existing = groups.get(key);
      if (existing) {
        existing.logs.push(log);
      } else {
        groups.set(key, {
          date: new Date(
            log.createdAt.getFullYear(),
            log.createdAt.getMonth(),
            log.createdAt.getDate(),
          ),
          logs: [log],
        });
      }
    }
    return Array.from(groups.values());
  }, [pagedLogs]);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="space-y-tk-md">
        <div className="flex flex-wrap items-end justify-between gap-tk-md">
          <div>
            <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
              Activity logs
            </h1>
            <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
              Audit trail of user actions across both web and mobile clients.
            </p>
          </div>
          {searched && logs ? (
            <button
              type="button"
              onClick={onSearch}
              className="rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Refresh
            </button>
          ) : null}
        </div>
        <ActivityLogFilterBar
          types={types}
          onTypes={(next) => {
            setTypes(next);
            markDirty();
          }}
          onRange={(next) => {
            setRange(next);
            markDirty();
          }}
          startTime={startTime}
          endTime={endTime}
          onStartTime={(v) => {
            setStartTime(v);
            markDirty();
          }}
          onEndTime={(v) => {
            setEndTime(v);
            markDirty();
          }}
          dirty={dirty}
          disabled={rangeInvalid}
          onSearch={onSearch}
        />
      </header>

      {!searched ? (
        <EmptyState
          title="Pick your filters and tap Search."
          description="Choose the operations and the date and time range you want to review, then tap Search."
        />
      ) : error ? (
        <ErrorView title="Could not load logs" message={error.message} />
      ) : isLoading || !logs ? (
        <LoadingView label="Loading logs…" />
      ) : grouped.length === 0 ? (
        <EmptyState
          title="No activity matched these filters"
          description="Try a wider date range, or fewer operations."
        />
      ) : (
        <div className="space-y-tk-lg">
          {logs.length >= ACTIVITY_LOG_SEARCH_LIMIT ? (
            <p className="text-bodySmall text-light-text-secondary">
              Showing the newest {ACTIVITY_LOG_SEARCH_LIMIT} — narrow your range.
            </p>
          ) : null}
          {grouped.map((group) => (
            <section key={dayKey(group.date)} className="space-y-tk-sm">
              <h2 className="sticky top-0 z-[1] -mx-tk-xl border-b border-light-hairline bg-light-background/80 px-tk-xl py-tk-xs text-[11px] font-semibold uppercase tracking-wider text-light-text-secondary backdrop-blur">
                {dateLabel(group.date)}
              </h2>
              <ul className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
                {group.logs.map((log) => (
                  <LogRow key={log.id} log={log} />
                ))}
              </ul>
            </section>
          ))}
          <Pager total={logs.length} page={page} onPage={setPage} pageSize={pageSize}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        </div>
      )}
    </div>
  );
}

/**
 * Stamps a wall-clock time onto a day. The end bound is pushed to the last
 * millisecond of the chosen minute so an inclusive `<=` never drops a record
 * logged within it.
 */
function applyTime(day: Date, hhmm: string, endInclusive: boolean): Date {
  const [h, m] = hhmm.split(':').map(Number);
  const d = new Date(day);
  d.setHours(h || 0, m || 0, endInclusive ? 59 : 0, endInclusive ? 999 : 0);
  return d;
}
```

Add these imports at the top of the file:

```tsx
import { ActivityLogFilterBar } from './ActivityLogFilterBar';
import {
  ACTIVITY_LOG_SEARCH_LIMIT,
  useActivityLogSearch,
} from '@/presentation/hooks/useActivityLogSearch';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
```

and remove the now-unused `useActivityLogs`, `FunnelIcon`, `ChevronDownIcon` and `activityTypeDisplayName` imports.

- [ ] **Step 8: Run the page tests**

Run (from `web_admin/`): `npm run test -- ActivityLogsPage`
Expected: PASS (8 tests).

- [ ] **Step 9: Confirm nothing still references the removed symbols**

Run (from `web_admin/`):

```bash
grep -rn "useActivityLogs\b\|COMMON_TYPES\|activityLogRepo.watch\|\.watch(" src | grep -i activ
```

Expected: no output.

- [ ] **Step 10: Full web gates**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: all clean.

- [ ] **Step 11: Commit**

```bash
git add web_admin/src
git commit -m "feat(web): gate activity logs behind filter-then-Search"
```

---

### Task 8: Final verification and handoff

**Files:** none modified.

**Interfaces:**
- Consumes: everything above.
- Produces: a verified branch and an explicit list of what the user must deploy.

- [ ] **Step 1: Run every mobile gate**

Run: `flutter analyze && flutter test`
Expected: analyze clean, all tests PASS. Record the actual output.

- [ ] **Step 2: Run every web gate**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: all clean. Record the actual output.

- [ ] **Step 3: Confirm no live subscription survives on either screen**

Run:

```bash
grep -rn "watchActivityLogs\|activityLogsStreamProvider" --include="*.dart" lib test
grep -rn "onSnapshot" web_admin/src/data/repositories/FirestoreActivityLogRepository.ts
```

Expected: no output from either.

- [ ] **Step 4: Report to the user — do not deploy**

State plainly, with the command output:
- both gate suites and their results;
- that `firestore.indexes.json` now contains the `user_logs` index and **needs `firebase deploy --only firestore:indexes`** before the operations filter works on a date range — the default all-operations search works without it;
- that the web change needs a hosting deploy and the mobile change needs APK +22;
- that device smoke is the user's step, and if the 500-row list janks on a heavy day, the spec's fallback is to drop the **mobile** cap to 200 and leave web at 500.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| §1 no fetch on open, filters, defaults, Search, dirty hint, Refresh, reset on leave | 4 (mobile), 7 (web) |
| §1 empty/edge states incl. invalid range | 3, 4, 6, 7 |
| §1 mobile collapse after search | 3, 4 |
| §1 web `defaultPreset`, Refresh placement | 6, 7 |
| §2 query shape, one-shot read | 4, 7 |
| §3 500 cap + notice + mobile fallback note | 4, 7, 8 |
| §4 composite index, not deployed | 1, 8 |
| §5 dead-code removal both surfaces | 2 (mobile providers/methods), 4 (`watchActivityLogs`), 7 (web `watch`, `useActivityLogs`) |
| §6 list-aware equality, canonical order, no initState fetch | 3, 4, 6 |
| §7 tests | 3, 4, 5, 6, 7 |
| §8 shipping | 8 |

Added beyond the spec: Task 5 (`day_closed` web drift). Justified — the feature is "filter by operation" and one operation was unlistable and mislabelled on web. Flagged to the user below.

**Placeholder scan:** none — every code step carries the literal code.

**Type consistency:** `kActivityLogSearchLimit` (Dart) and `ACTIVITY_LOG_SEARCH_LIMIT` (TS) are each defined once (Task 4 / Task 7) and referenced consistently. `getActivityLogs({types, startDate, endDate, limit})` matches between Task 4's interface, implementation, provider and tests. `ActivityLogQuery.types` matches between Task 7's contract, implementation, hook and page. `ActivityLogFilterCard`'s fifteen props match between Task 3's widget, its test, and Task 4's screen. `ActivityLogFilterBar`'s ten props match between Task 6's component, its test, and Task 7's page.
