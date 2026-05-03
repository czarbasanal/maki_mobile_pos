import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
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
                hintText: 'Search suppliers...',
                prefixIcon: Icon(CupertinoIcons.search),
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
              icon: CupertinoIcons.person_2,
              title: _searchQuery.isNotEmpty
                  ? 'No suppliers found'
                  : 'No suppliers yet',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Try a different search'
                  : 'Add your first supplier',
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.only(bottom: 80),
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
          child: FilledButton.icon(
            onPressed: () => context.push(RoutePaths.supplierAdd),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Add Supplier'),
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
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        leading: Icon(
          CupertinoIcons.briefcase,
          color: muted,
          size: 24,
        ),
        title: Text(
          supplier.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: supplier.isActive ? null : TextDecoration.lineThrough,
            color: supplier.isActive ? null : muted,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier.contactPerson != null) Text(supplier.contactPerson!),
            Text(
              supplier.transactionType.displayName,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
        trailing: Icon(CupertinoIcons.chevron_right, color: muted, size: 18),
        onTap: onTap,
      ),
    );
  }
}
