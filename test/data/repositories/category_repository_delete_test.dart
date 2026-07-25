import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/category_repository_impl.dart';

void main() {
  test('deleteCategory removes the document', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('product_categories')
        .doc('c1')
        .set({'name': 'Brakes', 'isActive': true});
    final repo = CategoryRepositoryImpl(
        collectionName: 'product_categories', firestore: firestore);

    await repo.deleteCategory('c1');

    final doc =
        await firestore.collection('product_categories').doc('c1').get();
    expect(doc.exists, isFalse);
  });
}
