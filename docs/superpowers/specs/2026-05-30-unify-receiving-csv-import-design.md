# Unify Receiving CSV Import — Design Spec

**Date:** 2026-05-30
**Status:** Approved
**Branch:** feature/admin-editable-sku (or a dedicated branch)

## Problem

The receiving module has **two divergent CSV import paths**:

1. **Batch import** — [batch_import_screen.dart](../../../lib/presentation/mobile/screens/receiving/batch_import_screen.dart)
   → `parseBatchImportCsv` ([core/utils/batch_import.dart](../../../lib/core/utils/batch_import.dart))
   → `classifyRows` → `BatchImportReceivingUseCase`. RFC-4180 compliant (`csv` package),
   8 columns (`sku,name,category,unit,cost,price,quantity,reorder_level`), accumulates
   per-row errors, creates new products and spawns SKU variations on cost mismatch.

2. **Inline dialog** — [csv_import_dialog.dart](../../../lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart),
   opened from [bulk_receiving_screen.dart](../../../lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart).
   Naive `line.split(',')` parser (`_parseCsv`), 5 columns
   (`sku,name,quantity,unit,unitCost`), throws on first bad row, no product creation,
   and sets `costCode: ''` (latent bug — items rely on something downstream to encode).

Consequences: a CSV authored for one path will not load in the other; the dialog parser
breaks on quoted commas (e.g. `"Widget, Large"`); error reporting and validation rules
differ; cost-code encoding is inconsistent.

## Goals

- One CSV format and one parser everywhere (the 8-column batch format).
- The inline dialog becomes a **thin client** of the shared pipeline, with **full parity**:
  it can create new products inline and add resolved items to the current receiving form.
- Eliminate the naive parser and the `costCode: ''` bug.
- Extract the duplicated "resolve classified rows → receiving items (+create products)"
  logic into a single shared service.

## Non-Goals

- Changing the CSV schema, the cost-code cipher, or the variation-spawning rules.
- Reworking how `completeReceiving` / `_processReceivingItem` adjusts stock.
- Adding a transaction/batch around product creation + stock updates (existing behavior
  is preserved; orphan risk is documented, not solved here).
- Unrelated refactoring of the receiving screens beyond what serves this unification.

## Architecture

### New unit — `ReceivingImportResolver`

Path: `lib/domain/usecases/receiving/receiving_import_resolver.dart`

A plain domain service (not a `UseCase` subclass) that owns the resolution step currently
inlined as steps 2–3 of `BatchImportReceivingUseCase`.

```dart
/// Result of resolving classified import rows into receiving items.
class ResolvedImport {
  final List<ReceivingItemEntity> items;
  final List<ProductEntity> createdProducts; // newly materialized, for caller awareness
  const ResolvedImport({required this.items, required this.createdProducts});
}

/// Thrown when resolution cannot complete (e.g. a product fails to create).
/// Subclass of AppException so callers can use UseCaseResult.fromException.
class ReceivingImportException extends AppException {
  const ReceivingImportException({required String message}) : super(message: message);
}

class ReceivingImportResolver {
  final CreateProductUseCase _createProductUseCase;
  final Uuid _uuid;

  ReceivingImportResolver({
    required CreateProductUseCase createProductUseCase,
    Uuid? uuid,
  })  : _createProductUseCase = createProductUseCase,
        _uuid = uuid ?? const Uuid();

  /// Asserts `addProduct` only when the classification contains NewProductRow(s).
  /// Creates a fresh product (quantity 0, costCode-encoded, supplier from caller)
  /// for every NewProductRow; builds a ReceivingItemEntity for every classified row.
  /// Throws ReceivingImportException if any product creation fails (already-created
  /// products are left in place — matches existing batch behavior).
  Future<ResolvedImport> resolve({
    required UserEntity actor,
    required List<ClassifiedRow> classified,
    required CostCodeEntity costCodeMapping,
    String? supplierId,
    String? supplierName,
  }) async { ... }
}
```

Resolution rules (unchanged from the current use case, lines 84–152):
- `NewProductRow`: SKU = `GENERATE` → `SkuGenerator.generateForName(name)`, else as-typed.
  Product created with `quantity: 0`, `costCode: costCodeMapping.encode(cost)`, supplier
  from caller, `isActive: true`, category from row.
- Item built for every row: existing/cost-mismatch target the stored `existing.id`
  (cost-mismatch passes the **new** CSV cost so completion spawns the variation), new rows
  target the just-created id.
- `costCode` on each item = `costCodeMapping.encode(row.cost)`.
- Defensive `StateError` on unknown `ClassifiedRow` subtype (preserve existing guard).

Provider: `receivingImportResolverProvider` in
[receiving_provider.dart](../../../lib/presentation/providers/receiving_provider.dart),
wired from `createProductUseCaseProvider`.

### `BatchImportReceivingUseCase` (refactor)

