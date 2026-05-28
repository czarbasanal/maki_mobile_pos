import 'package:csv/csv.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

/// Builds a CSV of [products] using the same column schema the Receiving
/// batch-import reads ([kBatchImportColumns]), so an export re-imports
/// cleanly via `parseBatchImportCsv`.
///
/// Emits LF line endings to match the parser's `eol: '\n'`.
String buildInventoryCsv(List<ProductEntity> products) {
  final rows = <List<dynamic>>[
    kBatchImportColumns,
    for (final p in products)
      [
        p.sku,
        p.name,
        p.category ?? '',
        p.unit,
        p.cost.toStringAsFixed(2),
        p.price.toStringAsFixed(2),
        p.quantity,
        p.reorderLevel,
      ],
  ];

  return const ListToCsvConverter(eol: '\n').convert(rows);
}
