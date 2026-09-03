import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Use case for processing a complete sale transaction.
///
/// This orchestrates:
/// 1. Validate cart and payment
/// 2. Create the sale — the sale number, sale doc, items, and the per-item
///    stock decrement are one atomic transaction in the repository (createSale)
/// 3. Mark the source job order converted (if applicable)
class ProcessSaleUseCase {
  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;
  final JobOrderRepository _jobOrderRepository;
  final ActivityLogger _logger;

  ProcessSaleUseCase({
    required SaleRepository saleRepository,
    required ProductRepository productRepository,
    required JobOrderRepository jobOrderRepository,
    required ActivityLogger logger,
  })  : _saleRepository = saleRepository,
        _productRepository = productRepository,
        _jobOrderRepository = jobOrderRepository,
        _logger = logger;

  /// Processes a sale transaction.
  ///
  /// [sale] - The sale entity to process
  /// [updateInventory] - Whether to deduct inventory (default: true)
  ///
  /// Returns the created sale with ID populated.
  /// Throws [ProcessSaleException] on failure.
  Future<ProcessSaleResult> execute({
    required UserEntity actor,
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

      // 4. Mark the source job order converted (if any)
      await _reconcileJobOrder(sale, createdSale.id, warnings);

      // 4b. A direct service sale (mechanic or motorcycle, no source ticket)
      //     records a job order born converted, so the JO ledger is the full
      //     bench history and not just deferred tickets (web parity).
      await _recordDirectServiceTicket(createdSale, warnings);

      // Fresh creates only — the DuplicateSaleException retry path above
      // reloads a sale that was already recorded (and already logged), so
      // logging there would show one sale twice in the audit trail.
      await _logger.logSale(
        user: actor,
        saleId: createdSale.id,
        saleNumber: createdSale.saleNumber,
        amount: createdSale.grandTotal,
        itemCount: createdSale.items.length,
      );

      return ProcessSaleResult(
        success: true,
        sale: createdSale,
        warnings: warnings,
      );
    } on AppException catch (e) {
      // The server-side drawerSettled() rule (business-day rollover gate)
      // denies sale creation when an earlier day's drawer is still open.
      // Firestore's raw 'permission-denied' is meaningless to a cashier —
      // map it to the actionable message; every other AppException keeps
      // its own message unchanged.
      return ProcessSaleResult(
        success: false,
        errorMessage: e.code == 'permission-denied'
            ? "Sale blocked: the previous day's drawer must be closed first."
            : e.message,
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
  /// the source job order — but never fabricates a success it cannot back with a
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
    await _reconcileJobOrder(sale, existing.id, warnings);
    return ProcessSaleResult(success: true, sale: existing, warnings: warnings);
  }

  /// Marks the source job order (if any) converted. Best-effort and safe to repeat
  /// on a replayed checkout — a job order-conversion failure is a warning, not a
  /// sale failure.
  Future<void> _reconcileJobOrder(
    SaleEntity sale,
    String saleId,
    List<String> warnings,
  ) async {
    if (sale.jobOrderId != null && sale.jobOrderId!.isNotEmpty) {
      try {
        await _jobOrderRepository.markJobOrderAsConverted(
          jobOrderId: sale.jobOrderId!,
          saleId: saleId,
        );
      } catch (e) {
        // Don't fail the sale if job order update fails
        warnings.add('Job Order conversion failed: $e');
      }
    }
  }

  /// Records a billed job order for a direct service sale that came from no
  /// ticket. Best-effort like [_reconcileJobOrder]: a failure warns, never
  /// sinks the sale. Fresh creates only — the replayed-checkout path skips it
  /// rather than risking a duplicate ticket (the first attempt normally
  /// created it).
  Future<void> _recordDirectServiceTicket(
    SaleEntity sale,
    List<String> warnings,
  ) async {
    final hasSourceTicket =
        sale.jobOrderId != null && sale.jobOrderId!.isNotEmpty;
    final isServiceSale =
        (sale.mechanicId != null && sale.mechanicId!.isNotEmpty) ||
            (sale.motorcycleModel != null && sale.motorcycleModel!.isNotEmpty);
    if (hasSourceTicket || !isServiceSale) return;

    try {
      final now = DateTime.now();
      // Same minting rule as Save-as-JO: today's names, converted included,
      // so a billed-out number is never reissued.
      final todays = await _jobOrderRepository.getJobOrdersByDateRange(
        startDate: now,
        endDate: now,
        includeConverted: true,
      );
      final name = nextJobOrderNumber(now, todays.map((j) => j.name));
      await _jobOrderRepository.createJobOrder(JobOrderEntity(
        id: '',
        name: name,
        items: sale.items,
        laborLines: sale.laborLines,
        feeLines: sale.feeLines,
        mechanicId: sale.mechanicId,
        mechanicName: sale.mechanicName,
        motorcycleModel: sale.motorcycleModel,
        discountType: sale.discountType,
        createdBy: sale.cashierId,
        createdByName: sale.cashierName,
        createdAt: now,
        isConverted: true,
        convertedToSaleId: sale.id,
        convertedAt: now,
        notes: sale.notes,
      ));
    } catch (e) {
      warnings.add('Service ticket record failed: $e');
    }
  }

  /// Validates the sale before processing.
  void _validateSale(SaleEntity sale) {
    // Items, labor, or shop fees — any one is enough to bill out. Only
    // reject when there is truly nothing to bill (mirrors
    // CartState.hasBillableContent).
    if (sale.items.isEmpty &&
        sale.laborLines.isEmpty &&
        sale.feeLines.isEmpty) {
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
