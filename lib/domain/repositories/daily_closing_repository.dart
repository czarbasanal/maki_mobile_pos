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

  /// Reads the raw `drawer_state/state` singleton doc (client-readable
  /// business-day rollover marker, `FirestoreCollections.drawerState`).
  /// Returns [DrawerState.empty] when the doc doesn't exist yet, matching
  /// the rules' "missing doc ⇒ allow" semantics.
  Future<DrawerState> getDrawerState();
}

/// Raw fields of the `drawer_state/state` doc. Both are yyyymmdd ints (see
/// `businessDayInt`/`dateFromBusinessDayInt`); null means the field was
/// never written (mirrors the rules' `.get(field, 0)` "not yet stamped").
class DrawerState {
  final int? lastSaleDay;
  final int? lastClosedDay;

  const DrawerState({this.lastSaleDay, this.lastClosedDay});

  const DrawerState.empty() : this();
}
