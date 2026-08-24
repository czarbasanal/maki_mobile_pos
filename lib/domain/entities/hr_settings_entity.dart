// Shop-wide HR settings (settings/hr doc) — port of HrSettings in
// web_admin/src/domain/hr/types.ts. A missing doc means the defaults below;
// saving is a full overwrite of exactly these three fields.
import 'package:equatable/equatable.dart';

class HrSettingsEntity extends Equatable {
  /// ISO weekday 1–7 the pay week starts on.
  final int weekStartDay;

  /// Regular-holiday pay as a percentage of the daily rate (100 = full day).
  final double regularHolidayPct;

  /// Special-holiday pay as a percentage of the daily rate.
  final double specialHolidayPct;

  const HrSettingsEntity({
    required this.weekStartDay,
    required this.regularHolidayPct,
    required this.specialHolidayPct,
  });

  static const defaults = HrSettingsEntity(
    weekStartDay: 1,
    regularHolidayPct: 100,
    specialHolidayPct: 30,
  );

  @override
  List<Object?> get props => [weekStartDay, regularHolidayPct, specialHolidayPct];
}
