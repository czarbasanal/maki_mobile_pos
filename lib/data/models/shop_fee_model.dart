import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for [ShopFeeEntity] with Firestore serialization.
class ShopFeeModel {
  final String id;
  final String name;
  final double? defaultAmount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ShopFeeModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.defaultAmount,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ShopFeeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ShopFeeModel.fromMap(data, doc.id);
  }

  factory ShopFeeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ShopFeeModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      defaultAmount: (map['defaultAmount'] as num?)?.toDouble(),
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
      'defaultAmount': defaultAmount,
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

  ShopFeeEntity toEntity() {
    return ShopFeeEntity(
      id: id,
      name: name,
      defaultAmount: defaultAmount,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  factory ShopFeeModel.fromEntity(ShopFeeEntity entity) {
    return ShopFeeModel(
      id: entity.id,
      name: entity.name,
      defaultAmount: entity.defaultAmount,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
    );
  }

  ShopFeeModel copyWith({
    String? id,
    String? name,
    double? defaultAmount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return ShopFeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
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
