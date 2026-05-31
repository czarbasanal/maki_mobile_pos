import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for a labor line with Firestore serialization.
///
/// Labor lines are stored **inline** inside the parent draft/sale document's
/// `laborLines` array (see spec §4.1), so [toMap] is called with
/// `includeId: true` to keep the line's id inside the array element. Mirrors
/// [SaleItemModel] for serialization shape.
class LaborLineModel {
  final String id;
  final String description;
  final double fee;

  const LaborLineModel({
    required this.id,
    required this.description,
    this.fee = 0,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (an element of the inline `laborLines` array).
  ///
  /// Defaults [description] to `''` and [fee] to `0` so legacy / partial docs
  /// deserialize without throwing.
  factory LaborLineModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LaborLineModel(
      id: documentId,
      description: map['description'] as String? ?? '',
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Creates from a Firestore document (when stored as a standalone doc).
  factory LaborLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return LaborLineModel.fromMap(doc.data()!, doc.id);
  }

  /// Converts to a Map for Firestore.
  ///
  /// Emits `description` and `fee`; includes `id` only when [includeId] is true
  /// (set when serializing inline inside the parent's `laborLines` array).
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'description': description,
      'fee': fee,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  LaborLineEntity toEntity() {
    return LaborLineEntity(
      id: id,
      description: description,
      fee: fee,
    );
  }

  /// Creates from domain entity.
  factory LaborLineModel.fromEntity(LaborLineEntity entity) {
    return LaborLineModel(
      id: entity.id,
      description: entity.description,
      fee: entity.fee,
    );
  }

  // ==================== COPY WITH ====================

  LaborLineModel copyWith({
    String? id,
    String? description,
    double? fee,
  }) {
    return LaborLineModel(
      id: id ?? this.id,
      description: description ?? this.description,
      fee: fee ?? this.fee,
    );
  }

  @override
  String toString() {
    return 'LaborLineModel(id: $id, description: $description, fee: $fee)';
  }
}
