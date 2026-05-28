import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';

/// Represents a business expense in the POS system.
///
/// Expenses are tracked for daily operations such as utilities,
/// supplies, transportation, and other business costs.
class ExpenseEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Description of the expense
  final String description;

  /// Amount in PHP
  final double amount;

  /// How the expense was paid. Defaults to cash. Only cash-paid expenses
  /// reduce drawer cash on hand in the end-of-day closing.
  final PaymentMethod paidVia;

  /// Category of the expense
  final String category;

  /// Date when the expense occurred
  final DateTime date;

  /// Optional notes or additional details
  final String? notes;

  /// Optional receipt number or reference
  final String? receiptNumber;

  /// When the record was created
  final DateTime createdAt;

  /// When the record was last updated
  final DateTime? updatedAt;

  /// ID of user who created this record
  final String createdBy;

  /// Display name of user who created this record
  final String createdByName;

  /// ID of user who last updated this record
  final String? updatedBy;

  const ExpenseEntity({
    required this.id,
    required this.description,
    required this.amount,
    this.paidVia = PaymentMethod.cash,
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

  ExpenseEntity copyWith({
    String? id,
    String? description,
    double? amount,
    PaymentMethod? paidVia,
    String? category,
    DateTime? date,
    String? notes,
    bool clearNotes = false,
    String? receiptNumber,
    bool clearReceiptNumber = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidVia: paidVia ?? this.paidVia,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: clearNotes ? null : (notes ?? this.notes),
      receiptNumber:
          clearReceiptNumber ? null : (receiptNumber ?? this.receiptNumber),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        amount,
        paidVia,
        category,
        date,
        notes,
        receiptNumber,
        createdAt,
        updatedAt,
        createdBy,
        createdByName,
        updatedBy,
      ];
}
