import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for a shop-fee line with Firestore serialization.
///
/// Fee lines are stored **inline** inside the parent draft/sale document's
/// `feeLines` array (see spec), so [toMap] is called with `includeId: true`
/// to keep the line's id inside the array element. Mirrors [LaborLineModel]
/// for serialization shape.
class FeeLineModel {
  final String id;
  final String name;
  final double amount;
  final String? description;

  const FeeLineModel({
    required this.id,
    required this.name,
    this.amount = 0,
    this.description,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (an element of the inline `feeLines` array).
  ///
  /// Defaults [name] to `''` and [amount] to `0` so legacy / partial docs
  /// deserialize without throwing. [description] defaults to `null` (older
  /// docs written before this field existed).
  factory FeeLineModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FeeLineModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
    );
  }

  /// Creates from a Firestore document (when stored as a standalone doc).
  factory FeeLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FeeLineModel.fromMap(doc.data()!, doc.id);
  }

  /// Converts to a Map for Firestore.
  ///
  /// Emits `name` and `amount`; includes `id` only when [includeId] is true
  /// (set when serializing inline inside the parent's `feeLines` array).
  /// Emits `description` only when non-null, so old docs stay untouched.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'name': name,
      'amount': amount,
    };

    if (includeId) {
      map['id'] = id;
    }

    if (description != null) {
      map['description'] = description;
    }

    return map;
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  FeeLineEntity toEntity() {
    return FeeLineEntity(
      id: id,
      name: name,
      amount: amount,
      description: description,
    );
  }

  /// Creates from domain entity.
  factory FeeLineModel.fromEntity(FeeLineEntity entity) {
    return FeeLineModel(
      id: entity.id,
      name: entity.name,
      amount: entity.amount,
      description: entity.description,
    );
  }

  // ==================== COPY WITH ====================

  FeeLineModel copyWith({
    String? id,
    String? name,
    double? amount,
    String? description,
  }) {
    return FeeLineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'FeeLineModel(id: $id, name: $name, amount: $amount, '
        'description: $description)';
  }
}
