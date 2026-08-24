import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/payslip_repository.dart';

/// Firestore implementation of [PayslipRepository] — the `payslips`
/// collection shared with the web admin. Frozen snapshots: create / read /
/// delete only, no update path exists (rules enforce `update: if false`).
class PayslipRepositoryImpl implements PayslipRepository {
  final FirebaseFirestore _firestore;

  PayslipRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.payslips);

  @override
  Stream<List<PayslipEntity>> watchAll() {
    return _ref.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PayslipModel.fromFirestore(d).toEntity())
          .toList();
      // Web's fixed sort: newest period first, names A→Z within a period.
      // Client-side (string compare on 'YYYY-MM-DD' is chronological) so no
      // composite index is needed.
      list.sort((a, b) {
        final byPeriod = b.periodStart.compareTo(a.periodStart);
        if (byPeriod != 0) return byPeriod;
        return a.employeeName
            .toLowerCase()
            .compareTo(b.employeeName.toLowerCase());
      });
      return list;
    });
  }

  @override
  Future<PayslipEntity?> getById(String id) async {
    try {
      final doc = await _ref.doc(id).get();
      if (!doc.exists) return null;
      return PayslipModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get payslip: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<String> create(PayslipEntity payslip) async {
    try {
      final ref =
          await _ref.add(PayslipModel.fromEntity(payslip).toMap(forCreate: true));
      return ref.id;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create payslip: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _ref.doc(id).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete payslip: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
