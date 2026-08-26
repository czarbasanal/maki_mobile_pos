import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/shop_timezone_model.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';

/// Firestore implementation over `settings/general`, the doc shared with the
/// web admin. Saves merge rather than overwrite: `general` is a bucket for
/// other future settings, unlike `settings/hr` which is a full overwrite.
class ShopTimezoneRepositoryImpl implements ShopTimezoneRepository {
  final FirebaseFirestore _firestore;

  ShopTimezoneRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(FirestoreCollections.settings)
      .doc(FirestoreCollections.generalSettings);

  @override
  Stream<ShopTimezoneEntity> watch() => _doc
      .snapshots()
      .map((snap) => ShopTimezoneModel.fromMap(snap.data()).toEntity());

  @override
  Future<ShopTimezoneEntity> get() async {
    try {
      final snap = await _doc.get();
      return ShopTimezoneModel.fromMap(snap.data()).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load shop timezone: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}) async {
    try {
      await _doc.set(
        ShopTimezoneModel.fromEntity(settings).toMap(updatedBy: updatedBy),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save shop timezone: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
