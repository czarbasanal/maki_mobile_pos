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
