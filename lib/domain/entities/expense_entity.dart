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

  /// Optional photo of the physical receipt (Storage download URL).
  final String? receiptImageUrl;

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

  /// Display name of user who last updated this record. Null until the
  /// first edit, or on a legacy record from before this field existed —
  /// mirrors the web admin's Expense.updatedByName.
  final String? updatedByName;

  const ExpenseEntity({
    required this.id,
    required this.description,
    required this.amount,
    this.paidVia = PaymentMethod.cash,
    required this.category,
    required this.date,
    this.notes,
    this.receiptNumber,
    this.receiptImageUrl,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.createdByName,
    this.updatedBy,
    this.updatedByName,
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
    String? receiptImageUrl,
    bool clearReceiptImageUrl = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
    String? updatedByName,
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
      receiptImageUrl: clearReceiptImageUrl
          ? null
          : (receiptImageUrl ?? this.receiptImageUrl),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
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
        receiptImageUrl,
        createdAt,
        updatedAt,
        createdBy,
        createdByName,
        updatedBy,
        updatedByName,
      ];
}
