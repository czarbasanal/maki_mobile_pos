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
}
