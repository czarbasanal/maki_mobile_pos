import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for ActivityLog with Firestore serialization.
class ActivityLogModel {
  final String id;
  final ActivityType type;
  final String action;
  final String? details;
  final String userId;
  final String userName;
  final String userRole;
  final String? entityId;
  final String? entityType;
  final Map<String, dynamic>? metadata;
  final String? deviceInfo;
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.type,
    required this.action,
    this.details,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.entityId,
    this.entityType,
    this.metadata,
    this.deviceInfo,
    required this.createdAt,
  });

  /// Creates from Firestore document.
  factory ActivityLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ActivityLogModel.fromMap(data, doc.id);
  }

  /// Creates from a Map.
  factory ActivityLogModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return ActivityLogModel(
      id: documentId,
      type: ActivityType.fromString(map['type'] as String?),
      action: map['action'] as String? ?? '',
      details: map['details'] as String?,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userRole: map['userRole'] as String? ?? '',
      entityId: map['entityId'] as String?,
      entityType: map['entityType'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      deviceInfo: map['deviceInfo'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = <String, dynamic>{
      'type': type.value,
      'action': action,
      'details': details,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'entityId': entityId,
      'entityType': entityType,
      'metadata': metadata,
      'deviceInfo': deviceInfo,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
    }

    return map;
  }

  /// Converts to domain entity.
  ActivityLogEntity toEntity() {
    return ActivityLogEntity(
      id: id,
      type: type,
      action: action,
      details: details,
      userId: userId,
      userName: userName,
      userRole: userRole,
      entityId: entityId,
      entityType: entityType,
      metadata: metadata,
      deviceInfo: deviceInfo,
      createdAt: createdAt,
    );
  }

  /// Creates from domain entity.
  factory ActivityLogModel.fromEntity(ActivityLogEntity entity) {
    return ActivityLogModel(
      id: entity.id,
      type: entity.type,
      action: entity.action,
      details: entity.details,
      userId: entity.userId,
      userName: entity.userName,
      userRole: entity.userRole,
      entityId: entity.entityId,
      entityType: entity.entityType,
      metadata: entity.metadata,
      deviceInfo: entity.deviceInfo,
      createdAt: entity.createdAt,
    );
  }

  /// Helper to parse Firestore timestamps.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
