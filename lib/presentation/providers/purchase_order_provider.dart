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
  final bool capped;
  const ReorderResult({required this.suggestions, required this.capped});
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
  return ReorderResult(
    suggestions:
        computeReorderSuggestions(products, unitsSoldByProduct(sales), params),
    capped: sales.length >= reorderSalesCap,
  );
});
