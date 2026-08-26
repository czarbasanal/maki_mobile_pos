import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

/// The timezone keys of the shared `settings/general` doc.
///
/// [watch] is a live stream because a timezone change has to reach every
/// open screen — a stale offset means a wrong business day. A missing doc
/// emits [ShopTimezoneEntity.defaults].
abstract class ShopTimezoneRepository {
  Stream<ShopTimezoneEntity> watch();

  Future<ShopTimezoneEntity> get();

  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy});
}
