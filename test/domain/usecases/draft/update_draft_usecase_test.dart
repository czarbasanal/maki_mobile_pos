import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/update_draft_usecase.dart';

class _MockDraftRepository extends Mock implements DraftRepository {}

class _FakeDraft extends Fake implements DraftEntity {}

UserEntity _user(UserRole role, {String? id, bool isActive = true}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

DraftEntity _draft({
  String id = 'd-1',
  String createdBy = 'u-cashier',
  String name = 'Lunch order',
}) =>
    DraftEntity(
      id: id,
      name: name,
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: '$createdBy user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDraft());
  });

  late _MockDraftRepository repo;
  late UpdateDraftUseCase useCase;

  setUp(() {
    repo = _MockDraftRepository();
    useCase = UpdateDraftUseCase(repository: repo);
    when(() => repo.updateDraft(
          draft: any(named: 'draft'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((inv) async => inv.namedArguments[#draft] as DraftEntity);
  });

  group('UpdateDraftUseCase', () {
    test('owner can update their own draft', () async {
      final draft = _draft(createdBy: 'u-cashier');
      when(() => repo.getDraftById('d-1')).thenAnswer((_) async => draft);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        draft: draft.copyWith(name: 'Renamed'),
      );

      expect(result.success, true);
      expect(result.data?.name, 'Renamed');
    });

    test('admin can update any draft', () async {
      final draft = _draft(createdBy: 'u-cashier');
      when(() => repo.getDraftById('d-1')).thenAnswer((_) async => draft);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        draft: draft.copyWith(name: 'Admin renamed'),
      );

      expect(result.success, true);
    });

    test('non-owner cashier cannot update someone elses draft', () async {
      final draft = _draft(createdBy: 'u-other');
      when(() => repo.getDraftById('d-1')).thenAnswer((_) async => draft);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier, id: 'u-cashier'),
        draft: draft.copyWith(name: 'Hacked'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
      verifyNever(() => repo.updateDraft(
            draft: any(named: 'draft'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff cannot update another user\'s draft', () async {
      final draft = _draft(createdBy: 'u-cashier');
      when(() => repo.getDraftById('d-1')).thenAnswer((_) async => draft);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        draft: draft.copyWith(name: 'Renamed'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
    });

    test('returns not-found for missing draft', () async {
      when(() => repo.getDraftById('missing')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        draft: _draft(id: 'missing'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'not-found');
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        draft: _draft(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
