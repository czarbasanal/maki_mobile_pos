import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';

/// Firestore implementation of [DailyClosingRepository].
///
/// Document id is the business date formatted `YYYY-MM-DD`, so each calendar
/// day maps to exactly one closing document.
class DailyClosingRepositoryImpl implements DailyClosingRepository {
  final FirebaseFirestore _firestore;

  DailyClosingRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(FirestoreCollections.dailyClosings);

  /// Formats a date as the deterministic `YYYY-MM-DD` document id.
  static String docIdFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<DailyClosingEntity?> getClosing(DateTime date) async {
    try {
      final doc = await _ref.doc(docIdFor(date)).get();
      if (!doc.exists) return null;
      return DailyClosingModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load closing: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DailyClosingEntity> saveClosing(DailyClosingEntity closing) async {
    try {
      debugPrint('DailyClosingRepository: saving closing ${closing.id}');
      final model = DailyClosingModel.fromEntity(closing);
      final docRef = _ref.doc(closing.id);
      await docRef.set(model.toCreateMap());
      final doc = await docRef.get();
      return DailyClosingModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save closing: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<DailyClosingEntity>> watchClosings({int limit = 60}) {
    return _ref
        .orderBy('businessDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyClosingModel.fromFirestore(doc).toEntity())
            .toList());
  }
}
