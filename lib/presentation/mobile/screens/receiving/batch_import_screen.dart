import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Standalone CSV-driven receiving import.
///
/// Two-step flow: pick file (with optional supplier) → preview the
/// classification → commit. The use case
/// (`BatchImportReceivingUseCase`) does the heavy lifting; this screen is
/// just orchestration and presentation.
class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

enum _Phase { idle, parsing, preview, importing, done, errored }

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  _Phase _phase = _Phase.idle;
  ParseResult? _parseResult;
  List<ClassifiedRow>? _classified;
  String? _supplierId;
  String? _supplierName;
  String? _errorMessage;
  String? _completedRefNumber;

  Future<void> _pickAndParse() async {
    setState(() {
      _phase = _Phase.parsing;
      _errorMessage = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null) {
        setState(() => _phase = _Phase.idle);
        return;
      }
      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _phase = _Phase.errored;
          _errorMessage = 'Could not read file contents.';
        });
        return;
      }
      final content = utf8.decode(bytes);
      final parsed = parseBatchImportCsv(content);

      // Snapshot inventory to classify against.
      final products = await ref.read(productsProvider.future);
      final classified = classifyRows(
        rows: parsed.rows,
        activeProducts: products.where((p) => p.isActive).toList(),
      );

      setState(() {
        _parseResult = parsed;
        _classified = classified;
        _phase = _Phase.preview;
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.errored;
        _errorMessage = 'Failed to read CSV: $e';
      });
    }
  }

  Future<void> _commit() async {
    final classified = _classified;
    if (classified == null || classified.isEmpty) return;
    setState(() {
      _phase = _Phase.importing;
      _errorMessage = null;
    });
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        throw Exception('User not signed in.');
      }
      final mapping = await ref.read(costCodeMappingProvider.future);
      final useCase = ref.read(batchImportReceivingUseCaseProvider);
      final result = await useCase.execute(
        actor: user,
        classified: classified,
        costCodeMapping: mapping,
        supplierId: _supplierId,
        supplierName: _supplierName,
      );
      if (!result.success) {
        setState(() {
          _phase = _Phase.errored;
          _errorMessage = result.errorMessage ?? 'Import failed.';
        });
        return;
      }
      ref.invalidate(recentReceivingsProvider);
      ref.invalidate(productsProvider);
      setState(() {
        _phase = _Phase.done;
        _completedRefNumber = result.data?.referenceNumber;
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.errored;
        _errorMessage = '$e';
      });
    }
  }

  void _resetToIdle() {
    setState(() {
      _phase = _Phase.idle;
      _parseResult = null;
      _classified = null;
      _errorMessage = null;
      _completedRefNumber = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: const Text('Batch Import'),
      ),
      body: switch (_phase) {
        _Phase.idle => _buildIdle(),
        _Phase.parsing => _buildSpinner('Parsing CSV…'),
        _Phase.preview => _buildPreview(),
        _Phase.importing => _buildSpinner('Importing…'),
        _Phase.done => _buildDone(),
        _Phase.errored => _buildErrored(),
      },
    );
  }

  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CsvFormatHelp(),
          const SizedBox(height: AppSpacing.md),
          _SupplierFilter(
            selectedSupplierId: _supplierId,
            onChanged: (id, name) {
              setState(() {
                _supplierId = id;
                _supplierName = name;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _pickAndParse,
            icon: const Icon(CupertinoIcons.cloud_upload),
            label: const Text('Pick CSV file'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinner(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final classified = _classified ?? const [];
    final parseErrors = _parseResult?.errors ?? const [];
    final existing =
        classified.whereType<ExistingMatchRow>().length;
    final mismatch = classified.whereType<CostMismatchRow>().length;
    final newProducts = classified.whereType<NewProductRow>().length;
    final hasNewProducts = newProducts > 0;

    final user = ref.watch(currentUserProvider).valueOrNull;
    final canAddProduct = user != null &&
        RolePermissions.hasPermission(user.role, Permission.addProduct);
    final blockedByPermission = hasNewProducts && !canAddProduct;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _SummaryChips(
                existing: existing,
                mismatch: mismatch,
                newProducts: newProducts,
                errors: parseErrors.length,
              ),
              if (blockedByPermission) ...[
                const SizedBox(height: AppSpacing.sm),
                _Banner(
                  color: AppColors.error,
                  icon: CupertinoIcons.exclamationmark_circle,
                  text:
                      'This file contains $newProducts new product(s). Auto-creating products requires admin permission.',
                ),
              ],
              if (parseErrors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _ErrorList(errors: parseErrors),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final c in classified) _ClassifiedRowTile(c: c),
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetToIdle,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (classified.isEmpty || blockedByPermission)
                      ? null
                      : _commit,
                  icon: const Icon(CupertinoIcons.arrow_right_circle),
                  label: Text('Import ${classified.length} row(s)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Import completed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_completedRefNumber != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reference: $_completedRefNumber',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => context.goBackOr(RoutePaths.receiving),
            child: const Text('Back to receiving'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Import another'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrored() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _resetToIdle,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _CsvFormatHelp extends StatelessWidget {
  const _CsvFormatHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ExpansionTile(
        title: Text('CSV format', style: theme.textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: const [
          Text(
            'Required columns (in order): sku, name, category, unit, cost, '
            'price, quantity, reorder_level.\n\n'
            '• Header row required. First column header must be "sku".\n'
            '• unit defaults to "pcs"; reorder_level defaults to 0.\n'
            '• To auto-generate a SKU for a new product, use the literal '
            'GENERATE in the sku column.\n'
            '• If the sku matches an existing product with the same cost, '
            'the quantity is added to the existing product. If the cost '
            'differs, a SKU variation (sku-1, sku-2, …) is created so '
            'existing prices stay intact.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SupplierFilter extends ConsumerWidget {
  const _SupplierFilter({
    required this.selectedSupplierId,
    required this.onChanged,
  });

  final String? selectedSupplierId;
  final void Function(String? id, String? name) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    return suppliersAsync.when(
      data: (suppliers) {
        final items = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('No supplier'),
          ),
          ...suppliers.map(
            (s) => DropdownMenuItem<String?>(
              value: s.id,
              child: Text(s.name),
            ),
          ),
        ];
        return AppDropdown<String?>(
          initialValue: selectedSupplierId,
          decoration: const InputDecoration(
            labelText: 'Supplier (applies to all rows)',
            prefixIcon: Icon(CupertinoIcons.briefcase),
          ),
          items: items,
          onChanged: (id) {
            final name = id == null
                ? null
                : suppliers.firstWhere((s) => s.id == id).name;
            onChanged(id, name);
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load suppliers'),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.existing,
    required this.mismatch,
    required this.newProducts,
    required this.errors,
  });

  final int existing;
  final int mismatch;
  final int newProducts;
  final int errors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(label: 'Match', count: existing, color: AppColors.success),
        _Chip(
          label: 'Cost variation',
          count: mismatch,
          color: AppColors.warningDark,
        ),
        _Chip(label: 'New product', count: newProducts, color: AppColors.info),
        if (errors > 0)
          _Chip(label: 'Errors', count: errors, color: AppColors.error),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x22),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.errors});

  final List<ParseError> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skipped rows:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$e',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassifiedRowTile extends StatelessWidget {
  const _ClassifiedRowTile({required this.c});

  final ClassifiedRow c;

  ({String label, Color color}) _badge() {
    if (c is ExistingMatchRow) {
      return (label: 'Match', color: AppColors.success);
    }
    if (c is CostMismatchRow) {
      return (label: 'Variation', color: AppColors.warningDark);
    }
    return (label: 'New', color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final badge = _badge();
    final row = c.row;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${row.sku} • ${row.quantity} ${row.unit} • cost ${row.cost.toStringAsFixed(2)}',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badge.color.withAlpha(0x22),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge.label,
                style: TextStyle(
                  color: badge.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
