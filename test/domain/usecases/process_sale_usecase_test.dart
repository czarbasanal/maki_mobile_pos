import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockDraftRepository extends Mock implements DraftRepository {}

class _FakeSaleEntity extends Fake implements SaleEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSaleEntity());
  });

  late ProcessSaleUseCase useCase;
  late MockSaleRepository mockSaleRepo;
  late MockProductRepository mockProductRepo;
  late MockDraftRepository mockDraftRepo;

  setUp(() {
    mockSaleRepo = MockSaleRepository();
    mockProductRepo = MockProductRepository();
    mockDraftRepo = MockDraftRepository();

    useCase = ProcessSaleUseCase(
      saleRepository: mockSaleRepo,
      productRepository: mockProductRepo,
      draftRepository: mockDraftRepo,
    );
    // Idempotency pre-check defaults to "no existing sale" unless a test
    // overrides it for a specific checkout id.
    when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => null);
  });

  SaleEntity createTestSale({
    String id = '',
    String saleNumber = '',
    List<SaleItemEntity>? items,
    double amountReceived = 200,
  }) {
    return SaleEntity(
      id: id,
      saleNumber: saleNumber,
      items: items ??
          const [
            SaleItemEntity(
              id: 'item-1',
              productId: 'prod-1',
              sku: 'SKU-001',
              name: 'Test Product',
              unitPrice: 100.0,
              unitCost: 60.0,
              quantity: 2,
            ),
          ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: amountReceived,
      changeGiven: amountReceived - 200,
      cashierId: 'cashier-1',
      cashierName: 'John Doe',
      createdAt: DateTime.now(),
    );
  }

  group('ProcessSaleUseCase', () {
    test('short-circuits when a sale already exists for the checkout id',
        () async {
      final sale = createTestSale();
      final existing = sale.copyWith(id: 'chk-1', saleNumber: 'SALE-001');
      when(() => mockSaleRepo.getSaleById('chk-1'))
          .thenAnswer((_) async => existing);

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-1');

      expect(result.success, isTrue);
      expect(result.sale!.id, 'chk-1');
      verifyNever(() => mockSaleRepo.createSale(any(), id: any(named: 'id')));
      verifyNever(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('DuplicateSaleException from createSale returns the existing sale',
        () async {
      final sale = createTestSale();
      final existing = sale.copyWith(id: 'chk-2', saleNumber: 'SALE-002');
      var getCalls = 0;
      when(() => mockSaleRepo.getSaleById('chk-2')).thenAnswer((_) async {
        getCalls++;
        return getCalls == 1 ? null : existing; // pre-check null, catch → existing
      });
      when(() => mockSaleRepo.createSale(any(), id: any(named: 'id')))
          .thenThrow(const DuplicateSaleException());
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-2');

      expect(result.success, isTrue);
      expect(result.sale!.id, 'chk-2');
      verifyNever(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('should return success when sale is valid', () async {
      final sale = createTestSale();
      final createdSale = sale.copyWith(id: 'sale-123', saleNumber: 'SALE-001');

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-001');
      when(() => mockSaleRepo.createSale(any(), id: any(named: 'id')))
          .thenAnswer((_) async => createdSale);
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => ProductEntity(
                id: 'prod-1',
                sku: 'SKU-001',
                name: 'Test Product',
                costCode: 'NBF',
                cost: 60,
                price: 100,
                quantity: 100,
                reorderLevel: 10,
                unit: 'pcs',
                isActive: true,
                createdAt: DateTime.now(),
              ));
      when(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).thenAnswer((_) async => ProductEntity(
            id: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            costCode: 'NBF',
            cost: 60,
            price: 100,
            quantity: 98,
            reorderLevel: 10,
            unit: 'pcs',
            isActive: true,
            createdAt: DateTime.now(),
          ));

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-test');

      expect(result.success, true);
      expect(result.sale, isNotNull);
      expect(result.sale!.saleNumber, 'SALE-001');

      // Stock must be DECREMENTED by exactly the qty sold (negative change).
      // A regression that increments on sale would otherwise pass.
      verify(() => mockProductRepo.updateStock(
            productId: 'prod-1',
            quantityChange: -2,
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).called(1);
    });

    test('should fail when cart is empty', () async {
      final sale = createTestSale(items: []);

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-test');

      expect(result.success, false);
      expect(result.errorMessage, contains('empty'));
    });

    test('should fail when the tender breakdown does not reconcile', () async {
      // Tenders sum to 100 but the grand total is 200.
      final sale = createTestSale()
          .copyWith(tenders: const {PaymentMethod.cash: 100});

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-test');

      expect(result.success, false);
      expect(result.errorMessage, contains('Payment'));
    });

    test('labor lines do not deduct inventory (only items are stocked)',
        () async {
      // grandTotal = parts(200) + labor(450) = 650; tenders must reconcile.
      final sale = createTestSale(amountReceived: 650).copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Engine tune-up', fee: 450),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        tenders: const {PaymentMethod.cash: 650},
      );

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-002');
      when(() => mockSaleRepo.createSale(any(), id: any(named: 'id')))
          .thenAnswer((inv) async =>
              (inv.positionalArguments.first as SaleEntity)
                  .copyWith(id: 'sale-200', saleNumber: 'SALE-002'));
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => ProductEntity(
                id: 'prod-1',
                sku: 'SKU-001',
                name: 'Test Product',
                costCode: 'NBF',
                cost: 60,
                price: 100,
                quantity: 100,
                reorderLevel: 10,
                unit: 'pcs',
                isActive: true,
                createdAt: DateTime.now(),
              ));
      when(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).thenAnswer((_) async => ProductEntity(
            id: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            costCode: 'NBF',
            cost: 60,
            price: 100,
            quantity: 98,
            reorderLevel: 10,
            unit: 'pcs',
            isActive: true,
            createdAt: DateTime.now(),
          ));

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-test');

      expect(result.success, true, reason: result.errorMessage);
      expect(result.sale!.laborSubtotal, 450);
      expect(result.sale!.grandTotal, 650);

      // The single part (qty 2) must be decremented exactly once.
      // Labor has no productId — it must never touch updateStock.
      verify(() => mockProductRepo.updateStock(
            productId: 'prod-1',
            quantityChange: -2,
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).called(1);
      // Note: getProductById is also called (inventory availability check),
      // so verifyNoMoreInteractions is intentionally omitted here.
    });
  });
}
