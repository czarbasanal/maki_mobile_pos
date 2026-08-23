import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late VoidSaleUseCase useCase;
  late MockSaleRepository mockSaleRepo;
  late MockProductRepository mockProductRepo;
  late MockAuthRepository mockAuthRepo;
  late MockActivityLogRepository mockLogRepo;

  setUp(() {
    mockSaleRepo = MockSaleRepository();
    mockProductRepo = MockProductRepository();
    mockAuthRepo = MockAuthRepository();
    mockLogRepo = MockActivityLogRepository();
    when(() => mockLogRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);

    useCase = VoidSaleUseCase(
      saleRepository: mockSaleRepo,
      productRepository: mockProductRepo,
      authRepository: mockAuthRepo,
      logger: ActivityLogger(mockLogRepo),
    );
  });

  /// Every log entry the use case wrote, by type.
  List<ActivityLogEntity> loggedOf(ActivityType type) =>
      verify(() => mockLogRepo.logActivity(captureAny()))
          .captured
          .cast<ActivityLogEntity>()
          .where((e) => e.type == type)
          .toList();

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
            updatedByName: any(named: 'updatedByName'),
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
        actor: _user(UserRole.admin),
        saleId: 'sale-1',
        password: 'admin123',
        reason: 'Customer refund request',
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
      );

      expect(result.success, true);
      expect(result.sale?.status, SaleStatus.voided);

      // Stock must be RESTORED on void: positive change equal to qty sold.
      // A regression that decrements again on void would otherwise pass.
      verify(() => mockProductRepo.updateStock(
            productId: 'prod-1',
            quantityChange: 2,
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).called(1);
    });

    test('non-admin actor is denied', () async {
      expect(
        () => useCase.execute(
          actor: _user(UserRole.cashier),
          saleId: 'sale-1',
          password: 'admin123',
          reason: 'Customer refund request',
          voidedBy: 'cashier-1',
          voidedByName: 'Cashier User',
        ),
        throwsA(isA<VoidSaleException>()),
      );
    });

    test('should fail with invalid password', () async {
      final sale = createTestSale();

      when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => false);

      expect(
        () => useCase.execute(
          actor: _user(UserRole.admin),
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
          actor: _user(UserRole.admin),
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
          actor: _user(UserRole.admin),
          saleId: 'sale-1',
          password: 'admin123',
          reason: '',
          voidedBy: 'admin-1',
          voidedByName: 'Admin User',
        ),
        throwsA(isA<VoidSaleException>()),
      );
    });

    test('labor lines are not restocked on void (only items restore stock)',
        () async {
      final sale = createTestSale().copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Brake bleed', fee: 300),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
      );
      final voidedSale = sale.void_(
        voidedById: 'admin-1',
        voidedByUserName: 'Admin User',
        reason: 'Customer refund request',
      );

      when(() => mockSaleRepo.getSaleById(any()))
          .thenAnswer((_) async => sale);
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
            updatedByName: any(named: 'updatedByName'),
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
        actor: _user(UserRole.admin),
        saleId: 'sale-1',
        password: 'admin123',
        reason: 'Customer refund request',
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
      );

      expect(result.success, true);

      // The single part (qty 2) must be restored exactly once (positive).
      // Labor has no productId — it must never trigger a restock.
      verify(() => mockProductRepo.updateStock(
            productId: 'prod-1',
            quantityChange: 2,
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).called(1);
      verifyNoMoreInteractions(mockProductRepo);
    });
  });

  group('VoidSaleUseCase activity logging', () {
    // The void is the shop's fraud-sensitive action; before this, a void from
    // the phone left NO trace in user_logs — the password check also bypassed
    // the logging wrapper, so not even a password event appeared.
    test('a successful void writes a void_sale entry with reason and amount',
        () async {
      final sale = createTestSale();
      final voidedSale = sale.void_(
        voidedById: 'admin-1',
        voidedByUserName: 'Admin User',
        reason: 'Wrong item',
      );
      when(() => mockSaleRepo.getSaleById('sale-1'))
          .thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => true);
      when(() => mockSaleRepo.voidSale(
            saleId: any(named: 'saleId'),
            voidedBy: any(named: 'voidedBy'),
            voidedByName: any(named: 'voidedByName'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => voidedSale);
      await useCase.execute(
        actor: _user(UserRole.admin),
        saleId: 'sale-1',
        password: 'pw',
        reason: 'Wrong item',
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
        restoreInventory: false,
      );

      final entries = loggedOf(ActivityType.voidSale);
      expect(entries, hasLength(1));
      expect(entries.single.action, contains('SALE-001'));
      expect(entries.single.details, contains('Wrong item'));
      expect(entries.single.entityId, 'sale-1');
    });

    test('the password check goes through the logging path — success', () async {
      final sale = createTestSale();
      when(() => mockSaleRepo.getSaleById('sale-1'))
          .thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => true);
      when(() => mockSaleRepo.voidSale(
            saleId: any(named: 'saleId'),
            voidedBy: any(named: 'voidedBy'),
            voidedByName: any(named: 'voidedByName'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => sale.void_(
            voidedById: 'admin-1',
            voidedByUserName: 'Admin User',
            reason: 'r',
          ));

      await useCase.execute(
        actor: _user(UserRole.admin),
        saleId: 'sale-1',
        password: 'pw',
        reason: 'r',
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
        restoreInventory: false,
      );

      expect(loggedOf(ActivityType.passwordVerified), hasLength(1));
    });

    test('a wrong password writes password_failed and never void_sale',
        () async {
      final sale = createTestSale();
      when(() => mockSaleRepo.getSaleById('sale-1'))
          .thenAnswer((_) async => sale);
      when(() => mockAuthRepo.verifyPassword(any()))
          .thenAnswer((_) async => false);

      await expectLater(
        useCase.execute(
          actor: _user(UserRole.admin),
          saleId: 'sale-1',
          password: 'wrong',
          reason: 'r',
          voidedBy: 'admin-1',
          voidedByName: 'Admin User',
        ),
        throwsA(isA<VoidSaleException>()),
      );

      final captured = verify(() => mockLogRepo.logActivity(captureAny()))
          .captured
          .cast<ActivityLogEntity>();
      expect(
          captured.where((e) => e.type == ActivityType.passwordFailed).length,
          1);
      expect(
          captured.where((e) => e.type == ActivityType.voidSale), isEmpty);
    });
  });
}
