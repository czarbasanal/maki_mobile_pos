import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

/// Counts reads so the test can prove the provider refetches rather than
/// serving a value it computed earlier in the session.
class _CountingSaleRepository implements SaleRepository {
  int getByIdCalls = 0;
  PaymentMethod method;
  _CountingSaleRepository(this.method);

  @override
  Future<SaleEntity?> getSaleById(String saleId) async {
    getByIdCalls += 1;
    return SaleEntity(
      id: saleId,
      saleNumber: 'SALE-1',
      items: const [],
      paymentMethod: method,
      amountReceived: 285,
      changeGiven: 0,
      status: SaleStatus.completed,
      cashierId: 'u',
      cashierName: 'U',
      createdAt: DateTime(2026, 8, 28),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a sale detail refetches instead of serving a stale session value',
      () async {
    // A sale corrected out-of-band (another device, or a back-office fix) used
    // to keep showing its old payment method until the app was restarted,
    // because this provider was not autoDispose and kept the first result for
    // the life of the ProviderContainer.
    final repo = _CountingSaleRepository(PaymentMethod.gcash);
    final container = ProviderContainer(
      overrides: [saleRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    var sub = container.listen(saleByIdProvider('s1'), (_, __) {});
    final first = await container.read(saleByIdProvider('s1').future);
    expect(first!.paymentMethod, PaymentMethod.gcash);
    expect(repo.getByIdCalls, 1);
    sub.close();
    // autoDispose tears down on a later microtask, not synchronously.
    await Future<void>.delayed(Duration.zero);

    // The record changes elsewhere.
    repo.method = PaymentMethod.mixed;

    sub = container.listen(saleByIdProvider('s1'), (_, __) {});
    final second = await container.read(saleByIdProvider('s1').future);
    sub.close();

    expect(repo.getByIdCalls, 2, reason: 'must re-read, not reuse the cached value');
    expect(second!.paymentMethod, PaymentMethod.mixed);
  });
}
