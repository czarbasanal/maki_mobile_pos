import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

class _MockVoidSaleUseCase extends Mock implements VoidSaleUseCase {}

class _FakeUser extends Fake implements UserEntity {}

UserEntity _user(UserRole role) => UserEntity(
    id: 'u-${role.value}',
    email: '${role.value}@test',
    displayName: '${role.value} user',
    role: role,
    isActive: true,
    createdAt: DateTime(2025, 1, 1));

VoidRequestEntity _req() => VoidRequestEntity(
    id: 'vr-1',
    saleId: 's-1',
    saleNumber: 'SALE-0042',
    saleGrandTotal: 100,
    requestedBy: 'u-cashier',
    requestedByName: 'cashier user',
    requestedByRole: 'cashier',
    reason: 'wrong item',
    createdAt: DateTime(2025, 1, 1));

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUser());
    registerFallbackValue(VoidRequestStatus.pending);
  });

  late _MockVoidRequestRepository repo;
  late _MockVoidSaleUseCase voidSale;
  late ApproveVoidRequestUseCase useCase;

  setUp(() {
    repo = _MockVoidRequestRepository();
    voidSale = _MockVoidSaleUseCase();
    useCase =
        ApproveVoidRequestUseCase(repository: repo, voidSaleUseCase: voidSale);
    when(() => repo.resolve(
          requestId: any(named: 'requestId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        )).thenAnswer((_) async {});
  });

  test('admin approval voids the sale then marks approved', () async {
    when(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: any(named: 'saleId'),
          password: any(named: 'password'),
          reason: any(named: 'reason'),
          voidedBy: any(named: 'voidedBy'),
          voidedByName: any(named: 'voidedByName'),
        )).thenAnswer((_) async => const VoidSaleResult(success: true));

    final result = await useCase.execute(
        actor: _user(UserRole.admin), request: _req(), password: 'pw');

    expect(result.success, isTrue);
    verify(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: 's-1',
          password: 'pw',
          reason: 'wrong item',
          voidedBy: 'u-admin',
          voidedByName: 'admin user',
        )).called(1);
    verify(() => repo.resolve(
          requestId: 'vr-1',
          status: VoidRequestStatus.approved,
          resolvedBy: 'u-admin',
          resolvedByName: 'admin user',
          rejectionReason: null,
        )).called(1);
  });

  test('if the void throws, request is not marked approved', () async {
    when(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: any(named: 'saleId'),
          password: any(named: 'password'),
          reason: any(named: 'reason'),
          voidedBy: any(named: 'voidedBy'),
          voidedByName: any(named: 'voidedByName'),
        )).thenThrow(const VoidSaleException(
        message: 'Invalid password', code: 'invalid-password'));

    final result = await useCase.execute(
        actor: _user(UserRole.admin), request: _req(), password: 'bad');

    expect(result.success, isFalse);
    verifyNever(() => repo.resolve(
          requestId: any(named: 'requestId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        ));
  });

  test('cashier denied', () async {
    final result = await useCase.execute(
        actor: _user(UserRole.cashier), request: _req(), password: 'pw');
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
  });
}
