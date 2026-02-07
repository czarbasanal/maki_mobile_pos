import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [ActivityLogRepository].
class ActivityLogRepositoryImpl implements ActivityLogRepository {
  final FirebaseFirestore _firestore;

  ActivityLogRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection(FirestoreCollections.userLogs);

  @override
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log) async {
    try {
      final model = ActivityLogModel.fromEntity(log);
      final docRef = await _logsRef.add(model.toMap(forCreate: true));
      return log.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to log activity: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ActivityLogEntity>> getActivityLogs({
    ActivityType? type,
    String? userId,
    String? entityId,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _logsRef.orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (entityId != null) {
        query = query.where('entityId', isEqualTo: entityId);
      }

      if (entityType != null) {
        query = query.where('entityType', isEqualTo: entityType);
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
          .map((doc) => ActivityLogModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get activity logs: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<ActivityLogEntity>> watchActivityLogs({
    ActivityType? type,
    String? userId,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query =
        _logsRef.orderBy('createdAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type.value);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ActivityLogModel.fromFirestore(doc).toEntity())
        .toList());
  }

  @override
  Future<List<ActivityLogEntity>> getEntityLogs({
    required String entityId,
    required String entityType,
    int limit = 20,
  }) async {
    return getActivityLogs(
      entityId: entityId,
      entityType: entityType,
      limit: limit,
    );
  }

  @override
  Future<List<ActivityLogEntity>> getSecurityLogs({
    int limit = 50,
  }) async {
    try {
      final securityTypes = [
        ActivityType.security.value,
        ActivityType.authentication.value,
        ActivityType.passwordVerified.value,
        ActivityType.passwordFailed.value,
        ActivityType.costViewed.value,
        ActivityType.userManagement.value,
        ActivityType.roleChanged.value,
      ];

      final snapshot = await _logsRef
          .where('type', whereIn: securityTypes)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ActivityLogModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get security logs: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ActivityLogEntity>> getUserLogs({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    return getActivityLogs(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  @override
  Future<int> deleteOldLogs({
    required DateTime olderThan,
    int batchSize = 100,
  }) async {
    try {
      int deletedCount = 0;

      while (true) {
        final snapshot = await _logsRef
            .where('createdAt', isLessThan: Timestamp.fromDate(olderThan))
            .limit(batchSize)
            .get();

        if (snapshot.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        deletedCount += snapshot.docs.length;

        if (snapshot.docs.length < batchSize) break;
      }

      return deletedCount;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete old logs: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
