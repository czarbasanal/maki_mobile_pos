import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockJobOrderRepository extends Mock implements JobOrderRepository {}

class MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _cashier() => UserEntity(
      id: 'cashier-1',
      email: 'c@test',
      displayName: 'John Doe',
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

class _FakeSaleEntity extends Fake implements SaleEntity {}

class _FakeJobOrderEntity extends Fake implements JobOrderEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  setUpAll(() {
    registerFallbackValue(_FakeSaleEntity());
  });

  late ProcessSaleUseCase useCase;
  late MockSaleRepository mockSaleRepo;
  late MockProductRepository mockProductRepo;
  late MockJobOrderRepository mockJobOrderRepo;
  late MockActivityLogRepository mockLogRepo;

  setUp(() {
    mockSaleRepo = MockSaleRepository();
    mockProductRepo = MockProductRepository();
    mockJobOrderRepo = MockJobOrderRepository();

    mockLogRepo = MockActivityLogRepository();
    when(() => mockLogRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = ProcessSaleUseCase(
      saleRepository: mockSaleRepo,
      productRepository: mockProductRepo,
      jobOrderRepository: mockJobOrderRepo,
      logger: ActivityLogger(mockLogRepo),
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
    test(
        'a duplicate checkout returns the existing sale without re-subtracting '
        'stock', () async {
      final sale = createTestSale();
      final existing = sale.copyWith(id: 'chk-1', saleNumber: 'SALE-001');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DuplicateSaleException());
      when(() => mockSaleRepo.getSaleById('chk-1'))
          .thenAnswer((_) async => existing);
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-1');

      expect(result.success, isTrue);
      expect(result.sale!.id, 'chk-1');
      verifyNever(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test(
        'a duplicate whose sale cannot be reloaded fails safely (no phantom '
        'success)', () async {
      final sale = createTestSale();
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DuplicateSaleException());
      when(() => mockSaleRepo.getSaleById(any()))
          .thenThrow(Exception('read failed'));
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-x');

      expect(result.success, isFalse);
      expect(result.sale, isNull);
    });

    test(
        'a duplicate jobOrder-sourced checkout still marks the jobOrder converted',
        () async {
      final sale = createTestSale().copyWith(jobOrderId: 'jobOrder-9');
      final existing = sale.copyWith(id: 'chk-3', saleNumber: 'SALE-003');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DuplicateSaleException());
      when(() => mockSaleRepo.getSaleById('chk-3'))
          .thenAnswer((_) async => existing);
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockJobOrderRepo.markJobOrderAsConverted(
            jobOrderId: any(named: 'jobOrderId'),
            saleId: any(named: 'saleId'),
          )).thenThrow(Exception('ignored')); // caught; we verify the attempt

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-3');

      expect(result.success, isTrue);
      verify(() => mockJobOrderRepo.markJobOrderAsConverted(
            jobOrderId: 'jobOrder-9',
            saleId: 'chk-3',
          )).called(1);
    });

    test('should return success when sale is valid', () async {
      final sale = createTestSale();
      final createdSale = sale.copyWith(id: 'sale-123', saleNumber: 'SALE-001');

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-001');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
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
      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-test');

      expect(result.success, true);
      expect(result.sale, isNotNull);
      expect(result.sale!.saleNumber, 'SALE-001');

      // Stock is subtracted inside createSale's transaction now
      // (decrementStock true), not via a separate updateStock call.
      verify(() => mockSaleRepo.createSale(any(),
          id: any(named: 'id'), decrementStock: true)).called(1);
    });

    test('should fail when cart is empty', () async {
      final sale = createTestSale(items: []);

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-test');

      expect(result.success, false);
      expect(result.errorMessage, contains('empty'));
    });

    test('a fee-only sale (no items, one or more fee lines) passes validation',
        () async {
      // grandTotal = feesTotal(50) only; tenders must reconcile.
      final sale = createTestSale(items: [], amountReceived: 50).copyWith(
        feeLines: const [
          FeeLineEntity(id: 'fee-1', name: 'Electric charge', amount: 50),
        ],
        tenders: const {PaymentMethod.cash: 50},
      );

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-003');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenAnswer((inv) async =>
              (inv.positionalArguments.first as SaleEntity)
                  .copyWith(id: 'sale-300', saleNumber: 'SALE-003'));

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-fee');

      expect(result.success, true, reason: result.errorMessage);
      expect(result.sale!.feesTotal, 50);
      expect(result.sale!.grandTotal, 50);
      verifyNever(() => mockProductRepo.getProductById(any()));
    });

    // "truly-empty sale still throws" is already covered by 'should fail
    // when cart is empty' above (items: [], feeLines: []).

    test(
        'a labor-only sale (no items, no fee lines, labor only) passes '
        'validation', () async {
      // Policy change: labor alone is billable — items OR labor OR fees.
      // grandTotal = laborRevenue(450) only; tenders must reconcile.
      final sale = createTestSale(items: [], amountReceived: 450).copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Engine tune-up', fee: 450),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        tenders: const {PaymentMethod.cash: 450},
      );

      when(() => mockSaleRepo.generateSaleNumber(any()))
          .thenAnswer((_) async => 'SALE-004');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenAnswer((inv) async =>
              (inv.positionalArguments.first as SaleEntity)
                  .copyWith(id: 'sale-400', saleNumber: 'SALE-004'));

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-labor');

      expect(result.success, true, reason: result.errorMessage);
      expect(result.sale!.laborRevenue, 450);
      expect(result.sale!.grandTotal, 450);
      verifyNever(() => mockProductRepo.getProductById(any()));
    });

    test('should fail when the tender breakdown does not reconcile', () async {
      // Tenders sum to 100 but the grand total is 200.
      final sale =
          createTestSale().copyWith(tenders: const {PaymentMethod.cash: 100});

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-test');

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
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
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
      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-test');

      expect(result.success, true, reason: result.errorMessage);
      expect(result.sale!.laborSubtotal, 450);
      expect(result.sale!.grandTotal, 650);

      // "Labor never moves stock" is now verified at the repo layer
      // (createSale iterates sale.items only); here we just confirm the sale
      // succeeds with labor priced in.
    });

    test('a fresh jobOrder-sourced sale marks the ticket converted on success',
        () async {
      final sale = createTestSale().copyWith(jobOrderId: 'jobOrder-9');
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenAnswer((_) async => sale.copyWith(id: 'sale-1'));
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockJobOrderRepo.markJobOrderAsConverted(
            jobOrderId: any(named: 'jobOrderId'),
            saleId: any(named: 'saleId'),
          )).thenAnswer((_) async => _FakeJobOrderEntity());

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-conv');

      expect(result.success, isTrue);
      verify(() => mockJobOrderRepo.markJobOrderAsConverted(
            jobOrderId: 'jobOrder-9',
            saleId: 'sale-1',
          )).called(1);
    });

    test(
        'a rules permission-denied on sale create surfaces the '
        'drawer-must-close message instead of the raw Firestore error',
        () async {
      final sale = createTestSale();
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DatabaseException(
        message: 'Failed to create sale: PERMISSION_DENIED: Missing or '
            'insufficient permissions.',
        code: 'permission-denied',
      ));

      final result =
          await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-blocked');

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        "Sale blocked: the previous day's drawer must be closed first.",
      );
    });

    test('a non-permission database error keeps its original message',
        () async {
      final sale = createTestSale();
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DatabaseException(
        message: 'Failed to create sale: network blip',
        code: 'unavailable',
      ));

      final result = await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-other');

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Failed to create sale: network blip');
    });

    test('a walk-in sale (no jobOrderId) converts nothing', () async {
      final sale = createTestSale();
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'),
              decrementStock: any(named: 'decrementStock')))
          .thenAnswer((_) async => sale.copyWith(id: 'sale-2'));
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);

      final result =
          await useCase.execute(actor: _cashier(), sale: sale, checkoutId: 'chk-walkin');

      expect(result.success, isTrue);
      verifyNever(() => mockJobOrderRepo.markJobOrderAsConverted(
            jobOrderId: any(named: 'jobOrderId'),
            saleId: any(named: 'saleId'),
          ));
    });
  });

  group('ProcessSaleUseCase activity logging', () {
    test('a completed sale writes a sale entry with number and amount',
        () async {
      final sale = createTestSale();
      // Unknown products only produce stock warnings; the sale still commits.
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'), decrementStock: any(named: 'decrementStock')))
          .thenAnswer((_) async => sale.copyWith(
                id: 'sale-9',
                saleNumber: 'SALE-0042',
              ));

      await useCase.execute(
          actor: _cashier(), sale: sale, checkoutId: 'chk-log');

      final logged = verify(() => mockLogRepo.logActivity(captureAny()))
          .captured
          .cast<ActivityLogEntity>()
          .where((e) => e.type == ActivityType.sale)
          .toList();
      expect(logged, hasLength(1));
      expect(logged.single.action, contains('SALE-0042'));
      expect(logged.single.entityId, 'sale-9');
    });

    test('a duplicate retry does not log the sale a second time', () async {
      // The retry path reloads the already-committed sale; logging there would
      // show one sale twice in the audit trail.
      final sale = createTestSale();
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);
      when(() => mockSaleRepo.createSale(any(),
              id: any(named: 'id'), decrementStock: any(named: 'decrementStock')))
          .thenThrow(const DuplicateSaleException(saleId: 'chk-dup'));
      when(() => mockSaleRepo.getSaleById('chk-dup'))
          .thenAnswer((_) async => sale.copyWith(id: 'chk-dup'));

      await useCase.execute(
          actor: _cashier(), sale: sale, checkoutId: 'chk-dup');

      verifyNever(() => mockLogRepo.logActivity(any()));
    });
  });
}
