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
    List<ActivityType> types = const [],
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _logsRef;

      // Selecting every type is the same as selecting none, and skipping the
      // constraint keeps the query off the composite index.
      if (types.isNotEmpty && types.length < ActivityType.values.length) {
        query = query.where('type',
            whereIn: types.map((t) => t.value).toList(growable: false));
      }

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

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
}
