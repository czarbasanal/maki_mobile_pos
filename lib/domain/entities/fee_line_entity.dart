import 'package:equatable/equatable.dart';

/// A shop-fee line (outside-item charge, electric charge, tire changer,
/// air, …). Belongs to the SHOP — never to a mechanic; never discounted;
/// zero cost.
class FeeLineEntity extends Equatable {
  /// Unique identifier for this fee line (uuid, like cart items).
  final String id;

  /// What the fee is for, e.g. "Electric charge", "Tire changer", "Air".
  final String name;

  /// Peso amount charged for this fee line. Full price, never discounted.
  final double amount;

  /// Free-form description, required only for the "Charge Item" fee (a
  /// cashier-entered note on what's being charged). Null for every other
  /// fee, and for legacy fee lines written before this field existed.
  final String? description;

  const FeeLineEntity({
    required this.id,
    required this.name,
    this.amount = 0,
    this.description,
  });

  FeeLineEntity copyWith({
    String? id,
    String? name,
    double? amount,
    String? description,
  }) {
    return FeeLineEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }

  /// Label for itemized display: `"$name — $description"` when [description]
  /// is set (non-null, non-blank); otherwise just [name]. Used everywhere a
  /// fee line is itemized (cart row, receipt, sale detail).
  String get displayLabel {
    final d = description?.trim();
    if (d == null || d.isEmpty) return name;
    return '$name — $d';
  }

  @override
  List<Object?> get props => [id, name, amount, description];

  @override
  String toString() {
    return 'FeeLineEntity(id: $id, name: $name, amount: $amount, '
        'description: $description)';
  }
}
