import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_row.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying activity logs for audit trail.
class ActivityLogsScreen extends ConsumerStatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  ConsumerState<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends ConsumerState<ActivityLogsScreen> {
  ActivityType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final params = ActivityLogParams(
      type: _typeFilter,
      limit: 100,
    );

    final logsAsync = ref.watch(activityLogsStreamProvider(params));
    final filterActive = _typeFilter != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Activity Logs'),
        actions: [
          PopupMenuButton<ActivityType?>(
            tooltip: 'Filter by type',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filterActive
                    ? (isDark
                        ? AppColors.darkAccent.withValues(alpha: 0.16)
                        : AppColors.brandSlate.withValues(alpha: 0.09))
                    : Colors.transparent,
              ),
              child: Icon(
                LucideIcons.slidersHorizontal,
                size: 21,
                color: filterActive
                    ? (isDark ? AppColors.darkAccent : AppColors.brandSlate)
                    : null,
              ),
            ),
            onSelected: (type) => setState(() => _typeFilter = type),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Activities'),
              ),
              const PopupMenuDivider(),
              ..._getCommonActivityTypes().map((type) {
                final style = ActivityLogStyle.of(type, dark: isDark);
                return PopupMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(style.icon, size: 18, color: style.iconColor),
                      const SizedBox(width: AppSpacing.sm + 3),
                      Text(type.displayName),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (filterActive) _buildActiveFilter(isDark),
          Expanded(
            child: logsAsync.when(
              data: (logs) => _buildLogsList(logs, isDark),
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorStateView(
                message: 'Error: $error',
                onRetry: () =>
                    ref.invalidate(activityLogsStreamProvider(params)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilter(bool isDark) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = ActivityLogStyle.of(_typeFilter!, dark: isDark);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline(isDark))),
      ),
      child: Row(
        children: [
          Text(
            'FILTERED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: muted,
            ),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: _typeFilter!.displayName,
            icon: style.icon,
            iconColor: style.iconColor,
            onClear: () => setState(() => _typeFilter = null),
          ),
        ],
      ),
    );
  }

  List<ActivityType> _getCommonActivityTypes() {
    return [
      ActivityType.login,
      ActivityType.logout,
      ActivityType.sale,
      ActivityType.voidSale,
      ActivityType.stockAdjustment,
      ActivityType.receiving,
      ActivityType.userCreated,
      ActivityType.userUpdated,
      ActivityType.roleChanged,
      ActivityType.passwordVerified,
      ActivityType.passwordFailed,
      ActivityType.costViewed,
    ];
  }

  Widget _buildLogsList(List<ActivityLogEntity> logs, bool isDark) {
    if (logs.isEmpty) return _buildEmptyState(isDark);

    final groupedLogs = _groupLogsByDate(logs);

    return ListView.builder(
      itemCount: groupedLogs.length,
      padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.md),
      itemBuilder: (context, index) {
        final dateGroup = groupedLogs.entries.elementAt(index);
        return _buildDateGroup(dateGroup.key, dateGroup.value, isDark);
      },
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
              'No activity logs found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Actions taken across the store will appear here as an '
              'audit trail.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: muted,
              ),
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}

/// Active-filter pill: type icon + label + a round close button.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onClear,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0x0FFFFFFF) : AppColors.brandSlate.withValues(alpha: 0.07),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onClear,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 5, 5, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? const Color(0x17FFFFFF)
                      : const Color(0x12111C1D),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.x,
                    size: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
