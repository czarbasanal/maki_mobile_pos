import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  MechanicEntity newMechanic({String name = 'Juan'}) => MechanicEntity(
        id: '',
        name: name,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  group('MechanicRepositoryImpl', () {
    test('createMechanic assigns an id and stamps createdBy', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      expect(created.id, isNotEmpty);
      expect(created.name, 'Juan');
      expect(created.createdBy, 'admin-1');
    });

    test('createMechanic throws DuplicateEntryException on existing name',
        () async {
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      expect(
        () => repository.createMechanic(
          mechanic: newMechanic(name: 'Pedro'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('getMechanicById returns the persisted mechanic', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      final fetched = await repository.getMechanicById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Juan');
    });

    test('getMechanicById returns null when missing', () async {
      expect(await repository.getMechanicById('nope'), isNull);
    });

    test('watchActive emits only active mechanics, A->Z', () async {
      final pedro = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Andres'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: pedro.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final active = await repository.watchActive().first;
      expect(active.map((m) => m.name), ['Andres']);
    });

    test('watchAll emits active + inactive sorted A->Z', () async {
      final pedro = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Andres'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: pedro.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final all = await repository.watchAll().first;
      expect(all.map((m) => m.name), ['Andres', 'Pedro']);
    });

    test('updateMechanic persists the new name', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      final updated = await repository.updateMechanic(
        mechanic: created.copyWith(name: 'Juanito'),
        updatedBy: 'admin-2',
      );
      expect(updated.name, 'Juanito');
      expect(updated.updatedBy, 'admin-2');
    });

    test('setActive deactivates a mechanic', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: created.id,
        active: false,
        updatedBy: 'admin-1',
      );
      final fetched = await repository.getMechanicById(created.id);
      expect(fetched!.isActive, false);
    });

    test('nameExists honours excludeMechanicId', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      expect(await repository.nameExists(name: 'Pedro'), true);
      expect(
        await repository.nameExists(
          name: 'Pedro',
          excludeMechanicId: created.id,
        ),
        false,
      );
      expect(await repository.nameExists(name: 'Ghost'), false);
    });
  });
}
