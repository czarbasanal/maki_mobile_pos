import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/shop_fee_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ShopFeeRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = ShopFeeRepositoryImpl(firestore: fakeFirestore);
  });

  ShopFeeEntity newShopFee({String name = 'Environmental Fee', double? defaultAmount = 20}) =>
      ShopFeeEntity(
        id: '',
        name: name,
        defaultAmount: defaultAmount,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  group('ShopFeeRepositoryImpl', () {
    test('createShopFee assigns an id and stamps createdBy', () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(),
        createdBy: 'admin-1',
      );
      expect(created.id, isNotEmpty);
      expect(created.name, 'Environmental Fee');
      expect(created.defaultAmount, 20);
      expect(created.createdBy, 'admin-1');
    });

    test('createShopFee persists a null defaultAmount (entered at register)',
        () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(name: 'Misc Fee', defaultAmount: null),
        createdBy: 'admin-1',
      );
      expect(created.defaultAmount, isNull);

      final fetched = await repository.getShopFeeById(created.id);
      expect(fetched!.defaultAmount, isNull);
    });

    test('createShopFee throws DuplicateEntryException on existing name',
        () async {
      await repository.createShopFee(
        shopFee: newShopFee(name: 'Disposal Fee'),
        createdBy: 'admin-1',
      );
      expect(
        () => repository.createShopFee(
          shopFee: newShopFee(name: 'Disposal Fee'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('getShopFeeById returns the persisted shop fee', () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(),
        createdBy: 'admin-1',
      );
      final fetched = await repository.getShopFeeById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Environmental Fee');
    });

    test('getShopFeeById returns null when missing', () async {
      expect(await repository.getShopFeeById('nope'), isNull);
    });

    test('watchActive emits only active shop fees, A->Z', () async {
      final disposal = await repository.createShopFee(
        shopFee: newShopFee(name: 'Disposal Fee'),
        createdBy: 'admin-1',
      );
      await repository.createShopFee(
        shopFee: newShopFee(name: 'Battery Fee'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        shopFeeId: disposal.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final active = await repository.watchActive().first;
      expect(active.map((f) => f.name), ['Battery Fee']);
    });

    test('watchAll emits active + inactive sorted A->Z', () async {
      final disposal = await repository.createShopFee(
        shopFee: newShopFee(name: 'Disposal Fee'),
        createdBy: 'admin-1',
      );
      await repository.createShopFee(
        shopFee: newShopFee(name: 'Battery Fee'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        shopFeeId: disposal.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final all = await repository.watchAll().first;
      expect(all.map((f) => f.name), ['Battery Fee', 'Disposal Fee']);
    });

    test('updateShopFee persists the new name and amount', () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(),
        createdBy: 'admin-1',
      );
      final updated = await repository.updateShopFee(
        shopFee: created.copyWith(name: 'Green Fee', defaultAmount: 25),
        updatedBy: 'admin-2',
      );
      expect(updated.name, 'Green Fee');
      expect(updated.defaultAmount, 25);
      expect(updated.updatedBy, 'admin-2');
    });

    test('updateShopFee clears defaultAmount via clearDefaultAmount flag',
        () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(defaultAmount: 20),
        createdBy: 'admin-1',
      );
      final updated = await repository.updateShopFee(
        shopFee: created.copyWith(clearDefaultAmount: true),
        updatedBy: 'admin-2',
      );
      expect(updated.defaultAmount, isNull);

      final fetched = await repository.getShopFeeById(created.id);
      expect(fetched!.defaultAmount, isNull);
    });

    test('setActive deactivates a shop fee', () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        shopFeeId: created.id,
        active: false,
        updatedBy: 'admin-1',
      );
      final fetched = await repository.getShopFeeById(created.id);
      expect(fetched!.isActive, false);
    });

    test('nameExists honours excludeShopFeeId', () async {
      final created = await repository.createShopFee(
        shopFee: newShopFee(name: 'Disposal Fee'),
        createdBy: 'admin-1',
      );
      expect(await repository.nameExists(name: 'Disposal Fee'), true);
      expect(
        await repository.nameExists(
          name: 'Disposal Fee',
          excludeShopFeeId: created.id,
        ),
        false,
      );
      expect(await repository.nameExists(name: 'Ghost Fee'), false);
    });

    test('nameExists is case-insensitive', () async {
      await repository.createShopFee(
        shopFee: newShopFee(name: 'Disposal Fee'),
        createdBy: 'admin-1',
      );
      expect(await repository.nameExists(name: 'disposal fee'), true);
      expect(await repository.nameExists(name: 'DISPOSAL FEE'), true);
    });
  });
}
