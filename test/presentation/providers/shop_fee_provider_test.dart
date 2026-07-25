import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/shop_fee_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_fee_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_fee_provider.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ShopFeeRepository repo;

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        shopFeeRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      ],
    );
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = ShopFeeRepositoryImpl(firestore: fakeFirestore);
  });

  test('create then deactivate via the operations notifier', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Warm currentUserProvider so the notifier can resolve the actor.
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);

    final created = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    expect(created, isNotNull);
    expect(created!.id, isNotEmpty);
    expect(created.createdBy, 'admin-1');

    final ok = await ops.deactivate(created.id);
    expect(ok, true);

    final fetched = await repo.getShopFeeById(created.id);
    expect(fetched!.isActive, false);
  });

  test('create with a null defaultAmount (entered-at-register fee)', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);
    final created = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Misc Fee',
        defaultAmount: null,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    expect(created, isNotNull);
    expect(created!.defaultAmount, isNull);
  });

  test('activeShopFeesProvider emits only active shop fees', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);
    final disposal = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Battery Fee',
        defaultAmount: 10,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.deactivate(disposal!.id);

    final active = await container.read(activeShopFeesProvider.future);
    expect(active.map((f) => f.name), ['Battery Fee']);
  });

  test('allShopFeesProvider emits active + inactive', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);
    final disposal = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.deactivate(disposal!.id);

    final all = await container.read(allShopFeesProvider.future);
    expect(all.map((f) => f.name), ['Disposal Fee']);
    expect(all.first.isActive, false);
  });

  test('update via the operations notifier surfaces failures', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);
    await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    final other = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Battery Fee',
        defaultAmount: 10,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );

    final result = await ops.update(
      shopFee: other!.copyWith(name: 'Disposal Fee'),
    );
    expect(result, isNull);
    expect(container.read(shopFeeOperationsProvider).hasError, true);
  });

  test('reactivate via the operations notifier', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(shopFeeOperationsProvider.notifier);
    final created = await ops.create(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.deactivate(created!.id);

    final ok = await ops.reactivate(created.id);
    expect(ok, true);

    final fetched = await repo.getShopFeeById(created.id);
    expect(fetched!.isActive, true);
  });
}
