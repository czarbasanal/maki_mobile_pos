import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserRepositoryImpl(
      firestore: fakeFirestore,
      auth: _MockFirebaseAuth(),
    );
  });

  test('deleteUser removes the users/{uid} document', () async {
    await fakeFirestore.collection('users').doc('u-1').set({
      'email': 'x@test',
      'displayName': 'X',
      'role': 'cashier',
      'isActive': false,
      'createdAt': Timestamp.now(),
    });

    await repository.deleteUser('u-1');

    final doc = await fakeFirestore.collection('users').doc('u-1').get();
    expect(doc.exists, isFalse);
  });

  test('deleteUser on a missing doc completes without error', () async {
    await expectLater(repository.deleteUser('missing'), completes);
  });
}
