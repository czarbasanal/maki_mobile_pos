// deleteUser goes through the deleteUserAccount Cloud Function, which owns
// both the Auth login and the users/{uid} doc. The client no longer deletes
// the doc itself — that path left the login behind.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late List<Map<String, dynamic>> calls;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    calls = [];
  });

  UserRepositoryImpl repo({Future<void> Function(Map<String, dynamic>)? fn}) =>
      UserRepositoryImpl(
        firestore: fakeFirestore,
        deleteAccount: fn ??
            (data) async {
              calls.add(data);
            },
      );

  test('deleteUser calls the deleteUserAccount function with the uid', () async {
    await repo().deleteUser('u-1');
    expect(calls, [
      {'uid': 'u-1'},
    ]);
  });

  test('deleteUser leaves the users doc to the function — no client-side delete',
      () async {
    await fakeFirestore.collection('users').doc('u-1').set({
      'email': 'x@test',
      'displayName': 'X',
      'role': 'cashier',
      'isActive': false,
      'createdAt': Timestamp.now(),
    });

    await repo().deleteUser('u-1');

    final doc = await fakeFirestore.collection('users').doc('u-1').get();
    expect(doc.exists, isTrue, reason: 'the function removes it, not the client');
  });

  test("the function's own refusal surfaces as a DatabaseException with its message and code",
      () async {
    final r = repo(
      fn: (_) async => throw FirebaseFunctionsException(
        message: 'Deactivate this user before deleting them.',
        code: 'failed-precondition',
      ),
    );

    await expectLater(
      r.deleteUser('u-1'),
      throwsA(
        isA<DatabaseException>()
            .having((e) => e.message, 'message', 'Deactivate this user before deleting them.')
            .having((e) => e.code, 'code', 'failed-precondition'),
      ),
    );
  });
}
