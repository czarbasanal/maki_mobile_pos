import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

void main() {
  ProductEntity makeProduct(String id,
          {int quantity = 0, int reorderLevel = 2, bool isActive = true}) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: quantity,
        reorderLevel: reorderLevel,
        unit: 'pcs',
        isActive: isActive,
        createdAt: DateTime(2026, 1, 1),
      );

  final product = makeProduct('p1');

  test('purchaseOrdersProvider streams from Firestore', () async {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    await container.read(purchaseOrderRepositoryProvider).createPurchaseOrder(
          PurchaseOrderEntity(
            id: '',
            referenceNumber: 'PO-20260703-001',
            items: const [],
            totalCost: 0,
            totalQuantity: 0,
            status: PurchaseOrderStatus.draft,
            createdAt: DateTime(2026, 7, 3),
            createdBy: 'u1',
            createdByName: 'Admin',
          ),
        );

    final list = await container.read(purchaseOrdersProvider.future);
    expect(list, hasLength(1));
    expect(list.first.referenceNumber, 'PO-20260703-001');
  });

  test('reorderSuggestionsProvider computes suggestions and cap flag',
      () async {
    final saleRepo = _MockSaleRepository();
    // 60 units sold in the window → velocity 1/day.
    final sale = SaleEntity(
      id: 's1',
      saleNumber: 'S-1',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          unitPrice: 80,
          unitCost: 55,
          quantity: 60,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      amountReceived: 4800,
      changeGiven: 0,
      cashierId: 'u1',
      cashierName: 'Admin',
      createdAt: DateTime(2026, 7, 1),
    );
    when(() => saleRepo.getSalesByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          status: SaleStatus.completed,
          limit: reorderSalesCap,
        )).thenAnswer((_) async => [sale]);

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value([product])),
      saleRepositoryProvider.overrideWithValue(saleRepo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
        reorderSuggestionsProvider((windowDays: 60, coverDays: 30)).future);
    // velocity 1/day × 30 cover − 0 stock = 30
    expect(result.suggestions, hasLength(1));
    expect(result.suggestions.first.suggestedQty, 30);
    expect(result.capped, isFalse);
  });

  test('buckets active non-suggested products into low/out of stock',
      () async {
    final saleRepo = _MockSaleRepository();
    // Only 'sold' has movement; everything else is zero-velocity.
    final sale = SaleEntity(
      id: 's1',
      saleNumber: 'S-1',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'sold',
          sku: 'SKU-sold',
          name: 'Item sold',
          unitPrice: 80,
          unitCost: 55,
          quantity: 60,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      amountReceived: 4800,
      changeGiven: 0,
      cashierId: 'u1',
      cashierName: 'Admin',
      createdAt: DateTime(2026, 7, 1),
    );
    when(() => saleRepo.getSalesByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          status: SaleStatus.completed,
          limit: reorderSalesCap,
        )).thenAnswer((_) async => [sale]);

    final products = [
      makeProduct('sold'), // suggested → excluded from buckets
      makeProduct('empty'), // qty 0 → out of stock
      makeProduct('low', quantity: 2, reorderLevel: 3), // 0<qty<=level → low
      makeProduct('edge', quantity: 3, reorderLevel: 3), // boundary → low
      makeProduct('fine', quantity: 9), // above level → neither
      makeProduct('dead', isActive: false), // inactive → neither
    ];

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value(products)),
      saleRepositoryProvider.overrideWithValue(saleRepo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
        reorderSuggestionsProvider((windowDays: 60, coverDays: 30)).future);
    expect(result.suggestions.map((s) => s.product.id), ['sold']);
    expect(result.outOfStock.map((p) => p.id), ['empty']);
    expect(result.lowStock.map((p) => p.id), ['edge', 'low'],
        reason: 'sorted by name; boundary qty == reorderLevel counts as low');
  });
}
