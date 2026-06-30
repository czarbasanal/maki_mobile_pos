import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/sales/void_status_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Admin queue of void requests (opened from the dashboard notification bell).
class VoidRequestsScreen extends ConsumerWidget {
  const VoidRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voidRequestsProvider);
    final unread = ref.watch(unreadVoidRequestCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Void Requests'),
        actions: [_MarkAllReadAction(enabled: unread > 0)],
      ),
      body: async.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(message: 'Error: $e'),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          final sorted = [...list]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final pending = sorted.where((r) => r.isPending).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _CountCaption(pending: pending, total: sorted.length),
              ...sorted.map((r) => _RequestRow(request: r)),
            ],
          );
        },
      ),
    );
  }
}

class _MarkAllReadAction extends ConsumerWidget {
  const _MarkAllReadAction({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = enabled
        ? theme.colorScheme.primary
        : (dark ? const Color(0xFF4A5A5E) : const Color(0xFFB7BDC0));
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: enabled
          ? () => ref.read(voidRequestOperationsProvider.notifier).markAllRead()
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCheck, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              'Mark all read',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCaption extends StatelessWidget {
  const _CountCaption({required this.pending, required this.total});
  final int pending;
  final int total;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = VoidStatusStyle.of(VoidRequestStatus.pending, dark: dark);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: s.tint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$pending pending',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: s.textColor),
            ),
          ),
          const SizedBox(width: 7),
          Text('· $total total',
              style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request});
  final VoidRequestEntity request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final hint = dark ? AppColors.darkTextHint : AppColors.lightTextHint;
    final s = VoidStatusStyle.of(request.status, dark: dark);
    final df = DateFormat('MMM d, h:mm a');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      radius: AppRadius.field,
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await ref
            .read(voidRequestOperationsProvider.notifier)
            .markRead(request.id);
        if (request.isPending && context.mounted) {
          _showResolveSheet(context, ref, request);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: s.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(s.squareIcon, size: 20, color: s.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        request.saleNumber,
                        style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      request.saleGrandTotal.toCurrency(),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.requestedByName} · ${request.reason}',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.45, color: muted),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _StatusPill(style: s),
                    const SizedBox(width: 8),
                    Text(df.format(request.createdAt),
                        style: TextStyle(fontSize: 11.5, color: hint)),
                  ],
                ),
              ],
            ),
          ),
          if (!request.read) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? AppColors.errorOnDark : AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});
  final VoidStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.pillIcon, size: 11, color: style.textColor),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: style.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final hint = dark ? AppColors.darkTextHint : AppColors.lightTextHint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 30, 40, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    dark ? const Color(0x0DFFFFFF) : const Color(0x0F283E46),
              ),
              child: Icon(LucideIcons.bell, size: 34, color: hint),
            ),
            const SizedBox(height: 16),
            Text('No void requests',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'When a cashier requests a void, it appears here for your review.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: hint),
            ),
          ],
        ),
      ),
    );
  }
}

void _showResolveSheet(
    BuildContext screenContext, WidgetRef ref, VoidRequestEntity r) {
  final dark = Theme.of(screenContext).brightness == Brightness.dark;
  showModalBottomSheet(
    context: screenContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (sheetContext) => _ResolveSheet(request: r, parentRef: ref),
  );
}

