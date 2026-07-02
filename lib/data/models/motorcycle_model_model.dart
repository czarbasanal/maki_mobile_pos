import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore serialization for [MotorcycleModelEntity].
class MotorcycleModelModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MotorcycleModelModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory MotorcycleModelModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      MotorcycleModelModel.fromMap(doc.data()!, doc.id);

  factory MotorcycleModelModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return MotorcycleModelModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false, bool forUpdate = false}) {
    final map = <String, dynamic>{
      'name': name,
      // Dedup key — derived, write-only. Enables case-insensitive lookup.
      'normalizedName': normalizedModelKey(name),
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
      if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }
    return map;
  }

  Map<String, dynamic> toCreateMap(String createdByUserId) =>
      copyWith(createdBy: createdByUserId).toMap(forCreate: true);

  Map<String, dynamic> toUpdateMap(String updatedByUserId) =>
      copyWith(updatedBy: updatedByUserId).toMap(forUpdate: true);

  MotorcycleModelEntity toEntity() => MotorcycleModelEntity(
        id: id,
        name: name,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
      );

  factory MotorcycleModelModel.fromEntity(MotorcycleModelEntity e) =>
      MotorcycleModelModel(
        id: e.id,
        name: e.name,
        isActive: e.isActive,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
      );

  MotorcycleModelModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MotorcycleModelModel(
      id: id ?? this.id,
      name: name ?? this.name,
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
