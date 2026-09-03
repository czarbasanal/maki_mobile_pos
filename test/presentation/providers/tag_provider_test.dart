import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/tag_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _RecordingTagRepo implements TagRepository {
  final created = <TagEntity>[];
  final setActiveTagIds = <String>[];
  final setActiveValues = <bool>[];

  @override
  Future<TagEntity> createTag({
    required TagEntity tag,
    required String createdBy,
  }) async {
    created.add(tag);
    return tag.copyWith(id: 'new-1', createdBy: createdBy);
  }

  @override
  Future<void> setActive({
    required String tagId,
    required bool active,
    required String updatedBy,
  }) async {
    setActiveTagIds.add(tagId);
    setActiveValues.add(active);
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
    final repo = _RecordingTagRepo();
    final container = ProviderContainer(overrides: [
      tagRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    // Let currentUserProvider emit before the notifier reads it.
    await container.read(currentUserProvider.future);

    final tag = TagEntity.empty().copyWith(name: 'Intact', color: 'green');
    final created =
        await container.read(tagOperationsProvider.notifier).create(tag: tag);

    expect(created, isNotNull);
    expect(created!.createdBy, 'u-staff');
    expect(repo.created.single.name, 'Intact');
    expect(repo.created.single.color, 'green');
  });

  test('deactivate flips isActive false via setActive', () async {
    final repo = _RecordingTagRepo();
    final container = ProviderContainer(overrides: [
      tagRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ok =
        await container.read(tagOperationsProvider.notifier).deactivate('t1');

    expect(ok, isTrue);
    expect(repo.setActiveTagIds.single, 't1');
    expect(repo.setActiveValues.single, false);
  });
}
