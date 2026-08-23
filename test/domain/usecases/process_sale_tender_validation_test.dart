import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';

class _MockSaleRepo extends Mock implements SaleRepository {}

class _MockActivityLogRepo extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

class _MockProductRepo extends Mock implements ProductRepository {}

class _MockJobOrderRepo extends Mock implements JobOrderRepository {}

class _FakeSale extends Fake implements SaleEntity {}

SaleItemEntity _item() => SaleItemEntity(
      id: 'i',
      productId: 'p',
      sku: 'S',
      name: 'N',
      unitPrice: 1000,
      unitCost: 0,
      quantity: 1,
    );

SaleEntity _salmonSale() => SaleEntity(
      id: '', saleNumber: '', items: [_item()],
      paymentMethod: PaymentMethod.salmon,
      tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 600},
      amountReceived: 400, // only downpayment collected
      changeGiven: 0,
      cashierId: 'c', cashierName: 'C', createdAt: DateTime(2026, 5, 28),
    );

UserEntity _actor() => UserEntity(
      id: 'u-1',
      email: 'u@test',
      displayName: 'U',
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  setUpAll(() => registerFallbackValue(_FakeSale()));

  late _MockSaleRepo sales;
  late _MockProductRepo products;
  late _MockJobOrderRepo jobOrders;
  late ProcessSaleUseCase useCase;

  setUp(() {
    sales = _MockSaleRepo();
    products = _MockProductRepo();
    jobOrders = _MockJobOrderRepo();
    final logRepo = _MockActivityLogRepo();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = ProcessSaleUseCase(
      saleRepository: sales,
      productRepository: products,
      jobOrderRepository: jobOrders,
      logger: ActivityLogger(logRepo),
    );
    when(() => sales.generateSaleNumber(any()))
        .thenAnswer((_) async => 'SALE-1');
    when(() => sales.createSale(any(),
        id: any(named: 'id'),
        decrementStock:
            any(named: 'decrementStock'))).thenAnswer((inv) async =>
        (inv.positionalArguments.first as SaleEntity).copyWith(id: 'sale-1'));
    when(() => products.getProductById(any())).thenAnswer((_) async => null);
    when(() => sales.getSaleById(any())).thenAnswer((_) async => null);
  });

  test('salmon sale (collected < grandTotal) is accepted', () async {
    final result = await useCase.execute(
      actor: _actor(),
      sale: _salmonSale(),
      checkoutId: 'chk-test',
      updateInventory: false,
    );
    expect(result.success, true, reason: result.errorMessage);
  });

  test('a tender breakdown that does not reconcile is rejected', () async {
    final bad = _salmonSale().copyWith(
      tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 100},
    );
    final result = await useCase.execute(
        actor: _actor(), sale: bad, checkoutId: 'chk-test', updateInventory: false);
    expect(result.success, false);
  });
}
