import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Inventory valuation over whatever product list the screen is rendering.
class StockTotals {
  final double cost;
  final double retail;

  const StockTotals({required this.cost, required this.retail});

  double get profit => retail - cost;

  static StockTotals of(Iterable<ProductEntity> products) {
    var cost = 0.0;
    var retail = 0.0;
    for (final p in products) {
      cost += p.cost * p.quantity;
      retail += p.price * p.quantity;
    }
    return StockTotals(cost: cost, retail: retail);
  }
}
