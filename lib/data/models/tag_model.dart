import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for [TagEntity] with Firestore serialization.
class TagModel {
  final String id;
  final String name;
  final String color;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const TagModel({
    required this.id,
    required this.name,
    required this.color,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory TagModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TagModel.fromMap(data, doc.id);
  }

  factory TagModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TagModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      color: TagColors.normalize(map['color'] as String?),
      description: map['description'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'name': name,
      'color': color,
      'description': description,
      'isActive': isActive,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
      map['updatedBy'] = createdBy;
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['updatedBy'] = updatedBy;
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }

    return map;
  }

  Map<String, dynamic> toCreateMap(String createdByUserId) {
    return copyWith(createdBy: createdByUserId).toMap(forCreate: true);
  }

  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return copyWith(updatedBy: updatedByUserId).toMap(forUpdate: true);
  }

  TagEntity toEntity() {
    return TagEntity(
      id: id,
      name: name,
      color: color,
      description: description,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  factory TagModel.fromEntity(TagEntity entity) {
    return TagModel(
      id: entity.id,
      name: entity.name,
      color: entity.color,
      description: entity.description,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
    );
  }

  TagModel copyWith({
    String? id,
    String? name,
    String? color,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
