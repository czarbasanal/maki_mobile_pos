import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

/// Abstract repository contract for end-of-day closings.
abstract class DailyClosingRepository {
  /// Returns the saved closing for [date]'s business day, or null if the day
  /// has not been closed yet.
  Future<DailyClosingEntity?> getClosing(DateTime date);

  /// Returns the most recently closed business day (by `businessDate`), or
  /// null if no day has ever been closed.
  Future<DailyClosingEntity?> latestClosing();

  /// Persists a closing. The document id is the business date (`YYYY-MM-DD`).
  Future<DailyClosingEntity> saveClosing(DailyClosingEntity closing);

  /// Streams saved closings, newest first.
  Stream<List<DailyClosingEntity>> watchClosings({int limit = 60});
}
