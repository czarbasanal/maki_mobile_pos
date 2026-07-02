import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Updates an existing draft (Job Order).
///
/// Permission: [Permission.editDraft]. Additionally, only the original
/// creator OR an admin may edit a ticket (mirrors the firestore.rules
/// owner-or-admin rule; the rules carry one extra exception this use case
/// doesn't need — bill-out marks any ticket converted via the repository
/// directly). A converted ticket is frozen. Returns `not-found` if the
/// draft is gone, `forbidden-not-owner` for non-owner non-admin edits, and
/// `already-converted` for edits to a billed-out ticket.
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

      // A billed-out ticket is frozen (mirrors the firestore.rules guard).
      // Without this, an editor holding a stale copy could write
      // isConverted:false back over a converted ticket and let it be billed
      // out a second time.
      if (original.isConverted) {
        return const UseCaseResult.failure(
          message: 'This job order was already billed out',
          code: 'already-converted',
        );
      }

      final isOwner = original.createdBy == actor.id;
      final isAdmin = actor.role == UserRole.admin;
      if (!isOwner && !isAdmin) {
        return const UseCaseResult.failure(
          message: 'You can only edit job orders you created',
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
