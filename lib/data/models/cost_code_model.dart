import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for CostCode with Firestore serialization.
class CostCodeModel {
  final Map<String, String> digitToLetter;
  final String doubleZeroCode;
  final String tripleZeroCode;
  final DateTime? updatedAt;
  final String? updatedBy;

  const CostCodeModel({
    required this.digitToLetter,
    this.doubleZeroCode = 'SC',
    this.tripleZeroCode = 'SCS',
    this.updatedAt,
    this.updatedBy,
  });

  /// Creates from Firestore document.
  factory CostCodeModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CostCodeModel.fromMap(data);
  }

  /// Creates from a Map.
  factory CostCodeModel.fromMap(Map<String, dynamic> map) {
    // Parse digitToLetter map
    final rawMapping = map['digitToLetter'] as Map<String, dynamic>? ?? {};
    final digitToLetter = rawMapping.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    // Use defaults if mapping is empty
    if (digitToLetter.isEmpty) {
      return CostCodeModel.defaultMapping();
    }

    return CostCodeModel(
      digitToLetter: digitToLetter,
      doubleZeroCode: map['doubleZeroCode'] as String? ?? 'SC',
      tripleZeroCode: map['tripleZeroCode'] as String? ?? 'SCS',
      updatedAt: _parseTimestamp(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({bool forUpdate = false}) {
    final map = <String, dynamic>{
      'digitToLetter': digitToLetter,
      'doubleZeroCode': doubleZeroCode,
      'tripleZeroCode': tripleZeroCode,
      'updatedBy': updatedBy,
    };

    if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
  }

  /// Creates the default cost code mapping.
  factory CostCodeModel.defaultMapping() {
    return const CostCodeModel(
      digitToLetter: {
        '1': 'N',
        '2': 'B',
        '3': 'Q',
        '4': 'M',
        '5': 'F',
        '6': 'Z',
        '7': 'V',
        '8': 'L',
        '9': 'J',
        '0': 'S',
      },
      doubleZeroCode: 'SC',
      tripleZeroCode: 'SCS',
    );
  }

  /// Converts to domain entity.
  CostCodeEntity toEntity() {
    return CostCodeEntity(
      digitToLetter: digitToLetter,
      doubleZeroCode: doubleZeroCode,
      tripleZeroCode: tripleZeroCode,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  /// Creates from domain entity.
  factory CostCodeModel.fromEntity(CostCodeEntity entity) {
    return CostCodeModel(
      digitToLetter: entity.digitToLetter,
      doubleZeroCode: entity.doubleZeroCode,
      tripleZeroCode: entity.tripleZeroCode,
      updatedAt: entity.updatedAt,
      updatedBy: entity.updatedBy,
    );
  }

  /// Helper to parse Firestore timestamps.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  CostCodeModel copyWith({
    Map<String, String>? digitToLetter,
    String? doubleZeroCode,
    String? tripleZeroCode,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CostCodeModel(
      digitToLetter: digitToLetter ?? this.digitToLetter,
      doubleZeroCode: doubleZeroCode ?? this.doubleZeroCode,
      tripleZeroCode: tripleZeroCode ?? this.tripleZeroCode,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
