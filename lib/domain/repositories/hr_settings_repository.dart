import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// The single `settings/hr` doc. Missing doc reads as
/// [HrSettingsEntity.defaults]; save is a full overwrite of its three fields.
abstract class HrSettingsRepository {
  Future<HrSettingsEntity> get();

  Future<void> save(HrSettingsEntity settings);
}
