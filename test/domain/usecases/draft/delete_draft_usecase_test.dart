import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/delete_draft_usecase.dart';

class _MockDraftRepository extends Mock implements DraftRepository {}

UserEntity _user(UserRole role, {String? id, bool isActive = true}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

DraftEntity _draft({String createdBy = 'u-cashier'}) => DraftEntity(
      id: 'd-1',
      name: 'Lunch order',
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: '$createdBy user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  late _MockDraftRepository repo;
  late DeleteDraftUseCase useCase;

  setUp(() {
    repo = _MockDraftRepository();
    useCase = DeleteDraftUseCase(repository: repo);
    when(() => repo.deleteDraft(any())).thenAnswer((_) async {});
  });

  group('DeleteDraftUseCase', () {
    test('owner can delete their own draft', () async {
      when(() => repo.getDraftById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        draftId: 'd-1',
      );

      expect(result.success, true);
      verify(() => repo.deleteDraft('d-1')).called(1);
    });

    test('admin can delete any draft', () async {
      when(() => repo.getDraftById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        draftId: 'd-1',
      );

      expect(result.success, true);
      verify(() => repo.deleteDraft('d-1')).called(1);
    });

    test('non-owner cashier cannot delete', () async {
      when(() => repo.getDraftById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-other'));

      final result = await useCase.execute(
        actor: _user(UserRole.cashier, id: 'u-cashier'),
        draftId: 'd-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
      verifyNever(() => repo.deleteDraft(any()));
    });

    test('staff cannot delete another user\'s draft', () async {
      when(() => repo.getDraftById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        draftId: 'd-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
    });

    test('idempotent on missing draft (no error, repo not called)', () async {
      when(() => repo.getDraftById('gone')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        draftId: 'gone',
      );

      expect(result.success, true);
      verifyNever(() => repo.deleteDraft(any()));
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        draftId: 'd-1',
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
