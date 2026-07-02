import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Creates a void request (cashier/staff). Permission: [Permission.requestVoidSale].
class RequestVoidSaleUseCase {
  final VoidRequestRepository _repository;

  RequestVoidSaleUseCase({required VoidRequestRepository repository})
      : _repository = repository;

  Future<UseCaseResult<VoidRequestEntity>> execute({
    required UserEntity actor,
    required SaleEntity sale,
    required String reason,
  }) async {
    try {
      assertPermission(actor, Permission.requestVoidSale);

      // The reason is usually an admin-managed dropdown name, which can
      // legitimately be short — the min-length rule for free text lives on
      // the form's "Other" detail field, not here.
      final trimmed = reason.trim();
      if (trimmed.isEmpty) {
        return const UseCaseResult.failure(
          message: 'Please provide a reason',
          code: 'reason-required',
        );
      }

      if (await _repository.hasPendingForSale(sale.id)) {
        return const UseCaseResult.failure(
          message: 'A void request for this sale is already pending',
          code: 'void-already-pending',
        );
      }

      final created = await _repository.createRequest(VoidRequestEntity(
        id: '',
        saleId: sale.id,
        saleNumber: sale.saleNumber,
        saleGrandTotal: sale.grandTotal,
        requestedBy: actor.id,
        requestedByName: actor.displayName,
        requestedByRole: actor.role.value,
        reason: trimmed,
        createdAt: DateTime.now(),
      ));

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to request void: $e');
    }
  }
}
