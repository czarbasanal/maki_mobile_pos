import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Deletes a draft.
///
/// Permission: [Permission.deleteDraft]. Owner-or-admin guard mirrors the
/// firestore.rules rule. Idempotent on a missing draft (succeeds with
/// nothing to delete).
class DeleteDraftUseCase {
  final DraftRepository _repository;

  DeleteDraftUseCase({required DraftRepository repository})
      : _repository = repository;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String draftId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteDraft);

      final original = await _repository.getDraftById(draftId);
      if (original == null) {
        // Already gone — succeed silently rather than surface a 404 the
        // caller has to handle.
        return const UseCaseResult.successVoid();
      }

      final isOwner = original.createdBy == actor.id;
      final isAdmin = actor.role == UserRole.admin;
      if (!isOwner && !isAdmin) {
        return const UseCaseResult.failure(
          message: 'You can only delete drafts you created',
          code: 'forbidden-not-owner',
        );
      }

      await _repository.deleteDraft(draftId);
      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete draft: $e');
    }
  }
}
