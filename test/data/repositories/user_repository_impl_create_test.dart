// Regression tests for the admin "create user" flow.
//
// The bug: createUser called createUserWithEmailAndPassword on the app's
// PRIMARY FirebaseAuth. The Firebase client SDK signs the newly-created user
// in as a side effect, so the admin's own session was replaced mid-operation.
// The very next write (users/{uid}) was then evaluated by the rules as the
// brand-new user — who has no profile doc yet, so `isAdmin()` is false and
// the create is DENIED. Net result: a login credential with no profile
// (invisible in the user list), and the admin bounced to the login screen.
//
// The fix mirrors the web admin (FirestoreUserRepository.ts): mint the
// account on a throwaway "provisioning" auth instance, sign that instance
// out, and write the profile with the admin's untouched session.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late _MockFirebaseAuth provisioningAuth;
  late UserRepositoryImpl repository;

  UserCredential credentialFor(String uid) {
    final user = _MockUser();
    when(() => user.uid).thenReturn(uid);
    final cred = _MockUserCredential();
    when(() => cred.user).thenReturn(user);
    return cred;
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    provisioningAuth = _MockFirebaseAuth();
    when(() => provisioningAuth.signOut()).thenAnswer((_) async {});
    repository = UserRepositoryImpl(
      firestore: fakeFirestore,
      provisioningAuth: () async => provisioningAuth,
    );
  });

  Future<UserEntity> create({String email = 'new@shop.test'}) {
    return repository.createUser(
      email: email,
      password: 'hunter2000',
      displayName: 'New Cashier',
      role: UserRole.cashier,
      createdBy: 'admin-1',
    );
  }

  // The admin's own session can no longer be touched by construction: the
  // repository holds only the provisioning auth, never the primary instance.
  test('mints the account on the provisioning auth', () async {
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => credentialFor('new-uid'));

    await create();

    verify(() => provisioningAuth.createUserWithEmailAndPassword(
          email: 'new@shop.test',
          password: 'hunter2000',
        )).called(1);
  });

  test('signs the throwaway provisioning session out afterwards', () async {
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => credentialFor('new-uid'));

    await create();

    verify(() => provisioningAuth.signOut()).called(1);
  });

  test('writes the profile doc under the new uid', () async {
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => credentialFor('new-uid'));

    final result = await create();

    expect(result.id, 'new-uid');
    expect(result.email, 'new@shop.test');
    final doc = await fakeFirestore.collection('users').doc('new-uid').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['email'], 'new@shop.test');
    expect(doc.data()!['displayName'], 'New Cashier');
    expect(doc.data()!['role'], 'cashier');
    expect(doc.data()!['isActive'], isTrue);
  });

  test('still signs the provisioning session out when minting fails',
      () async {
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(FirebaseAuthException(code: 'weak-password'));

    await expectLater(create(), throwsA(isA<AuthException>()));
    verify(() => provisioningAuth.signOut()).called(1);
  });

  test('a create still succeeds when signing the throwaway session out fails',
      () async {
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => credentialFor('new-uid'));
    when(() => provisioningAuth.signOut())
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

    // Cleanup must never mask the real outcome — the account was made.
    final result = await create();

    expect(result.id, 'new-uid');
    final doc = await fakeFirestore.collection('users').doc('new-uid').get();
    expect(doc.exists, isTrue);
  });

  test(
      'a credential with no profile is reported as a login clash, not a '
      'missing user', () async {
    // Auth has the credential but the users collection doesn't — e.g. the
    // person was deleted (delete removes the profile, not the credential) or
    // an earlier create failed midway.
    when(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await expectLater(
      create(),
      throwsA(isA<DuplicateEntryException>()
          .having((e) => e.field, 'field', 'email')
          .having((e) => e.value, 'value', 'new@shop.test')),
    );
  });

  test('an email already in the user list short-circuits before Auth is hit',
      () async {
    await fakeFirestore.collection('users').doc('existing').set({
      'email': 'taken@shop.test',
      'displayName': 'Taken',
      'role': 'cashier',
      'isActive': true,
    });

    await expectLater(
      create(email: 'taken@shop.test'),
      throwsA(isA<DuplicateEntryException>()),
    );
    verifyNever(() => provisioningAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });
}
