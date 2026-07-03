import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/sale_status.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/purchase_order_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

final purchaseOrderRepositoryProvider =
    Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

/// Recent purchase orders, newest first. Status filtering is client-side —
/// shop volume is small and this avoids a composite index.
final purchaseOrdersProvider =
    StreamProvider.autoDispose<List<PurchaseOrderEntity>>((ref) {
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrders();
});

final purchaseOrderProvider =
    StreamProvider.autoDispose.family<PurchaseOrderEntity?, String>((ref, id) {
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

/// Movement data for a window: units sold per product + whether the sales
/// fetch hit [reorderSalesCap]. Carries the [windowDays] it was fetched for
/// so velocity math always divides by the window the numerator covers.
typedef ReorderMovement = ({
  int windowDays,
  Map<String, int> unitsSold,
  bool capped,
});

/// Keyed by windowDays ONLY — coverDays never affects the fetch, so cover
/// changes must not refetch.
///
/// The window is [windowDays] FULL days ending YESTERDAY: today's partial
/// day is excluded, so velocity always divides complete days and the cached
/// fetch stays correct for the whole day (only a screen left open past
/// midnight goes stale; autoDispose refetches on re-entry).
final reorderMovementProvider = FutureProvider.autoDispose
    .family<ReorderMovement, int>((ref, windowDays) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final sales = await ref.watch(saleRepositoryProvider).getSalesByDateRange(
        startDate: todayStart.subtract(Duration(days: windowDays)),
        // The repo normalizes endDate to endOfDay → yesterday 23:59:59.999.
        endDate: todayStart.subtract(const Duration(days: 1)),
        status: SaleStatus.completed,
        limit: reorderSalesCap,
      );
  return (
    windowDays: windowDays,
    unitsSold: unitsSoldByProduct(sales),
    capped: sales.length >= reorderSalesCap,
  );
});

/// Suggestions + low/out buckets for the given params — a pure synchronous
/// derivation over [productsProvider] and [reorderMovementProvider], so
/// cover-days changes recompute instantly without refetching sales.
final reorderSuggestionsProvider = Provider.autoDispose
    .family<AsyncValue<ReorderResult>, ReorderParams>((ref, params) {
  final productsAsync = ref.watch(productsProvider);
  final movementAsync = ref.watch(reorderMovementProvider(params.windowDays));

  return productsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (products) => movementAsync.whenData((movement) {
      // The window rides with the movement data, so the velocity denominator
      // can never drift from the window the units were fetched for.
      final suggestions = computeReorderSuggestions(
          products,
          movement.unitsSold,
          (windowDays: movement.windowDays, coverDays: params.coverDays));
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
        capped: movement.capped,
      );
    }),
  );
});
