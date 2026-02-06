import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Use case for voiding a sale transaction.
///
/// This orchestrates:
/// 1. Validate the sale can be voided
/// 2. Verify admin password
/// 3. Void the sale record
/// 4. Restore inventory
/// 5. Create audit trail
class VoidSaleUseCase {
  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;
  final AuthRepository _authRepository;

  VoidSaleUseCase({
    required SaleRepository saleRepository,
    required ProductRepository productRepository,
    required AuthRepository authRepository,
  })  : _saleRepository = saleRepository,
        _productRepository = productRepository,
        _authRepository = authRepository;

  /// Voids a sale transaction.
  ///
  /// [saleId] - The ID of the sale to void
  /// [password] - Admin password for verification
  /// [reason] - Reason for voiding (required)
  /// [voidedBy] - User ID of person voiding
  /// [voidedByName] - Display name of person voiding
  /// [restoreInventory] - Whether to restore stock (default: true)
  ///
  /// Returns the voided sale.
  /// Throws [VoidSaleException] on failure.
  Future<VoidSaleResult> execute({
    required String saleId,
    required String password,
    required String reason,
    required String voidedBy,
    required String voidedByName,
    bool restoreInventory = true,
  }) async {
    final warnings = <String>[];

    try {
      // 1. Validate inputs
      _validateInputs(reason: reason, voidedBy: voidedBy);

      // 2. Get the sale
      final sale = await _saleRepository.getSaleById(saleId);
      if (sale == null) {
        throw const VoidSaleException(
          message: 'Sale not found',
          code: 'sale-not-found',
        );
      }

      // 3. Validate sale can be voided
      _validateSaleCanBeVoided(sale);

      // 4. Verify password
      final isPasswordValid = await _authRepository.verifyPassword(password);
      if (!isPasswordValid) {
        throw const VoidSaleException(
          message: 'Invalid password',
          code: 'invalid-password',
        );
      }

      // 5. Void the sale
      final voidedSale = await _saleRepository.voidSale(
        saleId: saleId,
        voidedBy: voidedBy,
        voidedByName: voidedByName,
        reason: reason,
      );

      // 6. Restore inventory
      if (restoreInventory) {
        final inventoryWarnings = await _restoreInventory(
          sale.items,
          voidedBy,
        );
        warnings.addAll(inventoryWarnings);
      }

      return VoidSaleResult(
        success: true,
        sale: voidedSale,
        warnings: warnings,
      );
    } on VoidSaleException {
      rethrow;
    } on AppException catch (e) {
      throw VoidSaleException(
        message: e.message,
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      throw VoidSaleException(
        message: 'Failed to void sale: $e',
        originalError: e,
      );
    }
  }

  /// Validates input parameters.
  void _validateInputs({
    required String reason,
    required String voidedBy,
  }) {
    if (reason.trim().isEmpty) {
      throw const VoidSaleException(
        message: 'Void reason is required',
        code: 'reason-required',
      );
    }

    if (reason.trim().length < 5) {
      throw const VoidSaleException(
        message:
            'Please provide a more detailed reason (at least 5 characters)',
        code: 'reason-too-short',
      );
    }

    if (voidedBy.isEmpty) {
      throw const VoidSaleException(
        message: 'User ID is required',
        code: 'user-required',
      );
    }
  }

  /// Validates that the sale can be voided.
  void _validateSaleCanBeVoided(SaleEntity sale) {
    // Check if already voided
    if (sale.status == SaleStatus.voided) {
      throw const VoidSaleException(
        message: 'This sale has already been voided',
        code: 'already-voided',
      );
    }

    // Check if sale is too old (optional business rule)
    final hoursSinceSale = DateTime.now().difference(sale.createdAt).inHours;
    if (hoursSinceSale > 24) {
      // Warning but don't prevent - business may allow older voids
      // This could be made configurable
    }
  }

  /// Restores inventory for voided sale items.
  Future<List<String>> _restoreInventory(
    List<SaleItemEntity> items,
    String updatedBy,
  ) async {
    final warnings = <String>[];

    for (final item in items) {
      try {
        await _productRepository.updateStock(
          productId: item.productId,
          quantityChange: item.quantity, // Positive to restore stock
          updatedBy: updatedBy,
        );
      } catch (e) {
        warnings.add('Failed to restore stock for ${item.name}: $e');
      }
    }

    return warnings;
  }
}

/// Result of voiding a sale.
class VoidSaleResult {
  final bool success;
  final SaleEntity? sale;
  final String? errorMessage;
  final List<String> warnings;

  const VoidSaleResult({
    required this.success,
    this.sale,
    this.errorMessage,
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
