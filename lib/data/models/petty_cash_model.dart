import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore data model for petty cash records.
class PettyCashModel {
  final String id;
  final PettyCashType type;
  final double amount;
  final double balance;
  final String description;
  final String? referenceId;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final String? notes;

  const PettyCashModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balance,
    required this.description,
    this.referenceId,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.notes,
  });

  factory PettyCashModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PettyCashModel.fromMap(data, doc.id);
  }

  factory PettyCashModel.fromMap(Map<String, dynamic> map, String id) {
    return PettyCashModel(
      id: id,
      type: PettyCashType.fromString(map['type'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      referenceId: map['referenceId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      notes: map['notes'] as String?,
    );
  }

  factory PettyCashModel.fromEntity(PettyCashEntity entity) {
    return PettyCashModel(
      id: entity.id,
      type: entity.type,
      amount: entity.amount,
      balance: entity.balance,
      description: entity.description,
      referenceId: entity.referenceId,
      createdAt: entity.createdAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      notes: entity.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'amount': amount,
      'balance': balance,
      'description': description,
      'referenceId': referenceId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'notes': notes,
    };
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'type': type.value,
      'amount': amount,
      'balance': balance,
      'description': description,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'notes': notes,
    };
  }

  PettyCashEntity toEntity() {
    return PettyCashEntity(
      id: id,
      type: type,
      amount: amount,
      balance: balance,
      description: description,
      referenceId: referenceId,
      createdAt: createdAt,
      createdBy: createdBy,
      createdByName: createdByName,
      notes: notes,
    );
  }
}
