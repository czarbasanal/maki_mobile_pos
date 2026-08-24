// HR settings doc — full-overwrite semantics: toMap emits EXACTLY the three
// fields (an extra key would survive a later web write, since web also does a
// full setDoc of three keys). A missing/partial doc falls back per-field to
// the 1/100/30 defaults.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/hr_settings_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('missing map reads as the defaults', () {
    expect(HrSettingsModel.fromMap(null).toEntity(), HrSettingsEntity.defaults);
  });

  test('partial doc keeps per-field defaults', () {
    final e = HrSettingsModel.fromMap({'weekStartDay': 3}).toEntity();
    expect(e.weekStartDay, 3);
    expect(e.regularHolidayPct, 100);
    expect(e.specialHolidayPct, 30);
  });

  test('toMap emits exactly the three fields', () {
    const entity = HrSettingsEntity(
      weekStartDay: 7,
      regularHolidayPct: 200,
      specialHolidayPct: 50,
    );
    final map = HrSettingsModel.fromEntity(entity).toMap();
    expect(map.keys.toSet(),
        {'weekStartDay', 'regularHolidayPct', 'specialHolidayPct'});
    expect(map['weekStartDay'], 7);
    expect(HrSettingsModel.fromMap(map).toEntity(), entity);
  });
}
