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
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

/// Pinned instant: 12:00 shop time, far from any midnight so the window's
/// arithmetic never depends on when the suite is run.
final _fixedNow = DateTime.utc(2026, 8, 20, 4, 0);

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
      nowProvider.overrideWithValue(() => _fixedNow),
    ]);
    addTearDown(container.dispose);

    const params = (windowDays: 60, coverDays: 30);
    final sub =
        container.listen(reorderSuggestionsProvider(params), (_, __) {});
    addTearDown(sub.close);
    await container.read(productsProvider.future);
    await container.read(reorderMovementProvider(60).future);

    final result = container.read(reorderSuggestionsProvider(params)).value!;
    // velocity 1/day × 30 cover − 0 stock = 30
    expect(result.suggestions, hasLength(1));
    expect(result.suggestions.first.suggestedQty, 30);
    expect(result.capped, isFalse);
  });

  test('movement window is full days ending YESTERDAY — today excluded', () async {
    final saleRepo = _MockSaleRepository();
    when(() => saleRepo.getSalesByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          status: SaleStatus.completed,
          limit: reorderSalesCap,
        )).thenAnswer((_) async => []);

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value([product])),
      saleRepositoryProvider.overrideWithValue(saleRepo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      nowProvider.overrideWithValue(() => _fixedNow),
    ]);
    addTearDown(container.dispose);

    await container.read(reorderMovementProvider(60).future);

    final captured = verify(() => saleRepo.getSalesByDateRange(
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
          status: SaleStatus.completed,
          limit: reorderSalesCap,
        )).captured;
    final startDate = captured[0] as DateTime;
    final endDate = captured[1] as DateTime;

    // Asserted in SHOP days, not the machine's. The window moved to shop days
    // when the repository stopped re-deriving local ones, so comparing against
    // DateTime.now() made this pass or fail depending on the hour — the two
    // calendars disagree for six hours of every day on a non-PH machine.
    final shopToday = businessDateOf(_fixedNow, kDefaultShopOffsetMinutes);
    final shopTodayStart =
        shopDayStartInstant(shopToday, kDefaultShopOffsetMinutes);

    expect(endDate.isBefore(shopTodayStart), isTrue,
        reason: "today's partial day must not leak into velocity");
    expect(shopTodayStart.difference(startDate).inDays, 60,
        reason: '60 FULL days ending yesterday');
    // endDate is the last instant of yesterday, so the span is 59 whole days.
    expect(endDate.difference(startDate).inDays, 59);
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
      nowProvider.overrideWithValue(() => _fixedNow),
    ]);
    addTearDown(container.dispose);

    const params = (windowDays: 60, coverDays: 30);
    final sub =
        container.listen(reorderSuggestionsProvider(params), (_, __) {});
    addTearDown(sub.close);
    await container.read(productsProvider.future);
    await container.read(reorderMovementProvider(60).future);

    final result = container.read(reorderSuggestionsProvider(params)).value!;
    expect(result.suggestions.map((s) => s.product.id), ['sold']);
    expect(result.outOfStock.map((p) => p.id), ['empty']);
    expect(result.lowStock.map((p) => p.id), ['edge', 'low'],
        reason: 'sorted by name; boundary qty == reorderLevel counts as low');
  });
}
