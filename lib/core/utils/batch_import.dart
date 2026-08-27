import 'package:csv/csv.dart';
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

/// CSV schema for the receiving batch-import flow.
///
/// Header row is required. Column names match case-insensitively. Order
/// is fixed (the existing `CsvImportDialog` infers position; we keep that
/// convention so users moving from the old 5-column flow can extend
/// rather than re-learn).
///
/// Required: sku, name, cost, price, quantity.
/// Optional: category, unit (defaults to "pcs"), reorder_level (defaults to 0).
const List<String> kBatchImportColumns = [
  'sku',
  'name',
  'category',
  'unit',
  'cost',
  'price',
  'quantity',
  'reorder_level',
];

/// SKU literal that triggers auto-generation at import time. Matches case-
/// insensitively. The classifier treats any row using this literal as a
/// new-product row regardless of whether the literal happens to collide
/// with an existing SKU.
const String kSkuGenerateLiteral = 'GENERATE';

/// Cost equality tolerance — matches `_processReceivingItem` in
/// receiving_repository_impl.dart so the classifier predicts the same
/// variation-spawning behavior the existing pipeline already enforces.
const double kCostEqualityTolerance = 0.01;

/// One parsed CSV row. Type-validated but not yet classified against
/// inventory. Field semantics match [ProductEntity] so the use case can
/// hand them off without further coercion.
class ParsedImportRow {
  /// 1-based source line number for error messages (header is line 1).
  final int rowNumber;
  final String sku;
  final String name;
  final String? category;
  final String unit;
  final double cost;
  final double price;
  final int quantity;
  final int reorderLevel;

  const ParsedImportRow({
    required this.rowNumber,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    required this.cost,
    required this.price,
    required this.quantity,
    required this.reorderLevel,
  });

  /// True when the SKU is the auto-generate literal.
  bool get autoGenerateSku => sku.toUpperCase() == kSkuGenerateLiteral;
}

/// Per-row parse error with the source line number.
class ParseError {
  final int rowNumber;
  final String message;
  const ParseError({required this.rowNumber, required this.message});

  @override
  String toString() => 'Row $rowNumber: $message';
}

/// Parser output — successful rows plus per-row errors. Callers decide
/// whether to abort on any error or proceed with the ok rows only.
class ParseResult {
  final List<ParsedImportRow> rows;
  final List<ParseError> errors;
  const ParseResult({required this.rows, required this.errors});
}

/// Parses [content] into [ParsedImportRow]s. Uses the `csv` package for
/// RFC 4180 compliance (quoted fields, embedded commas, escaped quotes).
///
/// The header row is required. Columns are matched **by position**, not
/// by header name — but the header name is checked to bail early on a
/// completely wrong file shape. Missing optional columns can be left
/// blank in any data row.
ParseResult parseBatchImportCsv(String content) {
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(content);

  if (rows.isEmpty) {
    return const ParseResult(
      rows: [],
      errors: [
        ParseError(rowNumber: 0, message: 'CSV is empty.'),
      ],
    );
  }

  // Validate header. We're lenient — we only require that the first
  // column header is "sku" (case-insensitive). The rest is positional.
  final header = rows.first.map((c) => '$c'.trim().toLowerCase()).toList();
  if (header.isEmpty || header.first != 'sku') {
    return const ParseResult(
      rows: [],
      errors: [
        ParseError(
          rowNumber: 1,
          message:
              'Header row missing or malformed. Expected first column "sku".',
        ),
      ],
    );
  }

  final parsed = <ParsedImportRow>[];
  final errors = <ParseError>[];

  for (var i = 1; i < rows.length; i++) {
    final lineNumber = i + 1; // 1-based, including header
    final cells = rows[i].map((c) => '$c'.trim()).toList();

    // Skip wholly empty rows so trailing newlines or blanks don't error.
    if (cells.every((c) => c.isEmpty)) continue;

    if (cells.length < 7) {
      errors.add(ParseError(
        rowNumber: lineNumber,
        message:
            'Expected at least 7 columns (sku..quantity), got ${cells.length}.',
      ));
      continue;
    }

    final sku = cells[0];
    final name = cells[1];
    final category = cells[2].isEmpty ? null : cells[2];
    final unit = cells[3].isEmpty ? 'pcs' : cells[3];
    final costStr = cells[4];
    final priceStr = cells[5];
    final quantityStr = cells[6];
    final reorderStr = cells.length > 7 ? cells[7] : '';

    if (sku.isEmpty) {
      errors.add(ParseError(rowNumber: lineNumber, message: 'sku is required.'));
      continue;
    }
    if (name.isEmpty) {
      errors.add(ParseError(rowNumber: lineNumber, message: 'name is required.'));
      continue;
    }

    final cost = double.tryParse(costStr);
    if (cost == null || cost < 0) {
      errors.add(ParseError(
        rowNumber: lineNumber,
        message: 'cost must be a non-negative number (got "$costStr").',
      ));
      continue;
    }
    final price = double.tryParse(priceStr);
    if (price == null || price < 0) {
      errors.add(ParseError(
        rowNumber: lineNumber,
        message: 'price must be a non-negative number (got "$priceStr").',
      ));
      continue;
    }
    final quantity = int.tryParse(quantityStr);
    if (quantity == null || quantity <= 0) {
      errors.add(ParseError(
        rowNumber: lineNumber,
        message: 'quantity must be a positive integer (got "$quantityStr").',
      ));
      continue;
    }
    final reorderLevel = reorderStr.isEmpty ? 0 : int.tryParse(reorderStr);
    if (reorderLevel == null || reorderLevel < 0) {
      errors.add(ParseError(
        rowNumber: lineNumber,
        message:
            'reorder_level must be a non-negative integer (got "$reorderStr").',
      ));
      continue;
    }

    parsed.add(ParsedImportRow(
      rowNumber: lineNumber,
      sku: sku,
      name: name,
      category: category,
      unit: unit,
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
    ));
  }

  return ParseResult(rows: parsed, errors: errors);
}

