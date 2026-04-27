import 'package:equatable/equatable.dart';

/// Types of petty cash transactions.
enum PettyCashType {
  /// Cash added to the fund
  cashIn('cash_in', 'Cash In'),

  /// Cash withdrawn from the fund
  cashOut('cash_out', 'Cash Out'),

  /// Initial fund setup
  initial('initial', 'Initial Fund'),

  /// Cut-off / end-of-day settlement
  cutOff('cut_off', 'Cut-Off');

  const PettyCashType(this.value, this.displayName);

  final String value;
  final String displayName;

  static PettyCashType fromString(String? value) {
    return PettyCashType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PettyCashType.cashOut,
    );
  }
}

/// Represents a petty cash transaction record.
///
/// Tracks cash fund additions, withdrawals, and end-of-day settlements.
class PettyCashEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Type of transaction
  final PettyCashType type;

  /// Amount of the transaction
  final double amount;

  /// Running balance after this transaction
  final double balance;

  /// Description or purpose
  final String description;

  /// Optional reference (e.g., linked expense ID)
  final String? referenceId;

  /// When the transaction occurred
  final DateTime createdAt;

  /// ID of user who created this record
  final String createdBy;

  /// Display name of user who created this record
  final String createdByName;

  /// Optional notes
  final String? notes;

  const PettyCashEntity({
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

  PettyCashEntity copyWith({
    String? id,
    PettyCashType? type,
    double? amount,
    double? balance,
    String? description,
    String? referenceId,
    bool clearReferenceId = false,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    String? notes,
    bool clearNotes = false,
  }) {
    return PettyCashEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      balance: balance ?? this.balance,
      description: description ?? this.description,
      referenceId: clearReferenceId ? null : (referenceId ?? this.referenceId),
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        amount,
        balance,
        description,
        referenceId,
        createdAt,
        createdBy,
        createdByName,
        notes,
      ];
}
