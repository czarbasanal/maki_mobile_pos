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

  const FeeLineEntity({
    required this.id,
    required this.name,
    this.amount = 0,
  });

  FeeLineEntity copyWith({
    String? id,
    String? name,
    double? amount,
  }) {
    return FeeLineEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }

  @override
  List<Object?> get props => [id, name, amount];

  @override
  String toString() {
    return 'FeeLineEntity(id: $id, name: $name, amount: $amount)';
  }
}
