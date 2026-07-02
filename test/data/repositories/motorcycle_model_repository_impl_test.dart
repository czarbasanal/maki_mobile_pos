import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/motorcycle_model_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MotorcycleModelRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = MotorcycleModelRepositoryImpl(firestore: db);
  });

  MotorcycleModelEntity model(String name) => MotorcycleModelEntity(
        id: '',
        name: name,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  test('create persists + findByNormalizedKey matches case-insensitively',
      () async {
    await repo.create(model: model('Nmax'), createdBy: 'u1');
    final found = await repo.findByNormalizedKey('nmax');
    expect(found, isNotNull);
    expect(found!.name, 'Nmax');
  });

  test('findByNormalizedKey returns null when absent', () async {
    expect(await repo.findByNormalizedKey('aerox'), isNull);
  });

  test('watchActive excludes inactive + sorts A->Z', () async {
    await repo.create(model: model('Sniper'), createdBy: 'u');
    await repo.create(model: model('Aerox'), createdBy: 'u');
    final hidden = await repo.create(model: model('XRM'), createdBy: 'u');
    await repo.setActive(id: hidden.id, active: false, updatedBy: 'u');
    final list = await repo.watchActive().first;
    expect(list.map((m) => m.name), ['Aerox', 'Sniper']);
  });
}
