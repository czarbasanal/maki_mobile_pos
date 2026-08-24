// One payslip: the receipt render + Save PNG + Delete. The receipt is a
// FROZEN snapshot — this screen renders the stored figures verbatim.
// The RepaintBoundary wraps the receipt INSIDE the scrollable so a slip
// taller than the viewport still captures completely.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/payslip_png.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/hr/payslip_receipt.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

class PayslipDetailScreen extends ConsumerStatefulWidget {
  const PayslipDetailScreen({super.key, required this.payslipId});

  final String payslipId;

  @override
  ConsumerState<PayslipDetailScreen> createState() =>
      _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends ConsumerState<PayslipDetailScreen> {
  final _receiptKey = GlobalKey();
  bool _isSavingPng = false;

  @override
  Widget build(BuildContext context) {
    final payslipAsync = ref.watch(payslipByIdProvider(widget.payslipId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.hr),
        ),
        title: const Text('Payslip'),
        actions: [
          payslipAsync.maybeWhen(
            data: (p) => p == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(LucideIcons.trash2),
                    tooltip: 'Delete payslip',
                    onPressed: () => _confirmDelete(p),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: payslipAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load payslip: $e',
          onRetry: () =>
              ref.invalidate(payslipByIdProvider(widget.payslipId)),
        ),
        data: (payslip) {
          if (payslip == null) {
            // Deleted (possibly from the web) while this screen was open —
            // say so instead of crashing on a null snapshot.
            return const EmptyStateView(
              icon: LucideIcons.receipt,
              title: 'Payslip not found',
              subtitle: 'It may have been deleted.',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Center(
                  child: RepaintBoundary(
                    key: _receiptKey,
                    child: PayslipReceipt(payslip: payslip),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSavingPng ? null : () => _savePng(payslip),
                    icon: const Icon(LucideIcons.imageDown),
                    label: Text(_isSavingPng ? 'Preparing…' : 'Save as image'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Folds common Latin diacritics to base letters before slugging — a name
  // like Muñoz must file as munoz, not mu-oz (the same bug web's slugify had
  // and fixed; Dart has no NFD normalize, so a small fold table suffices).
  static const _folds = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  Future<void> _savePng(PayslipEntity payslip) async {
    setState(() => _isSavingPng = true);
    var name = payslip.employeeName.toLowerCase();
    _folds.forEach((k, v) => name = name.replaceAll(k, v));
    final slug = name
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final ok = await savePayslipPng(
      context,
      _receiptKey,
      'payslip-$slug-${payslip.periodStart}.png',
    );
    if (!mounted) return;
    setState(() => _isSavingPng = false);
    if (!ok) context.showErrorSnackBar('Could not render the payslip image');
  }

  Future<void> _confirmDelete(PayslipEntity payslip) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this payslip?',
      message: 'The payslip for "${payslip.employeeName}" '
          '(${payslip.periodStart}) will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(hrOperationsProvider.notifier)
        .deletePayslip(payslip.id, payslip.employeeName);
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar('Payslip deleted');
      context.goBackOr(RoutePaths.hr);
    } else {
      context.showErrorSnackBar('Failed to delete');
    }
  }
}
