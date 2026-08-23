import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a void request (cashier/staff). Permission: [Permission.requestVoidSale].
class RequestVoidSaleUseCase {
  final VoidRequestRepository _repository;
  final ActivityLogger _logger;

  RequestVoidSaleUseCase({
    required VoidRequestRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

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

      String? itemsSummary;
      if (sale.items.isNotEmpty) {
        final joined =
            sale.items.map((i) => '${i.quantity}× ${i.name}').join(', ');
        itemsSummary =
            joined.length <= 80 ? joined : '${joined.substring(0, 79)}…';
      } else if (sale.laborLines.isNotEmpty) {
        itemsSummary = 'Service / labor';
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
        itemsSummary: itemsSummary,
      ));

      // Part of the void audit trail: request → approve shows up as the void
      // itself, request → reject as the rejection, so every request's fate is
      // in the log.
      await _logger.log(
        type: ActivityType.voidSale,
        action: 'Requested void for sale ${sale.saleNumber}',
        details:
            'Reason: $trimmed, Amount: ₱${sale.grandTotal.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: sale.id,
        entityType: 'sale',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to request void: $e');
    }
  }
}
