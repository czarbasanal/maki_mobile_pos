import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/save_draft_usecase.dart';

class _MockDraftRepository extends Mock implements DraftRepository {}

class _FakeDraft extends Fake implements DraftEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

DraftEntity _draft({String createdBy = '', String createdByName = ''}) =>
    DraftEntity(
      id: '',
      name: 'Lunch order',
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDraft());
  });

  late _MockDraftRepository repo;
  late SaveDraftUseCase useCase;

  setUp(() {
    repo = _MockDraftRepository();
    useCase = SaveDraftUseCase(repository: repo);
    when(() => repo.createDraft(any())).thenAnswer((inv) async =>
        (inv.positionalArguments.first as DraftEntity).copyWith(id: 'd-1'));
  });

  group('SaveDraftUseCase', () {
    test('cashier saves draft (saveDraft is held by all roles)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        draft: _draft(),
      );

      expect(result.success, true);
      expect(result.data?.id, 'd-1');
    });

    test('staff saves draft', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        draft: _draft(),
      );
      expect(result.success, true);
    });

    test('admin saves draft', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        draft: _draft(),
      );
      expect(result.success, true);
    });

    test('stamps actor as createdBy + createdByName', () async {
      final captured = <DraftEntity>[];
      when(() => repo.createDraft(any())).thenAnswer((inv) async {
        final d = inv.positionalArguments.first as DraftEntity;
        captured.add(d);
        return d.copyWith(id: 'd-1');
      });

      await useCase.execute(
        actor: _user(UserRole.cashier),
        draft: _draft(createdBy: 'WRONG', createdByName: 'WRONG'),
      );

      expect(captured.single.createdBy, 'u-cashier');
      expect(captured.single.createdByName, 'cashier user');
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        draft: _draft(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.createDraft(any()));
    });

    test('repository failure surfaces', () async {
      when(() => repo.createDraft(any()))
          .thenThrow(Exception('Firestore unavailable'));
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        draft: _draft(),
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Firestore unavailable'));
    });
  });
}
