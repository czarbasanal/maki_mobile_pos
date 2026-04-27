import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/petty_cash_model.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';

/// Firestore implementation of [PettyCashRepository].
class PettyCashRepositoryImpl implements PettyCashRepository {
  final FirebaseFirestore _firestore;

  PettyCashRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _pettyCashRef =>
      _firestore.collection(FirestoreCollections.pettyCash);

  // ==================== CREATE ====================

  @override
  Future<PettyCashEntity> createRecord(PettyCashEntity record) async {
    try {
      final model = PettyCashModel.fromEntity(record);
      final docRef = await _pettyCashRef.add(model.toCreateMap());
      final doc = await docRef.get();
      return PettyCashModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create petty cash record: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<PettyCashEntity?> getRecordById(String recordId) async {
    try {
      final doc = await _pettyCashRef.doc(recordId).get();
      if (!doc.exists) return null;
      return PettyCashModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get petty cash record: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<PettyCashEntity>> getRecords({
    PettyCashType? type,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _pettyCashRef.orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }
      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PettyCashModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get petty cash records: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<PettyCashEntity>> watchRecords({int limit = 50}) {
    return _pettyCashRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PettyCashModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<double> getCurrentBalance() async {
    try {
      // Get the most recent record to find current balance
      final snapshot = await _pettyCashRef
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      return (data['balance'] as num?)?.toDouble() ?? 0.0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get current balance: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== TRANSACTIONS ====================

  @override
  Future<PettyCashEntity> cashIn({
    required double amount,
    required String description,
    required String createdBy,
    required String createdByName,
    String? notes,
  }) async {
    final currentBalance = await getCurrentBalance();
    final newBalance = currentBalance + amount;

    final record = PettyCashEntity(
      id: '',
      type: PettyCashType.cashIn,
      amount: amount,
      balance: newBalance,
      description: description,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      createdByName: createdByName,
      notes: notes,
    );

    return createRecord(record);
  }

  @override
  Future<PettyCashEntity> cashOut({
    required double amount,
    required String description,
    required String createdBy,
    required String createdByName,
    String? referenceId,
    String? notes,
  }) async {
    final currentBalance = await getCurrentBalance();
    final newBalance = currentBalance - amount;

    final record = PettyCashEntity(
      id: '',
      type: PettyCashType.cashOut,
      amount: amount,
      balance: newBalance,
      description: description,
      referenceId: referenceId,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      createdByName: createdByName,
      notes: notes,
    );

    return createRecord(record);
  }

  @override
  Future<PettyCashEntity> performCutOff({
    required String createdBy,
    required String createdByName,
    String? notes,
  }) async {
    final currentBalance = await getCurrentBalance();

    final record = PettyCashEntity(
      id: '',
      type: PettyCashType.cutOff,
      amount: currentBalance,
      balance: 0,
      description: 'End-of-day cut-off',
      createdAt: DateTime.now(),
      createdBy: createdBy,
      createdByName: createdByName,
      notes: notes,
    );

    return createRecord(record);
  }
}
