import 'package:equatable/equatable.dart';

/// One way a product may be sold — a label, how many pieces of stock it
/// consumes, and the price of the whole set.
///
/// Options are optional and per-product. A product with no options sells at
/// its own [ProductEntity.price] per piece, exactly as before this existed.
/// A product WITH options can only be sold through one of them.
///
/// Distinct from the cost-variation mechanism (`ABC-1`, `ABC-2`), which
/// creates separate product docs. Options never split stock.
class SellingOptionEntity extends Equatable {
  /// Stable id, generated once at creation and never reused. Sale lines
  /// snapshot it so a later edit or deletion can't rewrite history.
  final String id;

  /// What the cashier sees, e.g. "By 6".
  final String label;

  /// How many pieces of stock this option consumes.
  final int pieces;

  /// Price of the WHOLE set, not per piece.
  final double price;

  const SellingOptionEntity({
    required this.id,
    required this.label,
    required this.pieces,
    required this.price,
  });

  /// Derived per-piece price. Shown as a caption in the picker so a
  /// mis-typed set price is obvious at the point of sale.
  double get pricePerPiece => pieces == 0 ? 0 : price / pieces;

  SellingOptionEntity copyWith({
    String? id,
    String? label,
    int? pieces,
    double? price,
  }) {
    return SellingOptionEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      pieces: pieces ?? this.pieces,
      price: price ?? this.price,
    );
  }

  @override
  List<Object?> get props => [id, label, pieces, price];

  @override
  String toString() =>
      'SellingOptionEntity(id: $id, label: $label, pieces: $pieces, price: $price)';
}
