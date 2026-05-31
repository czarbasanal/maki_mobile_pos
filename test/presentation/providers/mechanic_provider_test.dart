import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepository repo;

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
        mechanicRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      ],
    );
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  test('create then deactivate via the operations notifier', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Warm currentUserProvider so the notifier can resolve the actor.
    await container.read(currentUserProvider.future);

    final ops = container.read(mechanicOperationsProvider.notifier);

    final created = await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Juan',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    expect(created, isNotNull);
    expect(created!.id, isNotEmpty);
    expect(created.createdBy, 'admin-1');

    final ok = await ops.deactivate(created.id);
    expect(ok, true);

    final fetched = await repo.getMechanicById(created.id);
    expect(fetched!.isActive, false);
  });

  test('activeMechanicsProvider emits only active mechanics', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(mechanicOperationsProvider.notifier);
    final pedro = await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Andres',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.deactivate(pedro!.id);

    final active = await container.read(activeMechanicsProvider.future);
    expect(active.map((m) => m.name), ['Andres']);
  });
}
