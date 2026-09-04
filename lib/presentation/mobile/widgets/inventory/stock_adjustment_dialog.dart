import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/permissions/permissions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/stock_adjustment.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Audit-grade stock adjustment sheet — mirrors the web admin's
/// `AdjustStockDialog` (spec 2026-09-04): a preview strip shows the
/// resulting on-hand before the user commits, mode is three chips (not a
/// segmented control), quantity is a +/- stepper, and a reason is REQUIRED —
/// the record this sheet produces is what makes Receiving, sales and manual
/// corrections reconcilable. `Set to` is admin-only: it can erase a
/// discrepancy without recording what the discrepancy was.
class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final ProductEntity product;

  const StockAdjustmentDialog({
    super.key,
    required this.product,
  });

  static Future<bool?> show({
    required BuildContext context,
    required ProductEntity product,
  }) {
    return showAppBottomSheet<bool>(
      context,
      child: StockAdjustmentDialog(product: product),
    );
  }

  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  AdjustmentMode _mode = AdjustmentMode.add;
  late int _onHand;
  String? _reasonId;
  bool _isProcessing = false;
  String? _staleNotice;
  String? _errorMessage;
  bool _seededReasons = false;

  static const _modeLabels = {
    AdjustmentMode.add: 'Add',
    AdjustmentMode.remove: 'Remove',
    AdjustmentMode.set: 'Set to',
  };

  @override
  void initState() {
    super.initState();
    _onHand = widget.product.quantity;
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _qty {
    final text = _qtyController.text;
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _step(int direction) {
    final next = ((_qty ?? 0) + direction).clamp(0, 1 << 31);
    setState(() {
      _qtyController.text = '$next';
      _errorMessage = null;
    });
  }

  AdjustmentReasonEntity? _findReason(
    List<AdjustmentReasonEntity> reasons,
    String? id,
  ) {
    if (id == null) return null;
    for (final reason in reasons) {
      if (reason.id == id) return reason;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = ref.hasPermission(Permission.editProduct);
    final reasonsAsync = ref.watch(activeAdjustmentReasonsProvider);
    final reasons =
        reasonsAsync.valueOrNull ?? const <AdjustmentReasonEntity>[];

    // Auto-seed the default reason set the first time the active stream
    // resolves empty. Deferred to a post-frame callback — calling the
    // notifier here would modify a provider mid-build.
    if (!_seededReasons && reasonsAsync.hasValue && reasons.isEmpty) {
      _seededReasons = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(adjustmentReasonOperationsProvider.notifier).seedDefaults();
      });
    }

    final availableModes = isAdmin
        ? const [AdjustmentMode.add, AdjustmentMode.remove, AdjustmentMode.set]
        : const [AdjustmentMode.add, AdjustmentMode.remove];
    // A non-admin can never land on `set` (no chip to pick it), but guard
    // against a stale state if permissions change mid-session.
    if (!availableModes.contains(_mode)) _mode = AdjustmentMode.add;

    final qty = _qty;
    final result = resolveAdjustment(_mode, _onHand, qty ?? 0);
    final selectedReason = _findReason(reasons, _reasonId);
    final requiresNote = selectedReason?.requiresNote ?? false;
    final validity = adjustmentValidity(
      mode: _mode,
      qty: qty,
      onHand: _onHand,
      reasonId: _reasonId,
      requiresNote: requiresNote,
      note: _noteController.text,
    );
    final canApply = validity == null && !_isProcessing;
    final isCountedQuantity = _mode == AdjustmentMode.set;

    return AppBottomSheet(
      leadingIcon: LucideIcons.package,
      title: 'Adjust Stock',
      subtitle: widget.product.name,
      onClose: _isProcessing ? null : () => Navigator.pop(context),
      bodyExpands: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview strip — the whole point of the sheet: show the
            // number the user will land on, not just the delta typed.
            AppCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
              child: Row(
                children: [
                  _buildStockColumn('On hand', '$_onHand',
                      theme.colorScheme.onSurface, muted),
                  Icon(LucideIcons.arrowRight, color: muted, size: 18),
                  Expanded(
                    child: _buildStockColumn(
                      'New quantity',
                      qty == null ? '—' : '${result.after}',
                      qty != null && result.after < 0
                          ? AppColors.errorText(dark)
                          : theme.colorScheme.onSurface,
                      muted,
                    ),
                  ),
                  _buildDeltaChip(qty == null ? 0 : result.delta,
                      show: qty != null, dark: dark),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg - 4),
            // Mode — three (or two, for non-admins) equal chips.
            Row(
              children: [
                for (final mode in availableModes) ...[
                  if (mode != availableModes.first) const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(_modeLabels[mode]!),
                      selected: _mode == mode,
                      showCheckmark: false,
                      onSelected: _isProcessing
                          ? null
                          : (_) {
                              setState(() {
                                _mode = mode;
                                _errorMessage = null;
                              });
                            },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Quantity — stepper flanking a digits-only field.
            Text(
              isCountedQuantity ? 'Counted quantity' : 'Quantity',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Decrease quantity',
                  onPressed: _isProcessing ? null : () => _step(-1),
                  icon: const Icon(LucideIcons.minus),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: AppTextStyles.fieldInput,
                    controller: _qtyController,
                    textAlign: TextAlign.center,
                    enabled: !_isProcessing,
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Increase quantity',
                  onPressed: _isProcessing ? null : () => _step(1),
                  icon: const Icon(LucideIcons.plus),
                ),
                const SizedBox(width: 8),
                Text(widget.product.unit,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
            ),
            if (qty != null && result.after < 0) ...[
              const SizedBox(height: 6),
              Text(
                validity ?? '',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.errorText(dark)),
              ),
            ],
            const SizedBox(height: 20),
            // Reason — required.
            Text(
              'Reason',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            reasonsAsync.isLoading && reasons.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((reason) {
                      return ChoiceChip(
                        label: Text(reason.name),
                        selected: _reasonId == reason.id,
                        showCheckmark: false,
                        onSelected: _isProcessing
                            ? null
                            : (_) {
                                setState(() {
                                  _reasonId = reason.id;
                                  _errorMessage = null;
                                });
                              },
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),
            // Note — required only for reasons that demand one; the
            // requirement is visible before submit, not announced by an
            // error.
            Text(
              requiresNote ? 'Note' : 'Note (optional)',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              style: AppTextStyles.fieldInput,
              controller: _noteController,
              enabled: !_isProcessing,
              decoration: InputDecoration(
                hintText: 'e.g., Received shipment, Damaged items',
                prefixIcon: const Icon(LucideIcons.fileText),
              ),
              maxLines: 2,
            ),
            if (_staleNotice != null) ...[
              const SizedBox(height: 16),
              _buildNotice(
                _staleNotice!,
                background: AppColors.warningBannerFill(dark),
                foreground: AppColors.warningBannerText(dark),
                icon: LucideIcons.alertTriangle,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildNotice(
                _errorMessage!,
                background:
                    AppColors.error.withValues(alpha: dark ? 0.18 : 0.12),
                foreground: AppColors.errorText(dark),
                icon: LucideIcons.alertCircle,
              ),
            ],
          ],
        ),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recorded against ${currentUser?.displayName ?? 'you'}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: canApply ? _handleAdjustment : null,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Apply adjustment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockColumn(
      String label, String value, Color valueColor, Color muted) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.monoFontFamily,
                color: valueColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(widget.product.unit,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
        ),
      ],
    );
  }

  Widget _buildDeltaChip(int delta, {required bool show, required bool dark}) {
    final label = !show ? '—' : (delta >= 0 ? '+$delta' : '$delta');
    final Color background;
    final Color foreground;
    if (!show || delta == 0) {
      background = AppColors.neutralTileFill(dark);
      foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (delta > 0) {
      background = AppColors.successFill(dark);
      foreground = AppColors.successText(dark);
    } else {
      background = AppColors.error.withValues(alpha: dark ? 0.18 : 0.12);
      foreground = AppColors.errorText(dark);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.monoFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildNotice(
    String message, {
    required Color background,
    required Color foreground,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdjustment() async {
    final qty = _qty;
    final reasonsAsync = ref.read(activeAdjustmentReasonsProvider);
    final reasons =
        reasonsAsync.valueOrNull ?? const <AdjustmentReasonEntity>[];
    final selectedReason = _findReason(reasons, _reasonId);
    if (qty == null || selectedReason == null) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      setState(() => _errorMessage = 'User not logged in');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _staleNotice = null;
    });

    final note = _noteController.text.trim();

    try {
      final result =
          await ref.read(productRepositoryProvider).adjustStockAudited(
                productId: widget.product.id,
                mode: _mode,
                quantity: qty,
                expectedOnHand: _onHand,
                reasonId: selectedReason.id,
                reasonName: selectedReason.name,
                note: note.isEmpty ? null : note,
                updatedBy: currentUser.id,
                updatedByName: currentUser.displayName,
              );

      // The audit entry for a manual correction — the only place the
      // picked reason and typed note survive. Logging never throws
      // (ActivityLogger.log swallows failures), so a failed write cannot
      // undo the adjustment.
      await ref.read(activityLoggerProvider).logStockAdjustment(
            user: currentUser,
            productId: widget.product.id,
            productName: widget.product.name,
            sku: widget.product.sku,
            oldQuantity: result.before,
            newQuantity: result.after,
            reasonName: selectedReason.name,
            note: note.isEmpty ? null : note,
          );

      // Mirrors the old updateStock notifier path (product_provider.dart) and
      // the web hook's qc.invalidateQueries: any screen watching this
      // product, or the low-stock list, must see the new quantity.
      ref.invalidate(productByIdProvider(widget.product.id));
      ref.invalidate(lowStockProductsProvider);

      if (!mounted) return;
      final deltaLabel =
          result.delta >= 0 ? '+${result.delta}' : '${result.delta}';
      Navigator.pop(context, true);
      context.showSuccessSnackBar(
        'Stock adjusted · $deltaLabel → ${result.after} ${widget.product.unit}',
      );
    } on StaleOnHandException catch (e) {
      setState(() {
        _isProcessing = false;
        _onHand = e.currentOnHand;
        _staleNotice =
            'Someone else moved this stock — on hand is now ${e.currentOnHand}. Review and apply again.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }
}
