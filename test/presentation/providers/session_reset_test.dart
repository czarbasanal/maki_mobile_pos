import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/session_reset_provider.dart';

UserEntity _admin() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

const _item = SaleItemEntity(
  id: 'i-1',
  productId: 'p-1',
  sku: 'SKU-1',
  name: 'Widget',
  unitPrice: 10,
  unitCost: 5,
  quantity: 1,
);

DraftEntity _draft() => DraftEntity(
      id: 'd-1',
      name: 'Table 9',
      items: const [_item],
      discountType: DiscountType.amount,
      createdBy: 'u1',
      createdByName: 'Admin',
      createdAt: DateTime(2026, 6, 1, 9),
    );

void main() {
  test('clears cart + selected draft when the user signs out', () async {
    final auth = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWith((ref) => auth.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider); // activate the listener
    container.listen(currentUserProvider, (_, __) {}); // keep auth subscribed

    auth.add(_admin());
    await Future<void>.delayed(Duration.zero);

    container.read(cartProvider.notifier).addItem(_item);
    container.read(selectedDraftProvider.notifier).state = _draft();
    expect(container.read(cartProvider).isNotEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNotNull);

    auth.add(null); // sign out
    await Future<void>.delayed(Duration.zero);

    expect(container.read(cartProvider).isEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNull);
  });

  test('does NOT reset on initial sign-in (null -> user)', () async {
    final auth = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWith((ref) => auth.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider);
    container.listen(currentUserProvider, (_, __) {});

    container.read(cartProvider.notifier).addItem(_item); // cart built pre-auth
    auth.add(_admin());
    await Future<void>.delayed(Duration.zero);

    // Signing IN must not wipe a cart.
    expect(container.read(cartProvider).isNotEmpty, isTrue);
  });
}
