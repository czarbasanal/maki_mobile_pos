import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Rejects a void request (admin). Permission: [Permission.voidSale].
class RejectVoidRequestUseCase {
  final VoidRequestRepository _repository;

  RejectVoidRequestUseCase({required VoidRequestRepository repository})
      : _repository = repository;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required VoidRequestEntity request,
    required String rejectionReason,
  }) async {
    try {
      assertPermission(actor, Permission.voidSale);

      final trimmed = rejectionReason.trim();
      if (trimmed.isEmpty) {
        return const UseCaseResult.failure(
          message: 'A rejection reason is required',
          code: 'reason-required',
        );
      }

      await _repository.resolve(
        requestId: request.id,
        status: VoidRequestStatus.rejected,
        resolvedBy: actor.id,
        resolvedByName: actor.displayName,
        rejectionReason: trimmed,
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to reject request: $e');
    }
  }
}
