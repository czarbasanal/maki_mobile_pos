import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore data model for expenses.
///
/// Handles serialization/deserialization between Firestore and [ExpenseEntity].
class ExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? notes;
  final String? receiptNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String createdByName;
  final String? updatedBy;

  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.receiptNumber,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.createdByName,
    this.updatedBy,
  });

  /// Creates an [ExpenseModel] from a Firestore document snapshot.
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel.fromMap(data, doc.id);
  }

  /// Creates an [ExpenseModel] from a map and document ID.
  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'] as String?,
      receiptNumber: map['receiptNumber'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      updatedBy: map['updatedBy'] as String?,
    );
  }

  /// Creates an [ExpenseModel] from an [ExpenseEntity].
  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      description: entity.description,
      amount: entity.amount,
      category: entity.category,
      date: entity.date,
      notes: entity.notes,
      receiptNumber: entity.receiptNumber,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      updatedBy: entity.updatedBy,
    );
  }

  /// Converts to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'receiptNumber': receiptNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'updatedBy': updatedBy,
    };
  }

  /// Converts to a map for creating a new document (uses server timestamp).
  Map<String, dynamic> toCreateMap() {
    return {
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'receiptNumber': receiptNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  /// Converts to a map for updating an existing document.
  Map<String, dynamic> toUpdateMap() {
    return {
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'receiptNumber': receiptNumber,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  /// Converts to an [ExpenseEntity].
  ExpenseEntity toEntity() {
    return ExpenseEntity(
      id: id,
      description: description,
      amount: amount,
      category: category,
      date: date,
      notes: notes,
      receiptNumber: receiptNumber,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      createdByName: createdByName,
      updatedBy: updatedBy,
    );
  }
}
