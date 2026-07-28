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
    // Centred when it fits, scrollable when the expanded filter card leaves
    // little room (short phones, landscape) — never an overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(44, 30, 44, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    // Same shrink-safe treatment as the pre-search placeholder.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(44, 30, 44, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  Map<DateTime, List<ActivityLogEntity>> _groupLogsByDate(
    List<ActivityLogEntity> logs,
  ) {
    final grouped = <DateTime, List<ActivityLogEntity>>{};
    for (final log in logs) {
      final date = DateTime(
        log.createdAt.year,
        log.createdAt.month,
        log.createdAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(log);
    }
    return grouped;
  }

  Widget _buildDateGroup(
    DateTime date,
    List<ActivityLogEntity> logs,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateStr = _isToday(date)
        ? 'Today'
        : _isYesterday(date)
            ? 'Yesterday'
            : DateFormat('EEEE, MMMM d, y').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flat header above the card: date + event count.
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateStr.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: muted,
                  ),
                ),
              ),
              Text(
                logs.length == 1 ? '1 event' : '${logs.length} events',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        // One card per day holding the rows, hairline-divided.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppCard(
            radius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < logs.length; i++) ...[
                  ActivityLogRow(log: logs[i], dark: isDark),
                  if (i != logs.length - 1)
                    Divider(height: 1, color: AppColors.hairline(isDark)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Group labels compare against the business-day clock so "Today" /
  // "Yesterday" headers stay correct across a midnight rollover.
  bool _isToday(DateTime date) {
    final now = ref.watch(businessDayProvider);
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday =
        ref.watch(businessDayProvider).subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
