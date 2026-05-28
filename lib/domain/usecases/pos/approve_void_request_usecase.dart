import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';

/// Approves a void request (admin): runs the void, then marks the request
/// approved. Permission: [Permission.voidSale].
///
/// [VoidSaleUseCase] throws on failure (invalid password, already voided, …),
/// so a failed void propagates as an [AppException] and the request is left
/// pending — it is only marked approved once the void succeeds.
class ApproveVoidRequestUseCase {
  final VoidRequestRepository _repository;
  final VoidSaleUseCase _voidSaleUseCase;

  ApproveVoidRequestUseCase({
    required VoidRequestRepository repository,
    required VoidSaleUseCase voidSaleUseCase,
  })  : _repository = repository,
        _voidSaleUseCase = voidSaleUseCase;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required VoidRequestEntity request,
    required String password,
  }) async {
    try {
      assertPermission(actor, Permission.voidSale);

      // Run the actual void first (admin is recorded as voidedBy). Throws on
      // failure, which is caught below — resolve() is reached only on success.
      await _voidSaleUseCase.execute(
        actor: actor,
        saleId: request.saleId,
        password: password,
        reason: request.reason,
        voidedBy: actor.id,
        voidedByName: actor.displayName,
      );

      await _repository.resolve(
        requestId: request.id,
        status: VoidRequestStatus.approved,
        resolvedBy: actor.id,
        resolvedByName: actor.displayName,
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to approve request: $e');
    }
  }
}