Replace inline steps 2–3 with a call to the injected `ReceivingImportResolver`. The use
case keeps:
1. `assertPermission(bulkReceive)` + `assertPermission(receiveStock)`
2. empty-classification guard
3. `resolver.resolve(...)` (which itself asserts `addProduct` when needed)
4. build draft `ReceivingEntity` from `resolved.items` (reference number, totals)
5. `createReceiving` → `CompleteReceivingUseCase.execute`

Constructor gains `ReceivingImportResolver` (replacing the direct `CreateProductUseCase`
dependency; the resolver holds it instead). Net reduction ~70 → ~25 lines in `execute`.

### `CsvImportDialog` (refactor)

Path unchanged. Becomes a `ConsumerStatefulWidget` so it can read providers.

- **Delete** `_parseCsv` (naive splitter) and the 5-column format / `costCode: ''` path.
- File pick: `FilePicker.platform.pickFiles(type: custom, allowedExtensions: ['csv'],
  withData: true)` → `utf8.decode(bytes)` (web-safe; matches batch screen).
- Parse: `parseBatchImportCsv(content)` → `ParseResult`.
- Classify: snapshot `productsProvider`, filter `isActive`, `classifyRows(...)`.
- Preview: summary chips (Match / Cost variation / New / Errors) + per-row `ParseError`
  list (see shared preview widget below).
- On confirm:
  - read `costCodeMappingProvider` and `currentUserProvider`,
  - read the **current receiving form's supplier** from `currentReceivingProvider`,
  - `resolver.resolve(actor, classified, mapping, supplierId, supplierName)`,
  - `onImport(resolved.items)` — callback signature unchanged.
- `bulk_receiving_screen._showCsvImport` and its `onImport` loop are **untouched**.

### Shared preview widget (included in this plan, separable task)

Path: `lib/presentation/mobile/widgets/receiving/import_preview.dart`

Extract the classified-row summary + error-list rendering currently in
`batch_import_screen` into a reusable widget consumed by both the dialog and the batch
screen. Inputs: `ParseResult` + `List<ClassifiedRow>`. This removes preview duplication.
If it proves to entangle batch-screen-specific state during implementation, it may be
deferred to a follow-up without blocking the core unification.

## Data Flow

Both flows share the front half:

```
pick file → utf8.decode → parseBatchImportCsv → classifyRows
          → ReceivingImportResolver.resolve  (creates new products, builds items)
```

Then they diverge on the back half:

- **Batch:** build draft ReceivingEntity → createReceiving → CompleteReceivingUseCase
  (stock + price history + audit, completed immediately).
- **Dialog:** `onImport(items)` → `currentReceivingProvider.addItem(...)` for each →
  user completes the in-progress receiving manually later.

## Error Handling

- **Parse errors** — accumulated `ParseError` list with 1-based row numbers, shown in the
  preview; partial success allowed (unchanged from batch).
- **Product-create failure** — `resolve` throws `ReceivingImportException` with the row
  context message. Batch use case maps via `UseCaseResult.fromException`; the dialog shows
  it in an error state. Already-created products in the run remain in inventory (documented,
  matches today's batch behavior).
- **Permission** — `addProduct` asserted inside `resolve` (only when new products present);
  `bulkReceive`/`receiveStock` remain the caller's concern (batch asserts up front; the
  form asserts `receiveStock` at its own completion).

### Known tradeoff (accepted for v1)

In the dialog, products are created **eagerly** on confirm, but the receiving is completed
later by the user. Abandoning the form leaves orphan zero-stock products. This is the same
failure shape the batch flow already documents, but with a wider time window. Accepted for
v1; a future improvement could defer creation to completion (requires changing
`_processReceivingItem` to create products for `productId == null` items).

## Testing

- **`ReceivingImportResolver`** (unit, mock `CreateProductUseCase`): match row, cost-mismatch
  row, new row (explicit SKU), `GENERATE` row, mixed; `addProduct` gating (present/absent);
  product-create failure → `ReceivingImportException`; correct `costCode` encoding on items;
  supplier propagation to created products.
- **`BatchImportReceivingUseCase`** (existing tests): shrink to orchestration — resolver
  faked/mocked; assert draft built from resolved items and completion called. Update the
  existing test file to the new constructor.
- **`CsvImportDialog`** (widget test): valid CSV → preview shows correct counts; quoted-comma
  row parses correctly (regression vs old splitter); confirm → `onImport` called with
  resolved items; parse error → error surfaced, `onImport` not called.

## Files Touched

- `lib/domain/usecases/receiving/receiving_import_resolver.dart` — **new**
- `lib/domain/usecases/receiving/batch_import_receiving_usecase.dart` — refactor to use resolver
- `lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart` — rewrite to thin client
- `lib/presentation/mobile/widgets/receiving/import_preview.dart` — **new** (shared preview)
- `lib/presentation/mobile/screens/receiving/batch_import_screen.dart` — use shared preview
- `lib/presentation/providers/receiving_provider.dart` — add `receivingImportResolverProvider`,
  update `batchImportReceivingUseCaseProvider` wiring
- `test/...` — resolver unit tests, batch use case test update, dialog widget test
