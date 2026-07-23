import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/session_reset_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

class _MockProductRepository extends Mock implements ProductRepository {}

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
      overrides: [
        currentUserProvider.overrideWith((ref) => auth.stream),
        receivingRepositoryProvider
            .overrideWith((ref) => _MockReceivingRepository()),
        productRepositoryProvider
            .overrideWith((ref) => _MockProductRepository()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider); // activate the listener
    container.listen(currentUserProvider, (_, __) {}); // keep auth subscribed

    auth.add(_admin());
    await Future<void>.delayed(Duration.zero);

    container.read(cartProvider.notifier).addItem(_item);
    container.read(selectedDraftProvider.notifier).state = _draft();
    container.read(inventoryStateProvider.notifier)
      ..setSearchQuery('brake')
      ..setCategoryFilter('Brakes')
      ..toggleCostVisibility(true);
    container.read(currentReceivingProvider.notifier).addItem(
          const ReceivingItemEntity(
            id: 'r-1',
            productId: 'p-1',
            sku: 'SKU-1',
            name: 'Widget',
            quantity: 3,
            unit: 'pcs',
            unitCost: 5,
            costCode: 'NBF',
          ),
        );
    expect(container.read(cartProvider).isNotEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNotNull);
    expect(container.read(inventoryStateProvider).searchQuery, 'brake');
    expect(container.read(currentReceivingProvider).items, isNotEmpty);

    auth.add(null); // sign out
    await Future<void>.delayed(Duration.zero);

    expect(container.read(cartProvider).isEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNull);
    final inv = container.read(inventoryStateProvider);
    expect(inv.searchQuery, isEmpty);
    expect(inv.categoryFilter, isNull);
    expect(inv.showCost, isFalse);
    expect(container.read(currentReceivingProvider).items, isEmpty);
  });

  test('does NOT reset across a signed-out-at-boot -> sign-in transition',
      () async {
    final auth = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => auth.stream),
        receivingRepositoryProvider
            .overrideWith((ref) => _MockReceivingRepository()),
        productRepositoryProvider
            .overrideWith((ref) => _MockProductRepository()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider);
    container.listen(currentUserProvider, (_, __) {});

    container.read(cartProvider.notifier).addItem(_item); // cart built pre-auth

    auth.add(null); // signed out at boot (AsyncData(null), not just loading)
    await Future<void>.delayed(Duration.zero);
    auth.add(_admin()); // then signs in
    await Future<void>.delayed(Duration.zero);

    // Neither the loading->null nor the null->user transition is a sign-out,
    // so the cart must survive both.
    expect(container.read(cartProvider).isNotEmpty, isTrue);
  });
}
