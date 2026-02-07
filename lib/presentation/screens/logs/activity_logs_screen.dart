import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:intl/intl.dart';

/// Screen displaying activity logs for audit trail.
class ActivityLogsScreen extends ConsumerStatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  ConsumerState<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends ConsumerState<ActivityLogsScreen> {
  ActivityType? _typeFilter;
  final _dateFormat = DateFormat('MMM d, y • h:mm a');

  @override
  Widget build(BuildContext context) {
    final params = ActivityLogParams(
      type: _typeFilter,
      limit: 100,
    );

    final logsAsync = ref.watch(activityLogsStreamProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          // Filter by type
          PopupMenuButton<ActivityType?>(
            icon: const Icon(Icons.filter_list),
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
                        const SizedBox(width: 8),
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
          // Active filter
          if (_typeFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Text(_typeFilter!.emoji),
                    label: Text(_typeFilter!.displayName),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _typeFilter = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Logs list
          Expanded(
            child: logsAsync.when(
              data: (logs) => _buildLogsList(logs),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
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
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No activity logs found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Group logs by date
    final groupedLogs = _groupLogsByDate(logs);

    return ListView.builder(
      itemCount: groupedLogs.length,
      padding: const EdgeInsets.only(bottom: 16),
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
    final dateStr = _isToday(date)
        ? 'Today'
        : _isYesterday(date)
            ? 'Yesterday'
            : DateFormat('EEEE, MMMM d, y').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          width: double.infinity,
          child: Text(
            dateStr,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),

        // Logs for this date
        ...logs.map((log) => _buildLogItem(log)),
      ],
    );
  }

  Widget _buildLogItem(ActivityLogEntity log) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('h:mm a').format(log.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type emoji
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTypeColor(log.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                log.type.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Log details
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      log.userName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.userRole,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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

  Color _getTypeColor(ActivityType type) {
    if (type.isSecurityRelated) return Colors.red;
    if (type.isFinancialAction) return Colors.green;

    switch (type) {
      case ActivityType.inventory:
      case ActivityType.stockAdjustment:
      case ActivityType.receiving:
        return Colors.blue;
      case ActivityType.userManagement:
      case ActivityType.userCreated:
      case ActivityType.userUpdated:
      case ActivityType.userDeactivated:
      case ActivityType.roleChanged:
        return Colors.purple;
      case ActivityType.settings:
      case ActivityType.costCodeChanged:
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
