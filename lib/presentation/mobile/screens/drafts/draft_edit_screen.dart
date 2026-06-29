import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:uuid/uuid.dart';

/// Screen for editing/viewing a draft and converting to checkout.
class DraftEditScreen extends ConsumerStatefulWidget {
  final String draftId;

  const DraftEditScreen({
    super.key,
    required this.draftId,
  });

  @override
  ConsumerState<DraftEditScreen> createState() => _DraftEditScreenState();
}

class _DraftEditScreenState extends ConsumerState<DraftEditScreen> {
  bool _isLoading = false;
  bool _isDeleting = false;

  /// Local working copy so labor/mechanic edits render instantly; each edit is
  /// persisted through the FULL updateDraft path (NOT updateDraftItems, which
  /// writes only `items` and would drop labor).
  DraftEntity? _working;

  DraftEntity _sync(DraftEntity fromProvider) {
    final current = _working;
    if (current == null || current.id != fromProvider.id) {
      _working = fromProvider;
    }
    return _working!;
  }

  Future<void> _persistLabor(DraftEntity next) async {
    setState(() => _working = next);
    final actor = ref.read(currentUserProvider).valueOrNull;
    if (actor == null) return;
    await ref
        .read(draftOperationsProvider.notifier)
        .updateDraft(actor: actor, draft: next);
  }

  void _onMechanicChanged(String? id, String? name) {
    final base = _working;
    if (base == null) return;
    final next = (id == null)
        ? base.copyWith(clearMechanic: true, updatedAt: DateTime.now())
        : base.copyWith(
            mechanicId: id, mechanicName: name, updatedAt: DateTime.now());
    _persistLabor(next);
  }

