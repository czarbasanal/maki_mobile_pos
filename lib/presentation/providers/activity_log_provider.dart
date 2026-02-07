import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

// ==================== ACTIVITY LOG QUERIES ====================

/// Parameters for fetching activity logs.
class ActivityLogParams {
  final ActivityType? type;
  final String? userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const ActivityLogParams({
    this.type,
    this.userId,
    this.startDate,
    this.endDate,
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityLogParams &&
        other.type == type &&
        other.userId == userId &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      type.hashCode ^
      userId.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      limit.hashCode;
}

/// Provides activity logs based on parameters.
final activityLogsProvider =
    FutureProvider.family<List<ActivityLogEntity>, ActivityLogParams>(
  (ref, params) async {
    final repository = ref.watch(activityLogRepositoryProvider);
    return repository.getActivityLogs(
      type: params.type,
      userId: params.userId,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  },
);

/// Provides activity logs as a stream.
final activityLogsStreamProvider =
    StreamProvider.family<List<ActivityLogEntity>, ActivityLogParams>(
  (ref, params) {
    final repository = ref.watch(activityLogRepositoryProvider);
    return repository.watchActivityLogs(
      type: params.type,
      userId: params.userId,
      limit: params.limit,
    );
  },
);

/// Provides recent security logs.
final securityLogsProvider =
    FutureProvider<List<ActivityLogEntity>>((ref) async {
  final repository = ref.watch(activityLogRepositoryProvider);
  return repository.getSecurityLogs(limit: 100);
});

/// Provides logs for a specific user.
final userActivityLogsProvider =
    FutureProvider.family<List<ActivityLogEntity>, String>(
  (ref, userId) async {
    final repository = ref.watch(activityLogRepositoryProvider);
    return repository.getUserLogs(userId: userId, limit: 50);
  },
);

/// Provides logs for a specific entity.
final entityLogsProvider = FutureProvider.family<List<ActivityLogEntity>,
    ({String entityId, String entityType})>(
  (ref, params) async {
    final repository = ref.watch(activityLogRepositoryProvider);
    return repository.getEntityLogs(
      entityId: params.entityId,
      entityType: params.entityType,
    );
  },
);
