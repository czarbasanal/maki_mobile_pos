import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Use case for processing a complete sale transaction.
///
/// This orchestrates:
/// 1. Validate cart and payment
/// 2. Create the sale — the sale number, sale doc, items, and the per-item
///    stock decrement are one atomic transaction in the repository (createSale)
/// 3. Mark the source draft converted (if applicable)
class ProcessSaleUseCase {
  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;
  final DraftRepository _draftRepository;

  ProcessSaleUseCase({
    required SaleRepository saleRepository,
    required ProductRepository productRepository,
    required DraftRepository draftRepository,
  })  : _saleRepository = saleRepository,
        _productRepository = productRepository,
        _draftRepository = draftRepository;

  /// Processes a sale transaction.
  ///
  /// [sale] - The sale entity to process
  /// [updateInventory] - Whether to deduct inventory (default: true)
  ///
  /// Returns the created sale with ID populated.
  /// Throws [ProcessSaleException] on failure.
  Future<ProcessSaleResult> execute({
    required SaleEntity sale,
    required String checkoutId,
    bool updateInventory = true,
  }) async {
    final warnings = <String>[];

    try {
      // 1. Validate sale
      _validateSale(sale);

      // 2. Check inventory availability
      if (updateInventory) {
        final stockIssues = await _checkInventoryAvailability(sale.items);
        if (stockIssues.isNotEmpty) {
          // Add warnings but don't fail - let business decide
          warnings.addAll(stockIssues);
        }
      }

      // 3. Create the sale under the checkout id (the idempotency key). The
      //    sale number is generated inside createSale's transaction; a repeat
      //    write under the same id throws DuplicateSaleException. That
      //    transaction guard is authoritative, so there is no separate
      //    pre-check read on the happy path.
      final SaleEntity createdSale;
      try {
        createdSale = await _saleRepository.createSale(
          sale.copyWith(saleNumber: ''),
          id: checkoutId,
          decrementStock: updateInventory,
        );
      } on DuplicateSaleException {
        // Already recorded — a retry of a checkout that had actually committed.
        return _handleAlreadyRecorded(sale, checkoutId);
      }

      // 4. Mark the source draft converted (if any)
      await _reconcileDraft(sale, createdSale.id, warnings);

      return ProcessSaleResult(
        success: true,
        sale: createdSale,
        warnings: warnings,
      );
    } on AppException catch (e) {
      return ProcessSaleResult(
        success: false,
        errorMessage: e.message,
        errors: [e.message],
      );
    } catch (e) {
      return ProcessSaleResult(
        success: false,
        errorMessage: 'Failed to process sale: $e',
        errors: ['Unexpected error: $e'],
      );
    }
  }

  /// Handles a checkout whose sale was already recorded under [checkoutId]
  /// (the idempotency guard fired). Returns the existing sale and reconciles
  /// the source draft — but never fabricates a success it cannot back with a
  /// real, reloadable sale.
  Future<ProcessSaleResult> _handleAlreadyRecorded(
    SaleEntity sale,
    String checkoutId,
  ) async {
    SaleEntity? existing;
    try {
      existing = await _saleRepository.getSaleById(checkoutId);
    } catch (_) {
      existing = null;
    }

    if (existing == null) {
      // The sale exists (createSale's guard saw it) but we could not reload it.
      // Do not fake a receipt or clear the cart — have the cashier verify.
      return ProcessSaleResult(
        success: false,
        errorMessage:
            'This sale may already be recorded. Check Sales before charging again.',
        errors: const ['Duplicate sale could not be reloaded.'],
      );
    }

    final warnings = <String>['This sale was already recorded.'];
    await _reconcileDraft(sale, existing.id, warnings);
    return ProcessSaleResult(success: true, sale: existing, warnings: warnings);
  }

  /// Marks the source draft (if any) converted. Best-effort and safe to repeat
  /// on a replayed checkout — a draft-conversion failure is a warning, not a
  /// sale failure.
  Future<void> _reconcileDraft(
    SaleEntity sale,
    String saleId,
    List<String> warnings,
  ) async {
    if (sale.draftId != null && sale.draftId!.isNotEmpty) {
      try {
        await _draftRepository.markDraftAsConverted(
          draftId: sale.draftId!,
          saleId: saleId,
        );
      } catch (e) {
        // Don't fail the sale if draft update fails
        warnings.add('Draft conversion failed: $e');
      }
    }
  }

  /// Validates the sale before processing.
  void _validateSale(SaleEntity sale) {
    if (sale.items.isEmpty) {
      throw const EmptyCartException();
    }

    // The tender breakdown must reconcile to the grand total. This covers
    // single, mixed, and salmon (downpayment + receivable) sales — the amount
    // collected today may be less than grandTotal for salmon.
    if (!sale.isTenderValid) {
      throw InsufficientPaymentException(
        amountDue: sale.grandTotal,
        amountReceived:
            sale.effectiveTenders.values.fold<double>(0, (a, b) => a + b),
      );
    }

    if (sale.cashierId.isEmpty) {
      throw const ValidationException(
        message: 'Cashier ID is required',
        field: 'cashierId',
      );
    }
  }

  /// Checks if all items have sufficient inventory.
  Future<List<String>> _checkInventoryAvailability(
    List<SaleItemEntity> items,
  ) async {
    final issues = <String>[];

    for (final item in items) {
      final product = await _productRepository.getProductById(item.productId);

      if (product == null) {
        issues.add('Product not found: ${item.name} (${item.sku})');
        continue;
      }

      if (product.quantity < item.quantity) {
        issues.add(
          '${item.name}: Requested ${item.quantity}, available ${product.quantity}',
        );
      }
    }

    return issues;
  }
}

/// Result of processing a sale.
class ProcessSaleResult {
  final bool success;
  final SaleEntity? sale;
  final String? errorMessage;
  final List<String> errors;
  final List<String> warnings;

  const ProcessSaleResult({
    required this.success,
    this.sale,
    this.errorMessage,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Exception for validation errors.
class ValidationException extends AppException {
  final String field;

  const ValidationException({
    required super.message,
    required this.field,
    super.code = 'validation-error',
  });
}
