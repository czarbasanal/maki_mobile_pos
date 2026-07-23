import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

UserEntity _admin({bool isActive = true}) => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: isActive,
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  test('maps own-doc snapshots to active/deactivated/deleted', () async {
    final repo = _MockUserRepository();
    final docs = StreamController<UserEntity?>();
    when(() => repo.watchUser('u1')).thenAnswer((_) => docs.stream);

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
    ]);
    addTearDown(container.dispose);
    addTearDown(docs.close);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero); // let authGatedStream subscribe
    docs.add(_admin());
    await Future<void>.delayed(Duration.zero);
    docs.add(_admin(isActive: false));
    await Future<void>.delayed(Duration.zero);
    docs.add(null); // doc gone
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [
      AccountStatus.active,
      AccountStatus.deactivated,
      AccountStatus.deleted,
    ]);
  });

  test('permission-denied stream error surfaces as deleted', () async {
    final repo = _MockUserRepository();
    final docs = StreamController<UserEntity?>();
    when(() => repo.watchUser('u1')).thenAnswer((_) => docs.stream);

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
    ]);
    addTearDown(container.dispose);
    addTearDown(docs.close);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero);
    docs.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [AccountStatus.deleted]);
  });

  test('emits nothing while signed out', () async {
    final repo = _MockUserRepository();

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(statuses, isEmpty);
    verifyNever(() => repo.watchUser(any()));
  });
}
