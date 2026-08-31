import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
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

  /// Reference to the drawer_state/state doc (business-day rollover marker).
  DocumentReference<Map<String, dynamic>> get _drawerStateRef =>
      _firestore.collection(FirestoreCollections.drawerState).doc('state');

  /// Document id for a business day. [shopWallDate] must be a shop
  /// wall-clock date (businessDayProvider's value / businessDateOf output),
  /// never a raw instant — a raw instant would key the doc by the device's
  /// day.
  static String docIdFor(DateTime shopWallDate) {
    final y = shopWallDate.year.toString().padLeft(4, '0');
    final m = shopWallDate.month.toString().padLeft(2, '0');
    final d = shopWallDate.day.toString().padLeft(2, '0');
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
  Future<DailyClosingEntity?> latestClosing() async {
    try {
      final snapshot = await _ref
          .orderBy('businessDate', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return DailyClosingModel.fromFirestore(snapshot.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load latest closing: ${e.message}',
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

      // Batch the closing write with the drawer_state stamp so they land
      // atomically. lastClosedDay is the CLOSED day (closing.businessDate),
      // which for a past-day close is < today — allowed by the rules' ≤
      // phDay constraint.
      //
      // businessDate is a business DATE, not an instant: its y/m/d fields
      // already name the shop day (it is derived from businessDayProvider).
      // So read the fields directly — shifting it by the shop offset here
      // would be a second shift and a silent off-by-one.
      final batch = _firestore.batch();
      batch.set(docRef, model.toCreateMap());
      batch.set(
        _drawerStateRef,
        {'lastClosedDay': businessDayIntOfWall(closing.businessDate)},
        SetOptions(merge: true),
      );
      await batch.commit();

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

  @override
  Future<List<DailyClosingEntity>> getClosingsInRange({
    required DateTime fromBusinessDate,
    required DateTime toBusinessDate,
  }) async {
    try {
      // businessDate is stored as the shop wall midnight, so the bounds are
      // those same wall values — not day-start instants, which would sit
      // hours before the stored value and drop the first day.
      final snapshot = await _ref
          .where('businessDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(fromBusinessDate))
          .where('businessDate',
              isLessThanOrEqualTo: Timestamp.fromDate(toBusinessDate))
          .orderBy('businessDate', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => DailyClosingModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load closings: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DrawerState> getDrawerState() async {
    try {
      final doc = await _drawerStateRef.get();
      if (!doc.exists) return const DrawerState.empty();
      final data = doc.data() ?? const {};
      return DrawerState(
        lastSaleDay: data['lastSaleDay'] as int?,
        lastClosedDay: data['lastClosedDay'] as int?,
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to read drawer state: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
