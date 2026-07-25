import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_fee_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Admin CRUD editor for the shop-fees list.
///
/// Lists active + inactive shop fees; supports add / edit / deactivate /
/// reactivate with name-exists validation. Inactive entries stay (greyed) so
/// admin can reactivate them; deactivating never breaks historical records,
/// which carry a snapshotted fee name/amount.
class ShopFeeEditorScreen extends ConsumerStatefulWidget {
  const ShopFeeEditorScreen({super.key});

  @override
  ConsumerState<ShopFeeEditorScreen> createState() =>
      _ShopFeeEditorScreenState();
}

class _ShopFeeEditorScreenState extends ConsumerState<ShopFeeEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final shopFeesAsync = ref.watch(allShopFeesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Shop Fees'),
      ),
      body: shopFeesAsync.when(
        data: (shopFees) => _buildList(context, shopFees),
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load shop fees: $e',
          onRetry: () => ref.invalidate(allShopFeesProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showShopFeeDialog(context),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ShopFeeEntity> shopFees) {
    if (shopFees.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.circleDollarSign,
        title: 'No shop fees yet',
        subtitle: 'Tap Add to create one.',
      );
    }

    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: shopFees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final shopFee = shopFees[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsCrudRow(
              name: shopFee.name,
              isActive: shopFee.isActive,
              leadingIcon: LucideIcons.circleDollarSign,
              onEdit: () => _showShopFeeDialog(context, existing: shopFee),
              onToggleActive: canManage ? () => _toggleActive(shopFee) : null,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                shopFee.defaultAmount != null
                    ? shopFee.defaultAmount!.toCurrency()
                    : 'No default — entered at register',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleActive(ShopFeeEntity shopFee) async {
    final ops = ref.read(shopFeeOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => shopFee.isActive
          ? ops.deactivate(shopFee.id)
          : ops.reactivate(shopFee.id),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        shopFee.isActive ? 'Shop fee deactivated' : 'Shop fee reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _showShopFeeDialog(
    BuildContext context, {
    ShopFeeEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (dialogContext) => _ShopFeeFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Shop fee created' : 'Shop fee updated',
    );
  }
}

class _ShopFeeFormDialog extends ConsumerStatefulWidget {
  const _ShopFeeFormDialog({this.existing});

  final ShopFeeEntity? existing;

  @override
  ConsumerState<_ShopFeeFormDialog> createState() =>
      _ShopFeeFormDialogState();
}

class _ShopFeeFormDialogState extends ConsumerState<_ShopFeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _defaultAmountController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _defaultAmountController = TextEditingController(
      text: existing?.defaultAmount != null
          ? existing!.defaultAmount!.toString()
          : '',
    );
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultAmountController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
    return AppDialog(
      title: _isEdit ? 'Edit Shop Fee' : 'New Shop Fee',
      leadingIcon: LucideIcons.circleDollarSign,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(LucideIcons.circleDollarSign),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Name is required';
                if (trimmed.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _defaultAmountController,
              decoration: const InputDecoration(
                labelText: 'Default amount (optional)',
                prefixIcon: Icon(LucideIcons.banknote),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                final parsed = double.tryParse(trimmed);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount greater than 0';
                }
                return null;
              },
            ),
            if (_isEdit && canManage) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'Visible in the shop-fee picker'
                      : 'Hidden from the picker (existing records keep matching)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: _isSaving ? () {} : () => Navigator.pop(context)),
        appDialogPrimary(context, _isEdit ? 'Save' : 'Create',
            onTap: _save, loading: _isSaving),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    // Optional field: blank collapses to null so we don't persist a zero
    // amount (and clearing a previously-set value nulls it out).
    final amountText = _defaultAmountController.text.trim();
    final defaultAmount = amountText.isEmpty ? null : double.parse(amountText);
    final ops = ref.read(shopFeeOperationsProvider.notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    final result = await context.runWithWaiting(
      () async {
        if (existing == null) {
          return ops.create(
            shopFee: ShopFeeEntity(
              id: '',
              name: name,
              isActive: true,
              defaultAmount: defaultAmount,
              createdAt: DateTime.now(),
            ),
          );
        }
        return ops.update(
          shopFee: existing.copyWith(
            name: name,
            isActive: _isActive,
            defaultAmount: defaultAmount,
            clearDefaultAmount: defaultAmount == null,
          ),
        );
      },
      message: existing == null ? 'Saving…' : 'Updating…',
    );

    if (!mounted) return;

    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      final err = ref.read(shopFeeOperationsProvider).error;
      context.showErrorSnackBar(
        err == null ? 'Failed to save shop fee' : 'Failed: $err',
      );
    }
  }
}
