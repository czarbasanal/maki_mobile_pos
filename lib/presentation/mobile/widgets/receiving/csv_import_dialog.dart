import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/import_preview.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Dialog for importing receiving items from a CSV into the current receiving
/// form. Thin client of the shared batch-import pipeline: it parses with
/// [parseBatchImportCsv], classifies against active inventory, previews via
/// [ImportPreview], and on confirm resolves rows with [ReceivingImportResolver]
/// (creating new products inline) before handing items back through [onImport].
class CsvImportDialog extends ConsumerStatefulWidget {
  final void Function(List<ReceivingItemEntity> items) onImport;

  const CsvImportDialog({super.key, required this.onImport});

  @override
  ConsumerState<CsvImportDialog> createState() => CsvImportDialogState();
}

class CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  ParseResult? _parseResult;
  List<ClassifiedRow>? _classified;

  Future<void> _selectFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parseResult = null;
      _classified = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not read file contents.';
        });
        return;
      }
      await parseAndClassifyForTest(utf8.decode(bytes));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse CSV: $e';
      });
    }
  }

  /// Parses + classifies [content] against a snapshot of active products and
  /// updates state. Named `…ForTest` because it is the headless seam the widget
  /// test drives, but it is the same code path `_selectFile` uses after reading
  /// bytes.
  @visibleForTesting
  Future<void> parseAndClassifyForTest(String content) async {
    final parsed = parseBatchImportCsv(content);
    final products = await ref.read(productsProvider.future);
    final classified = classifyRows(
      rows: parsed.rows,
      activeProducts: products.where((p) => p.isActive).toList(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _parseResult = parsed;
      _classified = classified;
    });
  }

  Future<void> _confirm() async {
    final classified = _classified;
    if (classified == null || classified.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        throw Exception('User not signed in.');
      }
      final mapping = await ref.read(costCodeMappingProvider.future);
      final form = ref.read(currentReceivingProvider);
      final resolver = ref.read(receivingImportResolverProvider);
      final resolved = await resolver.resolve(
        actor: user,
        classified: classified,
        costCodeMapping: mapping,
        supplierId: form.supplierId,
        supplierName: form.supplierName,
      );
      if (!mounted) return;
      widget.onImport(resolved.items);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classified = _classified;
    final canImport =
        classified != null && classified.isNotEmpty && !_isLoading;
    return AppDialog(
      title: 'Import from CSV',
      leadingIcon: LucideIcons.uploadCloud,
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Columns (in order): sku, name, category, unit, cost, price, '
                'quantity, reorder_level. Header row required; first column '
                'must be "sku". Use GENERATE in the sku column to auto-create.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _isLoading && _parseResult == null
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: _isLoading ? null : _selectFile,
                        icon: const Icon(LucideIcons.folderOpen),
                        label: const Text('Select CSV file'),
                      ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              if (_parseResult != null && classified != null) ...[
                const SizedBox(height: AppSpacing.md),
                ImportPreview(
                  parseResult: _parseResult!,
                  classified: classified,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: () => Navigator.pop(context)),
        if (classified != null && classified.isNotEmpty)
          FilledButton(
            onPressed: canImport ? _confirm : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              textStyle: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Import ${classified.length} row(s)'),
          ),
      ],
    );
  }
}
