import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/category_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

CategoryEntity _category(String name) {
  return CategoryEntity(
    id: '',
    name: name,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('createCategory assignCode', () {
    test(
        'assigns sequential 0001/0002 codes, writes registry docs, and '
        'advances the counter', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CategoryRepositoryImpl(
        collectionName: 'product_categories',
        firestore: firestore,
      );

      final first = await repo.createCategory(
        category: _category('Brakes'),
        createdBy: 'user-1',
        assignCode: true,
      );
      final second = await repo.createCategory(
        category: _category('Filters'),
        createdBy: 'user-1',
        assignCode: true,
      );

      expect(first.code, '0001');
      expect(second.code, '0002');

      final registryFirst =
          await firestore.collection('category_codes').doc('0001').get();
      expect(registryFirst.exists, isTrue);
      expect(registryFirst.data()!['categoryId'], first.id);
      expect(registryFirst.data()!['nameSnapshot'], 'Brakes');
      expect(registryFirst.data()!['nextSequence'], 1);
      expect(registryFirst.data()!['assignedAt'], isA<Timestamp>());

      final registrySecond =
          await firestore.collection('category_codes').doc('0002').get();
      expect(registrySecond.exists, isTrue);
      expect(registrySecond.data()!['categoryId'], second.id);
      expect(registrySecond.data()!['nameSnapshot'], 'Filters');
      expect(registrySecond.data()!['nextSequence'], 1);

      final counter =
          await firestore.collection('category_codes').doc('_counter').get();
      expect(counter.data()!['next'], 3);
    });

    test('seeds the counter at 0001 when _counter is absent', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CategoryRepositoryImpl(
        collectionName: 'product_categories',
        firestore: firestore,
      );

      final created = await repo.createCategory(
        category: _category('Brakes'),
        createdBy: 'user-1',
        assignCode: true,
      );

      expect(created.code, '0001');
      final counter =
          await firestore.collection('category_codes').doc('_counter').get();
      expect(counter.data()!['next'], 2);
    });

    test(
        'assignCode: false (default) creates no code, no registry doc, and '
        'leaves the counter untouched', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = CategoryRepositoryImpl(
        collectionName: 'expense_categories',
        firestore: firestore,
      );

      final created = await repo.createCategory(
        category: _category('Utilities'),
        createdBy: 'user-1',
      );

      expect(created.code, isNull);

      final doc = await firestore
          .collection('expense_categories')
          .doc(created.id)
          .get();
      expect(doc.data()!.containsKey('code'), isFalse);

      final counterSnapshot =
          await firestore.collection('category_codes').get();
      expect(counterSnapshot.docs, isEmpty);
    });
  });
}
