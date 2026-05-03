import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final params = ActivityLogParams(
      type: _typeFilter,
      limit: 100,
    );

    final logsAsync = ref.watch(activityLogsStreamProvider(params));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Activity Logs'),
        actions: [
          PopupMenuButton<ActivityType?>(
            icon: const Icon(CupertinoIcons.line_horizontal_3_decrease),
            tooltip: 'Filter by type',
            onSelected: (type) {
              setState(() => _typeFilter = type);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Activities'),
              ),
              const PopupMenuDivider(),
              ..._getCommonActivityTypes().map((type) => PopupMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Text(type.emoji),
                        const SizedBox(width: AppSpacing.sm),
                        Text(type.displayName),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter — flat with hairline bottom border
          if (_typeFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.line_horizontal_3_decrease,
                    size: 16,
                    color: muted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Chip(
                    avatar: Text(_typeFilter!.emoji),
                    label: Text(_typeFilter!.displayName),
                    deleteIcon: const Icon(CupertinoIcons.xmark, size: 16),
                    onDeleted: () => setState(() => _typeFilter = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Expanded(
            child: logsAsync.when(
              data: (logs) => _buildLogsList(logs),
              loading: () => const LoadingView(),
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

  Widget _buildLogsList(List<ActivityLogEntity> logs) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.clock, size: 56, color: muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No activity logs found',
              style: theme.textTheme.titleMedium?.copyWith(color: muted),
            ),
          ],
        ),
      );
    }

    final groupedLogs = _groupLogsByDate(logs);

    return ListView.builder(
      itemCount: groupedLogs.length,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemBuilder: (context, index) {
        final dateGroup = groupedLogs.entries.elementAt(index);
        return _buildDateGroup(dateGroup.key, dateGroup.value);
      },
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

  Widget _buildDateGroup(DateTime date, List<ActivityLogEntity> logs) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateStr = _isToday(date)
        ? 'Today'
        : _isYesterday(date)
            ? 'Yesterday'
            : DateFormat('EEEE, MMMM d, y').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header — flat with hairline borders
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: hairline),
              bottom: BorderSide(color: hairline),
            ),
          ),
          width: double.infinity,
          child: Text(
            dateStr.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
        ),
        ...logs.map((log) => _buildLogItem(log)),
      ],
    );
  }

  Widget _buildLogItem(ActivityLogEntity log) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final timeStr = DateFormat('h:mm a').format(log.createdAt);
    final accent = _typeAccent(log.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji glyph — outlined circle for security/financial events,
          // hairline circle otherwise. Carries semantic accent only when
          // the action matters for audit (security-related / financial).
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent ?? hairline),
            ),
            child: Center(
              child: Text(
                log.type.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.action,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.details!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(CupertinoIcons.person, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      log.userName,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: hairline),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        log.userRole,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reserve color for the audit-meaningful events: security
  /// (failed/verified password, role change) and financial (sale, void,
  /// petty cash, cost-code change). Everything else stays neutral —
  /// the emoji already gives the categorical hint.
  Color? _typeAccent(ActivityType type) {
    if (type.isSecurityRelated) return AppColors.error;
    if (type.isFinancialAction) return AppColors.success;
    return null;
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
