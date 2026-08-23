import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

class _FakeVoidRequest extends Fake implements VoidRequestEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

SaleEntity _sale() => SaleEntity(
      id: 's-1',
      saleNumber: 'SALE-0042',
      items: const [
        SaleItemEntity(
          id: 'i-1',
          productId: 'p-1',
          sku: 'SKU-001',
          name: 'Test Product',
          unitPrice: 100.0,
          unitCost: 60.0,
          quantity: 1,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100.0,
      changeGiven: 0,
      cashierId: 'u-cashier',
      cashierName: 'cashier user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVoidRequest());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockVoidRequestRepository repo;
  late RequestVoidSaleUseCase useCase;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockVoidRequestRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = RequestVoidSaleUseCase(
        repository: repo, logger: ActivityLogger(logRepo));
    when(() => repo.hasPendingForSale(any())).thenAnswer((_) async => false);
    when(() => repo.createRequest(any())).thenAnswer(
        (inv) async => (inv.positionalArguments.first as VoidRequestEntity)
            .copyWith(id: 'vr-1'));
  });

  test('cashier creates a pending request', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isTrue);
    expect(result.data?.id, 'vr-1');
    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.saleId, 's-1');
    expect(captured.requestedBy, 'u-cashier');
    expect(captured.status, VoidRequestStatus.pending);
  });

  test('admin is denied (uses direct void, not requests)', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => repo.createRequest(any()));
  });

  test('empty reason is rejected', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: '   ',
    );
    expect(result.success, isFalse);
    expect(result.errorCode, 'reason-required');
    verifyNever(() => repo.createRequest(any()));
  });

  test('short admin-managed reason names are accepted', () async {
    // The dropdown submits admin-curated names which can legitimately be
    // short (e.g. 'Typo'); min-length only applies to free text in the form.
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'Typo',
    );
    expect(result.success, isTrue);
  });

  test('duplicate pending request is rejected', () async {
    when(() => repo.hasPendingForSale('s-1')).thenAnswer((_) async => true);
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isFalse);
    expect(result.errorCode, 'void-already-pending');
    verifyNever(() => repo.createRequest(any()));
  });

  test('void-request snapshot captures labor-inclusive grandTotal', () async {
    final saleWithLabor = _sale().copyWith(
      laborLines: const [
        LaborLineEntity(
          id: 'lab-1',
          description: 'Brake bleed',
          fee: 450,
        ),
      ],
      mechanicId: 'mech-1',
      mechanicName: 'Juan',
    );

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: saleWithLabor,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;

    // saleWithLabor.grandTotal = partsRevenue(100) + laborRevenue(450) = 550
    expect(captured.saleGrandTotal, saleWithLabor.grandTotal);
    expect(captured.saleGrandTotal, 550.0);
  });

  test('request stores an items summary built from the sale items',
      () async {
    final saleWithTwoItems = _sale().copyWith(items: const [
      SaleItemEntity(
        id: 'i-1',
        productId: 'p-1',
        sku: 'SKU-001',
        name: 'Brake Shoe',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 2,
      ),
      SaleItemEntity(
        id: 'i-2',
        productId: 'p-2',
        sku: 'SKU-002',
        name: 'Bulb',
        unitPrice: 20.0,
        unitCost: 10.0,
        quantity: 1,
      ),
    ]);

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: saleWithTwoItems,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.itemsSummary, '2× Brake Shoe, 1× Bulb');
  });

  test('items summary is truncated to 80 chars with an ellipsis', () async {
    final longNameSale = _sale().copyWith(items: const [
      SaleItemEntity(
        id: 'i-1',
        productId: 'p-1',
        sku: 'SKU-001',
        name: 'A Very Long Brake Component Name That Keeps Going On And On',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 1,
      ),
      SaleItemEntity(
        id: 'i-2',
        productId: 'p-2',
        sku: 'SKU-002',
        name: 'Another Long Part Name Appended To Push It Over The Limit',
        unitPrice: 20.0,
        unitCost: 10.0,
        quantity: 1,
      ),
    ]);

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: longNameSale,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.itemsSummary, isNotNull);
    expect(captured.itemsSummary!.length, 80);
    expect(captured.itemsSummary, endsWith('…'));
  });

  test('items summary of exactly 80 chars is not truncated', () async {
    final name80 = 'a' * 77; // 77 chars
    final saleWith80CharSummary = _sale().copyWith(items: [
      SaleItemEntity(
        id: 'i-1',
        productId: 'p-1',
        sku: 'SKU-001',
        name: name80,
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 1,
      ),
    ]);

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: saleWith80CharSummary,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    final expectedSummary = '1× $name80';
    expect(expectedSummary.length, 80);
    expect(captured.itemsSummary, expectedSummary);
    expect(captured.itemsSummary, isNot(endsWith('…')));
  });

  test('items summary of exactly 81 chars is truncated to 80 with ellipsis',
      () async {
    final name81 = 'a' * 78; // 78 chars
    final saleWith81CharSummary = _sale().copyWith(items: [
      SaleItemEntity(
        id: 'i-1',
        productId: 'p-1',
        sku: 'SKU-001',
        name: name81,
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 1,
      ),
    ]);

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: saleWith81CharSummary,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    final untruncatedSummary = '1× $name81';
    expect(untruncatedSummary.length, 81);
    expect(captured.itemsSummary!.length, 80);
    expect(captured.itemsSummary, endsWith('…'));
    expect(captured.itemsSummary,
        equals('${untruncatedSummary.substring(0, 79)}…'));
  });

  test('items summary falls back to "Service / labor" when items are empty',
      () async {
    final laborOnlySale = _sale().copyWith(
      items: const [],
      laborLines: const [
        LaborLineEntity(
          id: 'lab-1',
          description: 'Brake bleed',
          fee: 450,
        ),
      ],
      mechanicId: 'mech-1',
      mechanicName: 'Juan',
    );

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: laborOnlySale,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.itemsSummary, 'Service / labor');
  });

  test('items summary is null when both items and labor are empty',
      () async {
    final emptySale = _sale().copyWith(items: const []);

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: emptySale,
      reason: 'wrong item rung up',
    );

    expect(result.success, isTrue);

    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.itemsSummary, isNull);
  });

  test('a created request writes a void_sale log entry', () async {
    when(() => repo.hasPendingForSale(any())).thenAnswer((_) async => false);
    when(() => repo.createRequest(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as VoidRequestEntity);

    await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'wrong item',
    );

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.voidSale)
        .toList();
    expect(logged, hasLength(1));
    expect(logged.single.action.toLowerCase(), contains('request'));
    expect(logged.single.details, contains('wrong item'));
  });
}
