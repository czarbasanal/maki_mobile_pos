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
