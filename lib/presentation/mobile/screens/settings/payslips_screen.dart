// Generated payslips, newest period first (the repository's fixed sort —
// periodStart desc, employee A→Z within a period). Row tap opens the receipt
// detail.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

class PayslipsScreen extends ConsumerWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(payslipsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Payslips'),
      ),
      body: payslipsAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load payslips: $e',
          onRetry: () => ref.invalidate(payslipsProvider),
        ),
        data: (payslips) {
          if (payslips.isEmpty) {
            return const EmptyStateView(
              icon: LucideIcons.receipt,
              title: 'No payslips yet',
              subtitle: 'Generate one from Payroll.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: payslips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _PayslipRow(payslip: payslips[index]),
          );
        },
      ),
    );
  }
}

class _PayslipRow extends StatelessWidget {
  const _PayslipRow({required this.payslip});

  final PayslipEntity payslip;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _periodLabel {
    final s = parseIsoLocalDate(payslip.periodStart);
    final e = parseIsoLocalDate(payslip.periodEnd);
    return '${_months[s.month - 1]} ${s.day} – ${_months[e.month - 1]} ${e.day}, ${e.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      radius: 14,
      onTap: () =>
          context.push('${RoutePaths.hrPayslips}/${payslip.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payslip.employeeName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _periodLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payslip.computed.net.toCurrency(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.monoFontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gross ${payslip.computed.gross.toCurrency()}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