class _ResolveSheet extends StatelessWidget {
  const _ResolveSheet({required this.request, required this.parentRef});
  final VoidRequestEntity request;
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = VoidStatusStyle.of(VoidRequestStatus.pending, dark: dark);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) => AppBottomSheet(
        leadingIcon: LucideIcons.clock,
        title: 'Void this sale?',
        subtitle: 'Requested by ${request.requestedByName}',
        onClose: () => Navigator.pop(sheetContext),
        bodyExpands: true,
        body: Column(
          children: [
            // Reason box (status-tinted) — kept as body content.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: s.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.quote, size: 15, color: s.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                              fontSize: 12.5, height: 1.4, color: s.textColor),
                          children: [
                            const TextSpan(
                                text: 'Reason',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' · ${request.reason}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Receipt
            Expanded(
              child: Consumer(
                builder: (ctx, ref, _) {
                  final saleAsync = ref.watch(saleByIdProvider(request.saleId));
                  return saleAsync.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorStateView(message: 'Error: $e'),
                    data: (sale) => sale == null
                        ? const EmptyStateView(
                            icon: LucideIcons.fileText,
                            title: 'Sale not found',
                          )
                        : _Receipt(sale: sale, controller: scrollController),
                  );
                },
              ),
            ),
          ],
        ),
        footer: Row(
          children: [
            Expanded(
              child: _SheetButton(
                label: 'Reject',
                icon: LucideIcons.x,
                outlined: true,
                color: dark ? AppColors.errorOnDark : AppColors.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _rejectDialog(screenContextOf(context), parentRef, request);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SheetButton(
                label: 'Approve',
                icon: LucideIcons.check,
                outlined: false,
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _approveDialog(screenContextOf(context), parentRef, request);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The dialogs must anchor on the screen's navigator, not the sheet's, since
  // the sheet is being popped. We use the root navigator context.
  BuildContext screenContextOf(BuildContext sheetCtx) =>
      Navigator.of(sheetCtx, rootNavigator: true).context;
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.sale, required this.controller});
  final SaleEntity sale;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final hairline = AppColors.hairline(dark);
    final df = DateFormat('MMM d, y · h:mm a');

    final rows = <Widget>[];
    for (var i = 0; i < sale.items.length; i++) {
      final item = sale.items[i];
      final net = item.calculateNetAmount(isPercentage: sale.isPercentageDiscount);
      rows.add(_lineRow(
        theme: theme,
        muted: muted,
        hairline: hairline,
        last: i == sale.items.length - 1 && sale.laborLines.isEmpty,
        leading: _qtyChip(theme, '×${item.quantity}'),
        name: item.name,
        sub: '${item.sku} · ${item.unitPrice.toCurrency()}/pc',
        amount: net.toCurrency(),
      ));
    }
    for (var i = 0; i < sale.laborLines.length; i++) {
      final line = sale.laborLines[i];
      rows.add(_lineRow(
        theme: theme,
        muted: muted,
        hairline: hairline,
        last: i == sale.laborLines.length - 1,
        leading: _laborChip(theme, dark),
        name: line.description,
        sub: (sale.mechanicName != null && sale.mechanicName!.isNotEmpty)
            ? sale.mechanicName!
            : 'Labor',
        amount: line.fee.toCurrency(),
      ));
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                sale.saleNumber,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${df.format(sale.createdAt)} · ${sale.cashierName}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total to void',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                sale.grandTotal.toCurrency(),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyChip(ThemeData theme, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(text,
            style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _laborChip(ThemeData theme, bool dark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary
              .withValues(alpha: dark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text('Labor',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _lineRow({
    required ThemeData theme,
    required Color muted,
    required Color hairline,
    required bool last,
    required Widget leading,
    required String name,
    required String sub,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.outlined,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool outlined;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: outlined ? null : color,
          borderRadius: BorderRadius.circular(15),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: outlined ? color : onColor),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: outlined ? color : onColor)),
          ],
        ),
      ),
    );
  }
}

// ============================ dialogs ============================

void _approveDialog(
    BuildContext context, WidgetRef ref, VoidRequestEntity r) {
  final controller = TextEditingController();
  var obscure = true;
  showDialog(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final dark = theme.brightness == Brightness.dark;
      final green = AppColors.successText(dark);
      return StatefulBuilder(
        builder: (ctx, setState) => _DialogShell(
          iconSquare: _DialogIcon(
            icon: LucideIcons.shieldCheck,
            color: green,
            tint: dark ? const Color(0x294CAF50) : AppColors.successLight,
          ),
          title: 'Approve void',
          subtitle: 'Confirm with your admin password',
          field: _PasswordField(
            controller: controller,
            obscure: obscure,
            onToggle: () => setState(() => obscure = !obscure),
          ),
          actionLabel: 'Approve',
          actionColor: dark ? AppColors.successOnDarkIcon : AppColors.success,
          onAction: () async {
            final pw = controller.text;
            Navigator.pop(dialogContext);
            final err = await ref
                .read(voidRequestOperationsProvider.notifier)
                .approve(request: r, password: pw);
            if (context.mounted) {
              err == null
                  ? context.showSuccessSnackBar('Sale voided')
                  : context.showErrorSnackBar(err);
            }
          },
        ),
      );
    },
  );
}

void _rejectDialog(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) {
      final dark = Theme.of(dialogContext).brightness == Brightness.dark;
      return _DialogShell(
        iconSquare: _DialogIcon(
          icon: LucideIcons.xCircle,
          color: dark ? AppColors.errorOnDark : AppColors.error,
          tint: dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336),
        ),
        title: 'Reject request',
        subtitle: 'Tell the cashier why',
        field: _ReasonField(controller: controller),
        actionLabel: 'Reject',
        actionColor: AppColors.error,
        onAction: () async {
          final reason = controller.text;
          Navigator.pop(dialogContext);
          final err = await ref
              .read(voidRequestOperationsProvider.notifier)
              .reject(request: r, rejectionReason: reason);
          if (context.mounted) {
            err == null
                ? context.showSuccessSnackBar('Request rejected')
                : context.showErrorSnackBar(err);
          }
        },
      );
    },
  );
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.iconSquare,
    required this.title,
    required this.subtitle,
    required this.field,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });
  final Widget iconSquare;
  final String title;
  final String subtitle;
  final Widget field;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: dark
            ? const BorderSide(color: AppColors.darkHairline)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                iconSquare,
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field,
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: muted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon(
      {required this.icon, required this.color, required this.tint});
  final IconData icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 21, color: color),
      );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text('Password', style: TextStyle(fontSize: 12, color: muted)),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            prefixIcon: Icon(LucideIcons.lock,
                size: 17, color: theme.colorScheme.primary),
            suffixIcon: IconButton(
              icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 17, color: muted),
              onPressed: onToggle,
            ),
            border: _border(theme, false),
            enabledBorder: _border(theme, false),
            focusedBorder: _border(theme, true),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(ThemeData theme, bool focused) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: focused
              ? theme.colorScheme.primary
              : (theme.brightness == Brightness.dark
                  ? AppColors.darkInputBorder
                  : AppColors.lightInputBorder),
          width: focused ? 1.5 : 1,
        ),
      );
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text('Reason', style: TextStyle(fontSize: 12, color: muted)),
        ),
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            hintText: 'Add a short reason…',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: _border(theme, dark, false),
            enabledBorder: _border(theme, dark, false),
            focusedBorder: _border(theme, dark, true),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(ThemeData theme, bool dark, bool focused) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: focused
              ? theme.colorScheme.primary
              : (dark ? AppColors.darkInputBorder : AppColors.lightInputBorder),
          width: focused ? 1.5 : 1,
        ),
      );
}
