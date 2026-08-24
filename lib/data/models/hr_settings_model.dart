import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for [HrSettingsEntity] (the `settings/hr` doc).
///
/// Saving is a full-overwrite `set` of EXACTLY three fields — the same
/// contract as the web admin, so neither surface can leave a stale extra key
/// behind for the other. A missing doc (or missing field) falls back to the
/// 1 / 100 / 30 defaults.
class HrSettingsModel {
  final HrSettingsEntity entity;

  const HrSettingsModel(this.entity);

  factory HrSettingsModel.fromEntity(HrSettingsEntity e) => HrSettingsModel(e);

  factory HrSettingsModel.fromMap(Map<String, dynamic>? map) {
    const d = HrSettingsEntity.defaults;
    if (map == null) return const HrSettingsModel(d);
    return HrSettingsModel(HrSettingsEntity(
      weekStartDay: (map['weekStartDay'] as num?)?.toInt() ?? d.weekStartDay,
      regularHolidayPct:
          (map['regularHolidayPct'] as num?)?.toDouble() ?? d.regularHolidayPct,
      specialHolidayPct:
          (map['specialHolidayPct'] as num?)?.toDouble() ?? d.specialHolidayPct,
    ));
  }

  Map<String, dynamic> toMap() => {
        'weekStartDay': entity.weekStartDay,
        'regularHolidayPct': entity.regularHolidayPct,
        'specialHolidayPct': entity.specialHolidayPct,
      };

  HrSettingsEntity toEntity() => entity;
}
