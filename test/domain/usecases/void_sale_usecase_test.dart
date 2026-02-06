import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late VoidSaleUseCase useCase;
  late MockSaleRepository mockSaleRepo;
  late MockProductRepository mockProductRepo;
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockSaleRepo = MockSaleRepository();
    mockProductRepo = MockProductRepository();
    mockAuthRepo = MockAuthRepository();

    useCase = VoidSaleUseCase(
      saleRepository: mockSaleRepo,
      productRepository: mockProductRepo,
      authRepository: mockAuthRepo,
    );
  });

  SaleEntity createTestSale({
    SaleStatus status = SaleStatus.completed,
  }) {
    return SaleEntity(
      id: 'sale-1',
      saleNumber: 'SALE-001',
      items: const [
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
      amountReceived: 200.0,
      changeGiven: 0,
      status: status,
      cashierId: 'cashier-1',
      cashierName: 'John Doe',
      createdAt: DateTime.now(),
    );
  }

  group('VoidSaleUseCase', () {
    test('should void sale successfully', () async {
      final sale = createTestSale();
      final voidedSale = sale.void_(
        voidedById: 'admin-1',
        voidedByUserName: 'Admin User',
        reason: 'Customer refund request',
      );

      when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => true);
      when(() => mockSaleRepo.voidSale(
            saleId: any(named: 'saleId'),
            voidedBy: any(named: 'voidedBy'),
            voidedByName: any(named: 'voidedByName'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => voidedSale);
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
            quantity: 102,
            reorderLevel: 10,
            unit: 'pcs',
            isActive: true,
            createdAt: DateTime.now(),
          ));

      final result = await useCase.execute(
        saleId: 'sale-1',
        password: 'admin123',
        reason: 'Customer refund request',
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
      );

      expect(result.success, true);
      expect(result.sale?.status, SaleStatus.voided);
    });

    test('should fail with invalid password', () async {
      final sale = createTestSale();

      when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => false);

      expect(
        () => useCase.execute(
          saleId: 'sale-1',
          password: 'wrong',
          reason: 'Test reason',
          voidedBy: 'admin-1',
          voidedByName: 'Admin User',
        ),
        throwsA(isA<VoidSaleException>()),
      );
    });

    test('should fail if sale already voided', () async {
      final sale = createTestSale(status: SaleStatus.voided);

      when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => true);

      expect(
        () => useCase.execute(
          saleId: 'sale-1',
          password: 'admin123',
          reason: 'Test reason',
          voidedBy: 'admin-1',
          voidedByName: 'Admin User',
        ),
        throwsA(isA<VoidSaleException>()),
      );
    });

    test('should fail with empty reason', () async {
      expect(
        () => useCase.execute(
          saleId: 'sale-1',
          password: 'admin123',
          reason: '',
          voidedBy: 'admin-1',
          voidedByName: 'Admin User',
        ),
        throwsA(isA<VoidSaleException>()),
      );
    });
  });
}