  Future<void> _addOrEditLabor(DraftEntity draft,
      [LaborLineEntity? existing]) async {
    final result = await showDialog<LaborLineEntity>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (_) => _LaborLineDialog(line: existing),
    );
    if (result == null) return;
    final next = existing == null
        ? draft.addLaborLine(result)
        : draft.updateLaborLine(result);
    await _persistLabor(next);
  }

  Future<void> _removeLabor(DraftEntity draft, String lineId) async {
    await _persistLabor(draft.removeLaborLine(lineId));
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftByIdProvider(widget.draftId));

    return draftAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Draft...')),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ErrorStateView(
          message: 'Error loading draft: $error',
          action: ElevatedButton(
            onPressed: () => context.go(RoutePaths.drafts),
            child: const Text('Back to Drafts'),
          ),
        ),
      ),
      data: (draft) {
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Draft Not Found')),
            body: EmptyStateView(
              icon: Icons.search_off,
              title: 'Draft not found or has been deleted',
              action: ElevatedButton(
                onPressed: () => context.go(RoutePaths.drafts),
                child: const Text('Back to Drafts'),
              ),
            ),
          );
        }

        return _buildDraftContent(_sync(draft));
      },
    );
  }

  Widget _buildDraftContent(DraftEntity draft) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return LoadingOverlay(
      isLoading: _isLoading || _isDeleting,
      message: _isDeleting ? 'Deleting draft...' : 'Processing...',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            draft.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RoutePaths.drafts);
              }
            },
          ),
          actions: [
            // Delete button (red)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              color: AppColors.costUp(theme.brightness == Brightness.dark),
              onPressed: () => _confirmDelete(draft),
              tooltip: 'Delete Draft',
            ),
          ],
        ),
        body: Column(
          children: [
            // Draft info header
            Builder(builder: (context) {
              final muted = theme.colorScheme.onSurfaceVariant;
              final isDark = theme.brightness == Brightness.dark;
              final hairline = isDark
                  ? AppColors.darkHairline
                  : AppColors.lightHairline;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: hairline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: muted),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Created ${dateFormat.format(draft.createdAt)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    if (draft.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.edit, size: 14, color: muted),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Updated ${dateFormat.format(draft.updatedAt!)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                    if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(draft.notes!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              );
            }),

            // Items list
            Expanded(
              child: draft.items.isEmpty
                  ? _buildEmptyItems()
                  : ListView.builder(
                      itemCount: draft.items.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        return _buildDraftItem(draft.items[index]);
                      },
                    ),
            ),

            // Labor & Service (mechanic + labor lines) — editable anytime.
            _buildLaborSection(draft),

            // Summary and actions
            _buildSummarySection(draft),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItems() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shoppingCart, size: 56, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No items in this draft',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftItem(SaleItemEntity item) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      radius: AppRadius.md,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          // Quantity badge — outlined, no fill (1.4px, radius 10)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 1.4,
              ),
            ),
            child: Center(
              child: Text(
                '${item.quantity}x',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${item.sku}',
                  style: TextStyle(
                    fontFamily: AppTextStyles.monoFontFamily,
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
                Text(
                  '${item.unitPrice.toCurrency()} each',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            item.grossAmount.toCurrency(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLaborSection(DraftEntity draft) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wrench, size: 16, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Labor & Service',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addOrEditLabor(draft),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Labor'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          // Room above the picker so its floating "Mechanic" label isn't
          // clipped (same fix as the POS labor section).
          const SizedBox(height: AppSpacing.sm),
          MechanicPicker(
            selectedMechanicId: draft.mechanicId,
            onChanged: (m) => _onMechanicChanged(m?.id, m?.name),
          ),
          ...draft.laborLines.map((line) => _buildLaborLineRow(draft, line)),
        ],
      ),
    );
  }

  Widget _buildLaborLineRow(DraftEntity draft, LaborLineEntity line) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        radius: AppRadius.md,
        onTap: () => _addOrEditLabor(draft, line),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 4, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Icon(LucideIcons.wrench, size: 14, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              line.fee.toCurrency(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              visualDensity: VisualDensity.compact,
              color: muted,
              onPressed: () => _removeLabor(draft, line.id),
              tooltip: 'Remove labor line',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(DraftEntity draft) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SummaryRow(
              label: 'Subtotal',
              value:
                  draft.subtotal.toCurrency(),
            ),
            if (draft.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              SummaryRow(
                label: 'Discount',
                value:
                    '-${draft.totalDiscount.toCurrency()}',
                valueColor: AppColors.successText(isDark),
              ),
            ],
            if (draft.laborLines.isNotEmpty) ...[
              const SizedBox(height: 4),
              SummaryRow(
                label: draft.laborLines.length == 1
                    ? 'Labor (1 service)'
                    : 'Labor (${draft.laborLines.length} services)',
                value:
                    draft.laborSubtotal.toCurrency(),
              ),
            ],
            // Total row: "Total" 15/700 + "(n items)" 12.5/500 muted inline;
            // value 18/700 in onSurface. Border-top replaces the generic Divider.
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkHairline
                        : const Color(0xFFE5E3DE),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Total ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '(${draft.totalItemCount} items)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    draft.grandTotal.toCurrency(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        draft.items.isEmpty ? null : () => _editInPos(draft),
                    icon: const Icon(LucideIcons.edit),
                    label: const Text('Edit in POS'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: draft.items.isEmpty
                        ? null
                        : () => _proceedToCheckout(draft),
                    icon: const Icon(LucideIcons.shoppingCart),
                    label: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editInPos(DraftEntity draft) async {
    setState(() => _isLoading = true);

    try {
      // Load draft into cart and consume it — see drafts_list_screen for
      // the rationale on destructive load.
      ref.read(cartProvider.notifier).loadFromDraft(draft);
      ref.read(selectedDraftProvider.notifier).state = null;
      final actor = ref.read(currentUserProvider).valueOrNull;
      if (actor != null) {
        ref
            .read(draftOperationsProvider.notifier)
            .deleteDraft(actor: actor, draftId: draft.id);
      }

      if (mounted) {
        // Navigate to POS
        context.go(RoutePaths.pos);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error loading draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _proceedToCheckout(DraftEntity draft) async {
    setState(() => _isLoading = true);

    try {
      // Load draft into cart and consume it — see drafts_list_screen for
      // the rationale on destructive load.
      ref.read(cartProvider.notifier).loadFromDraft(draft);
      ref.read(selectedDraftProvider.notifier).state = null;
      final actor = ref.read(currentUserProvider).valueOrNull;
      if (actor != null) {
        ref
            .read(draftOperationsProvider.notifier)
            .deleteDraft(actor: actor, draftId: draft.id);
      }

      if (mounted) {
        // Navigate to checkout
        context.go(RoutePaths.checkout);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error loading draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete(DraftEntity draft) async {
    await showDeleteDraftDialog(context, draft, () => _deleteDraft(draft));
  }

  Future<void> _deleteDraft(DraftEntity draft) async {
    setState(() => _isDeleting = true);

    try {
      final actor = ref.read(currentUserProvider).value;
      if (actor == null) return;
      final success = await ref
          .read(draftOperationsProvider.notifier)
          .deleteDraft(actor: actor, draftId: draft.id);

      if (success && mounted) {
        context.showSuccessSnackBar('Draft deleted');
        context.go(RoutePaths.drafts);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error deleting draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

/// Add/edit a single free-form labor line (description + fee). Fee must be > 0.
class _LaborLineDialog extends StatefulWidget {
  const _LaborLineDialog({this.line});

  final LaborLineEntity? line;

  @override
  State<_LaborLineDialog> createState() => _LaborLineDialogState();
}

class _LaborLineDialogState extends State<_LaborLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _feeCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.line?.description ?? '');
    _feeCtrl = TextEditingController(
      text: (widget.line?.fee ?? 0) > 0
          ? widget.line!.fee.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final fee = double.parse(_feeCtrl.text.trim());
    final existing = widget.line;
    final line = LaborLineEntity(
      id: existing?.id ?? const Uuid().v4(),
      description: _descCtrl.text.trim(),
      fee: fee,
    );
    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.line == null ? 'Add Labor' : 'Edit Labor',
      leadingIcon: LucideIcons.wrench,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Engine tune-up',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _feeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Fee',
                prefixText: AppConstants.currencySymbol,
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null) return 'Enter a valid amount';
                if (parsed <= 0) return 'Fee must be greater than 0';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, widget.line == null ? 'Add' : 'Save',
            onTap: _submit),
      ],
    );
  }
}
