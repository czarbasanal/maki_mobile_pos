import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

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
  setUpAll(() => registerFallbackValue(_FakeVoidRequest()));

  late _MockVoidRequestRepository repo;
  late RequestVoidSaleUseCase useCase;

  setUp(() {
    repo = _MockVoidRequestRepository();
    useCase = RequestVoidSaleUseCase(repository: repo);
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
}
