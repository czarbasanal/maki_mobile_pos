import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Updates an existing draft.
///
/// Permission: [Permission.editDraft]. Additionally, only the original
/// creator OR an admin may update the draft (mirrors the firestore.rules
/// owner-or-admin rule). Returns `not-found` if the draft is gone and
/// `forbidden-not-owner` if the actor isn't the creator and isn't admin.
class UpdateDraftUseCase {
  final DraftRepository _repository;

  UpdateDraftUseCase({required DraftRepository repository})
      : _repository = repository;

  Future<UseCaseResult<DraftEntity>> execute({
    required UserEntity actor,
    required DraftEntity draft,
  }) async {
    try {
      assertPermission(actor, Permission.editDraft);

      final original = await _repository.getDraftById(draft.id);
      if (original == null) {
        return const UseCaseResult.failure(
          message: 'Draft not found',
          code: 'not-found',
        );
      }

      final isOwner = original.createdBy == actor.id;
      final isAdmin = actor.role == UserRole.admin;
      if (!isOwner && !isAdmin) {
        return const UseCaseResult.failure(
          message: 'You can only edit drafts you created',
          code: 'forbidden-not-owner',
        );
      }

      final updated = await _repository.updateDraft(
        draft: draft,
        updatedBy: actor.id,
      );
      return UseCaseResult.successData(updated);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to update draft: $e');
    }
  }
}
