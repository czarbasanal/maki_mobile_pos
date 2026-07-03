import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/sale_status.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/purchase_order_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

/// Recent purchase orders, newest first. Status filtering is client-side —
/// shop volume is small and this avoids a composite index.
final purchaseOrdersProvider =
    StreamProvider.autoDispose<List<PurchaseOrderEntity>>((ref) {
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrders();
});

final purchaseOrderProvider = StreamProvider.autoDispose
    .family<PurchaseOrderEntity?, String>((ref, id) {
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrderById(id);
});

/// Sales fetched for the movement window are capped; past the cap the
/// suggestions may under-count, so the UI shows an incompleteness note.
const int reorderSalesCap = 10000;

class ReorderResult {
  final List<ReorderSuggestion> suggestions;

  /// Active products at/below their reorder level (but not zero) that the
  /// velocity math did NOT recommend — zero-velocity items kept visible so
  /// dead-but-low stock can still be ordered. Sorted by name.
  final List<ProductEntity> lowStock;

  /// Active, zero-stock, non-recommended products. Sorted by name.
  final List<ProductEntity> outOfStock;
  final bool capped;

  const ReorderResult({
    required this.suggestions,
    this.lowStock = const [],
    this.outOfStock = const [],
    required this.capped,
  });
}

final reorderSuggestionsProvider = FutureProvider.autoDispose
    .family<ReorderResult, ReorderParams>((ref, params) async {
  final products = await ref.watch(productsProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: params.windowDays - 1));
  final sales = await ref.watch(saleRepositoryProvider).getSalesByDateRange(
        startDate: start,
        endDate: now,
        status: SaleStatus.completed,
        limit: reorderSalesCap,
      );
  final suggestions =
      computeReorderSuggestions(products, unitsSoldByProduct(sales), params);
  final suggestedIds = {for (final s in suggestions) s.product.id};
  final lowStock = <ProductEntity>[];
  final outOfStock = <ProductEntity>[];
  for (final product in products) {
    if (!product.isActive || suggestedIds.contains(product.id)) continue;
    if (product.quantity == 0) {
      outOfStock.add(product);
    } else if (product.quantity <= product.reorderLevel) {
      lowStock.add(product);
    }
  }
  int byName(ProductEntity a, ProductEntity b) => a.name.compareTo(b.name);
  lowStock.sort(byName);
  outOfStock.sort(byName);

  return ReorderResult(
    suggestions: suggestions,
    lowStock: lowStock,
    outOfStock: outOfStock,
    capped: sales.length >= reorderSalesCap,
  );
});
