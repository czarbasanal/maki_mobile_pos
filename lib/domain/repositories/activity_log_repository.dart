import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for ActivityLog operations.
abstract class ActivityLogRepository {
  /// Logs an activity.
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log);

  /// Gets activity logs. An empty [types] means "every operation".
  Future<List<ActivityLogEntity>> getActivityLogs({
    List<ActivityType> types = const [],
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });
}
