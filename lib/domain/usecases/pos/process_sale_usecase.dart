import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Use case for processing a complete sale transaction.
///
/// This orchestrates:
/// 1. Validate cart and payment
/// 2. Generate sale number
/// 3. Create sale record
/// 4. Update product inventory
/// 5. Mark draft as converted (if applicable)
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
    bool updateInventory = true,
  }) async {
    final errors = <String>[];
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

      // 3. Generate sale number if not provided
      String saleNumber = sale.saleNumber;
      if (saleNumber.isEmpty) {
        saleNumber = await _saleRepository.generateSaleNumber(DateTime.now());
      }

      // 4. Create sale with updated sale number
      final saleToCreate = sale.copyWith(saleNumber: saleNumber);
      final createdSale = await _saleRepository.createSale(saleToCreate);

      // 5. Update inventory
      if (updateInventory) {
        await _updateInventory(sale.items, createdSale.cashierId);
      }

      // 6. Mark draft as converted if applicable
      if (sale.draftId != null && sale.draftId!.isNotEmpty) {
        try {
          await _draftRepository.markDraftAsConverted(
            draftId: sale.draftId!,
            saleId: createdSale.id,
          );
        } catch (e) {
          // Don't fail the sale if draft update fails
          warnings.add('Draft conversion failed: $e');
        }
      }

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

  /// Validates the sale before processing.
  void _validateSale(SaleEntity sale) {
    if (sale.items.isEmpty) {
      throw const EmptyCartException();
    }

    if (sale.amountReceived < sale.grandTotal) {
      throw InsufficientPaymentException(
        amountDue: sale.grandTotal,
        amountReceived: sale.amountReceived,
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

  /// Updates inventory for all items in the sale.
  Future<void> _updateInventory(
    List<SaleItemEntity> items,
    String updatedBy,
  ) async {
    for (final item in items) {
      try {
        await _productRepository.updateStock(
          productId: item.productId,
          quantityChange: -item.quantity, // Negative to reduce stock
          updatedBy: updatedBy,
        );
      } catch (e) {
        // Log but don't fail - inventory can be corrected later
        // In production, you might want to queue this for retry
        print('Warning: Failed to update inventory for ${item.sku}: $e');
      }
    }
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
