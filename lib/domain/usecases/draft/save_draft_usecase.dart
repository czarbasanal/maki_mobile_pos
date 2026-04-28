import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Persists a draft (parked sale). Permission: [Permission.saveDraft].
///
/// The actor's id + name are stamped onto the draft so downstream
/// owner-or-admin checks resolve correctly. Drafts are transient working
/// state — no activity log is written.
class SaveDraftUseCase {
  final DraftRepository _repository;

  SaveDraftUseCase({required DraftRepository repository})
      : _repository = repository;

  Future<UseCaseResult<DraftEntity>> execute({
    required UserEntity actor,
    required DraftEntity draft,
  }) async {
    try {
      assertPermission(actor, Permission.saveDraft);

      final stamped = draft.copyWith(
        createdBy: actor.id,
        createdByName: actor.displayName,
      );
      final created = await _repository.createDraft(stamped);
      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to save draft: $e');
    }
  }
}
