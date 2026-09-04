import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/adjustment_reason_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/adjustment_reason_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

class _RecordingAdjustmentReasonRepo implements AdjustmentReasonRepository {
  final created = <AdjustmentReasonEntity>[];
  final seedDefaultsCalledWith = <String>[];

  @override
  Future<AdjustmentReasonEntity> createAdjustmentReason({
    required AdjustmentReasonEntity reason,
    required String createdBy,
  }) async {
    created.add(reason);
    return reason.copyWith(id: 'new-1', createdBy: createdBy);
  }

  @override
  Future<void> seedDefaults(String createdBy) async {
    seedDefaultsCalledWith.add(createdBy);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

UserEntity _staff() => UserEntity(
      id: 'u-staff',
      email: 'staff@x.com',
      displayName: 'Staff',
      role: UserRole.staff,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('create routes through the repository with the actor id', () async {
    final repo = _RecordingAdjustmentReasonRepo();
    final container = ProviderContainer(overrides: [
      adjustmentReasonRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    // Let currentUserProvider emit before the notifier reads it.
    await container.read(currentUserProvider.future);

    final reason = AdjustmentReasonEntity.empty().copyWith(
      name: 'Delivery',
      requiresNote: false,
    );
    final created = await container
        .read(adjustmentReasonOperationsProvider.notifier)
        .create(reason: reason);

    expect(created, isNotNull);
    expect(created!.createdBy, 'u-staff');
    expect(repo.created.single.name, 'Delivery');
    expect(repo.created.single.requiresNote, false);
  });

  test('seedDefaults calls the repo with the actor id', () async {
    final repo = _RecordingAdjustmentReasonRepo();
    final container = ProviderContainer(overrides: [
      adjustmentReasonRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ok =
        await container.read(adjustmentReasonOperationsProvider.notifier).seedDefaults();

    expect(ok, isTrue);
    expect(repo.seedDefaultsCalledWith.single, 'u-staff');
  });
}
