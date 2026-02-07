import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for ActivityLog operations.
abstract class ActivityLogRepository {
  /// Logs an activity.
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log);

  /// Gets activity logs with optional filters.
  Future<List<ActivityLogEntity>> getActivityLogs({
    ActivityType? type,
    String? userId,
    String? entityId,
    String? entityType,
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

  /// Gets activity logs for a specific entity.
  Future<List<ActivityLogEntity>> getEntityLogs({
    required String entityId,
    required String entityType,
    int limit = 20,
  });

  /// Gets recent security-related logs.
  Future<List<ActivityLogEntity>> getSecurityLogs({
    int limit = 50,
  });

  /// Gets logs by user.
  Future<List<ActivityLogEntity>> getUserLogs({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  /// Deletes old logs (for maintenance).
  Future<int> deleteOldLogs({
    required DateTime olderThan,
    int batchSize = 100,
  });
}
