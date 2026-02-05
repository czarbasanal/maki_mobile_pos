import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockDraftRepository extends Mock implements DraftRepository {}

void main() {
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
    test('should return success when sale is valid', () async {
      final sale = createTestSale();
      final createdSale = sale.copyWith(id: 'sale-123', saleNumber: 'SALE-001');

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-001');
      when(() => mockSaleRepo.createSale(any()))
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

      final result = await useCase.execute(sale: sale);

      expect(result.success, true);
      expect(result.sale, isNotNull);
      expect(result.sale!.saleNumber, 'SALE-001');
    });

    test('should fail when cart is empty', () async {
      final sale = createTestSale(items: []);

      final result = await useCase.execute(sale: sale);

      expect(result.success, false);
      expect(result.errorMessage, contains('empty'));
    });

    test('should fail when payment is insufficient', () async {
      final sale = createTestSale(amountReceived: 100); // Less than 200 total

      final result = await useCase.execute(sale: sale);

      expect(result.success, false);
      expect(result.errorMessage, contains('Payment'));
    });
  });
}
