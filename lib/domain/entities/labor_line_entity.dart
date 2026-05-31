import 'package:equatable/equatable.dart';

/// A single free-form labor/service charge on a draft, sale, or cart.
///
/// Labor is full price and is **never discounted** — it lives on a different
/// code path from item discounts (see spec decision #4). There is no cost
/// field: labor cost is always zero (pure margin).
class LaborLineEntity extends Equatable {
  /// Unique identifier for this labor line (uuid, like cart items).
  final String id;

  /// What was done, e.g. "Engine tune-up", "Brake bleed".
  final String description;

  /// Peso amount charged for this labor line. Full price, never discounted.
  final double fee;

  const LaborLineEntity({
    required this.id,
    required this.description,
    this.fee = 0,
  });

  LaborLineEntity copyWith({
    String? id,
    String? description,
    double? fee,
  }) {
    return LaborLineEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      fee: fee ?? this.fee,
    );
  }

  @override
  List<Object?> get props => [id, description, fee];

  @override
  String toString() {
    return 'LaborLineEntity(id: $id, description: $description, fee: $fee)';
  }
}
