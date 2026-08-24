import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/hr_settings_repository.dart';

/// Firestore implementation of [HrSettingsRepository] — the `settings/hr`
/// doc shared with the web admin. Save is a full overwrite (plain set, no
/// merge) of exactly three fields, matching web, so neither surface leaves a
/// stale key for the other.
class HrSettingsRepositoryImpl implements HrSettingsRepository {
  final FirebaseFirestore _firestore;

  HrSettingsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(FirestoreCollections.settings)
      .doc(FirestoreCollections.hrSettings);

  @override
  Future<HrSettingsEntity> get() async {
    try {
      final snap = await _doc.get();
      return HrSettingsModel.fromMap(snap.data()).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load HR settings: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> save(HrSettingsEntity settings) async {
    try {
      await _doc.set(HrSettingsModel.fromEntity(settings).toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save HR settings: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
