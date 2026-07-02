import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/data/repositories/motorcycle_model_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/motorcycle_model_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MotorcycleModelRepository repo;

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        motorcycleModelRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      ]);

  MotorcycleModelEntity model(String name) => MotorcycleModelEntity(
        id: '',
        name: name,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = MotorcycleModelRepositoryImpl(firestore: db);
  });

  test('resolveOrCreate creates a new canonical model and returns its name',
      () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(currentUserProvider.future);
    final ops = c.read(motorcycleModelOperationsProvider.notifier);

    final name = await ops.resolveOrCreate('  nmax ');
    expect(name, 'nmax'); // canonical (trim/collapse), case as typed
    expect((await repo.findByNormalizedKey('nmax'))!.name, 'nmax');
  });

  test('resolveOrCreate reuses an existing row (case-insensitive)', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(currentUserProvider.future);
    await repo.create(model: model('Nmax'), createdBy: 'u');

    final ops = c.read(motorcycleModelOperationsProvider.notifier);
    final name = await ops.resolveOrCreate('NMAX');
    expect(name, 'Nmax'); // reused canonical, not a new fork

    final all = await repo.watchAll().first;
    expect(all.where((m) => normalizedModelKey(m.name) == 'nmax').length, 1);
  });

  test('resolveOrCreate reactivates an archived match', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(currentUserProvider.future);
    final m = await repo.create(model: model('Beat'), createdBy: 'u');
    await repo.setActive(id: m.id, active: false, updatedBy: 'u');

    final ops = c.read(motorcycleModelOperationsProvider.notifier);
    await ops.resolveOrCreate('beat');
    expect((await repo.getById(m.id))!.isActive, isTrue);
  });

  test('resolveOrCreate returns null for blank input', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(currentUserProvider.future);
    final ops = c.read(motorcycleModelOperationsProvider.notifier);
    expect(await ops.resolveOrCreate('   '), isNull);
  });
}
