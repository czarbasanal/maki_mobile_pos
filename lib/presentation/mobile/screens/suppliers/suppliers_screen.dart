import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen displaying list of suppliers.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? LucideIcons.eye : LucideIcons.eyeOff),
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm + 4,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search suppliers…',
                prefixIcon: Icon(LucideIcons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          var filtered = suppliers.where((s) {
            if (!_showInactive && !s.isActive) return false;
            if (_searchQuery.isNotEmpty) {
              return s.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  (s.contactPerson
                          ?.toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ??
                      false);
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return EmptyStateView(
              icon: LucideIcons.users,
              title: _searchQuery.isNotEmpty
                  ? 'No suppliers found'
                  : 'No suppliers yet',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Try a different search'
                  : 'Add your first supplier',
            );
          }

          return ListView.separated(
            itemCount: filtered.length,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final supplier = filtered[index];
              return _SupplierListTile(
                supplier: supplier,
                onTap: () =>
                    context.push('${RoutePaths.suppliers}/edit/${supplier.id}'),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(suppliersProvider),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () => context.push(RoutePaths.supplierAdd),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Supplier'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierListTile extends StatelessWidget {
  final SupplierEntity supplier;
  final VoidCallback onTap;

  const _SupplierListTile({
    required this.supplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final active = supplier.isActive;

    final tileBg = dark ? const Color(0x0DFFFFFF) : const Color(0x12283E46);
    final inactive = dark ? const Color(0xFF6C797C) : const Color(0xFF9AA0A3);
    final glyphColor =
        active ? (dark ? const Color(0xFF9FB0B0) : AppColors.brandSlate) : inactive;
    final titleColor = active
        ? theme.colorScheme.onSurface
        : (dark ? const Color(0xFF6C797C) : const Color(0xFF8A9296));
    final contactColor =
        active ? (dark ? const Color(0xFFA9B4B5) : const Color(0xFF5A6468)) : inactive;
    final chipColor =
        active ? (dark ? const Color(0xFFC9D2D2) : AppColors.brandSlate) : inactive;
    final chipBorder = active
        ? (dark ? const Color(0xFF2C3C3E) : const Color(0xFFE2E2E2))
        : (dark ? const Color(0xFF2C3C3E) : const Color(0xFFECECEC));
    final chevron = dark ? const Color(0xFF6C797C) : const Color(0xFF9AA0A3);

    return AppCard(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.briefcase, size: 21, color: glyphColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  supplier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: titleColor,
                    decoration: active ? null : TextDecoration.lineThrough,
                    decorationColor: titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (supplier.contactPerson != null)
                      Text(
                        supplier.contactPerson!,
                        style: TextStyle(fontSize: 13, color: contactColor),
                      ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.creditCard, size: 12, color: chipColor),
                          const SizedBox(width: 4),
                          Text(
                            supplier.transactionType.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: chipColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 18, color: chevron),
        ],
      ),
    );
  }
}
