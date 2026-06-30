import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/void_request_provider.dart';

class _MockRequestUseCase extends Mock implements RequestVoidSaleUseCase {}

class _MockApproveUseCase extends Mock implements ApproveVoidRequestUseCase {}

class _MockRejectUseCase extends Mock implements RejectVoidRequestUseCase {}

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

VoidRequestEntity _req() => VoidRequestEntity(
      id: 'vr-1',
      saleId: 's-1',
      saleNumber: 'SALE-0042',
      saleGrandTotal: 100,
      requestedBy: 'u-cashier',
      requestedByName: 'cashier user',
      requestedByRole: 'cashier',
      reason: 'wrong item',
      createdAt: DateTime(2025, 1, 1),
    );

/// Builds a container where no user is signed in (the auth stream never
/// emits), and the use-case providers are mocked so construction never
/// touches Firestore. This reproduces the auth-transition race where
/// `_requireUser()` finds a null user.
ProviderContainer _signedOutContainer() {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const Stream<UserEntity?>.empty(),
      ),
      requestVoidSaleUseCaseProvider.overrideWithValue(_MockRequestUseCase()),
      approveVoidRequestUseCaseProvider.overrideWithValue(_MockApproveUseCase()),
      rejectVoidRequestUseCaseProvider.overrideWithValue(_MockRejectUseCase()),
    ],
  );
}

void main() {
  group('VoidRequestOperationsNotifier — no signed-in user', () {
    test('requestVoid returns an error message instead of throwing uncaught',
        () async {
      final c = _signedOutContainer();
      addTearDown(c.dispose);
      final ops = c.read(voidRequestOperationsProvider.notifier);

      final result = await ops.requestVoid(sale: _sale(), reason: 'oops');

      expect(result, contains('not authenticated'),
          reason: 'a null-user race must surface as the UnauthenticatedException '
              'message, not a rejected Future that strands the dialog on "Sending…"');
    });

    test('approve returns an error message instead of throwing uncaught',
        () async {
      final c = _signedOutContainer();
      addTearDown(c.dispose);
      final ops = c.read(voidRequestOperationsProvider.notifier);

      final result = await ops.approve(request: _req(), password: 'pw');

      expect(result, contains('not authenticated'));
    });

    test('reject returns an error message instead of throwing uncaught',
        () async {
      final c = _signedOutContainer();
      addTearDown(c.dispose);
      final ops = c.read(voidRequestOperationsProvider.notifier);

      final result =
          await ops.reject(request: _req(), rejectionReason: 'no');

      expect(result, contains('not authenticated'));
    });
  });
}
