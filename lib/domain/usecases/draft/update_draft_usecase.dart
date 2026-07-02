import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Updates an existing draft (Job Order).
///
/// Permission: [Permission.editDraft]. Job Orders are shared shop tickets:
/// any active user may update any ticket — bill-out conversion, parts, labor,
/// mechanic, motorcycle model (mirrors the firestore.rules /drafts update
/// rule). Deleting stays owner-or-admin (see DeleteDraftUseCase). Returns
/// `not-found` if the draft is gone.
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