/// Classification of a parsed row against existing inventory. Subclasses
/// drive the use-case branching; this stays a base class (no Dart sealed
/// keyword to keep compatibility with the existing exhaustive-switch
/// pattern used elsewhere in the codebase).
abstract class ClassifiedRow {
  final ParsedImportRow row;
  const ClassifiedRow(this.row);
}

/// SKU matches an existing active product AND the cost matches. Receiving
/// will simply add the quantity to the existing product.
class ExistingMatchRow extends ClassifiedRow {
  final ProductEntity existing;
  const ExistingMatchRow({
    required ParsedImportRow row,
    required this.existing,
  }) : super(row);
}

/// SKU matches an existing active product but the cost differs. The
/// existing receiving completion flow will spawn a SKU variation
/// (`<sku>-N`) for the new cost — this class is just a forecast for the
/// preview UI; no behavior change vs. ExistingMatchRow at the use-case
/// level (we still pass `productId` of the original; the repo decides).
class CostMismatchRow extends ClassifiedRow {
  final ProductEntity existing;
  const CostMismatchRow({
    required ParsedImportRow row,
    required this.existing,
  }) : super(row);
}

/// SKU is not present in inventory (or is the GENERATE literal). The use
/// case must call `CreateProductUseCase` first to materialize the product,
/// then add a receiving line referencing the new product's id.
class NewProductRow extends ClassifiedRow {
  const NewProductRow({required ParsedImportRow row}) : super(row);
}

/// GENERATE row whose name + category already belongs to an active product.
/// The operator resolves it per row in the preview: make a variation of
/// [existing], or create it as a genuinely separate product.
class DuplicateNameRow extends ClassifiedRow {
  final ProductEntity existing;
  const DuplicateNameRow({
    required ParsedImportRow row,
    required this.existing,
  }) : super(row);
}

/// How the operator resolved a [DuplicateNameRow]: fold it into the matched
/// product as a variation (the default), or let it through as a genuinely
/// new, separate product.
enum DuplicateNameResolution { variation, newProduct }

/// Applies the operator's choice for [row]. `variation` re-runs the same
/// cost-tolerance check a typed-SKU row would get against [row].existing, so
/// it resolves to [ExistingMatchRow] or [CostMismatchRow] and flows through
/// the existing cost-mismatch/variation machinery unchanged. `newProduct`
/// drops the name match and lets the row create a fresh product, exactly as
/// an un-flagged GENERATE row would.
///
/// MIRRORS `resolveDuplicateName` in
/// web_admin/src/domain/receiving/classifyReceivingRows.ts.
ClassifiedRow resolveDuplicateName(
  DuplicateNameRow row,
  DuplicateNameResolution resolution,
) {
  if (resolution == DuplicateNameResolution.newProduct) {
    return NewProductRow(row: row.row);
  }
  final costsEqual =
      (row.existing.cost - row.row.cost).abs() <= kCostEqualityTolerance;
  return costsEqual
      ? ExistingMatchRow(row: row.row, existing: row.existing)
      : CostMismatchRow(row: row.row, existing: row.existing);
}

/// Classifies [rows] against [activeProducts]. SKU lookup is case-
/// insensitive. Pure — no I/O.
List<ClassifiedRow> classifyRows({
  required List<ParsedImportRow> rows,
  required List<ProductEntity> activeProducts,
}) {
  final bySkuLower = <String, ProductEntity>{
    for (final p in activeProducts) p.sku.toLowerCase(): p,
  };
  final byNameKey = <String, ProductEntity>{};
  for (final p in activeProducts) {
    // A cost variation inherits its base's name/category, so it carries the
    // SAME nameKey — skip it so a base is always preferred over a variation.
    if (p.baseSku != null) continue;
    // First writer wins: duplicates already exist, and naming one is enough.
    byNameKey.putIfAbsent(productDuplicateKey(p.name, p.category), () => p);
  }

  return rows.map<ClassifiedRow>((row) {
    if (row.autoGenerateSku) {
      final match = byNameKey[productDuplicateKey(row.name, row.category)];
      if (match != null) return DuplicateNameRow(row: row, existing: match);
      return NewProductRow(row: row);
    }
    final existing = bySkuLower[row.sku.toLowerCase()];
    if (existing == null) {
      return NewProductRow(row: row);
    }
    final costsEqual =
        (existing.cost - row.cost).abs() <= kCostEqualityTolerance;
    if (costsEqual) {
      return ExistingMatchRow(row: row, existing: existing);
    }
    return CostMismatchRow(row: row, existing: existing);
  }).toList();
}
