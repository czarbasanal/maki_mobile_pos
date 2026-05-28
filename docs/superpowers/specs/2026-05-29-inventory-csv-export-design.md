# Inventory CSV Export (+ remove dead Import) — Design

**Date:** 2026-05-29
**Status:** Approved (pending spec review)

## Problem

The inventory three-dots menu has two dead items — **Import CSV** and **Export** — that
only show "coming soon" snackbars ([inventory_screen.dart `_handleMenuAction`](../../../lib/presentation/mobile/screens/inventory/inventory_screen.dart)).

This work:
1. **Removes** the inventory "Import CSV" item. Batch import already exists, fully
   working, under **Receiving → Import** (`/receiving/import`); the catalog screen
   shouldn't duplicate it.
2. **Implements** the **Export** item — write the full product catalog to a CSV file the
   user saves via the system file picker.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Inventory Import | **Remove** the menu item; batch import stays in Receiving only. |
| Export delivery | **Save via `file_picker`'s `saveFile`** — no new dependency (`share_plus` not added). |
| Export scope | **Entire catalog** (all products, ignores on-screen search/filter/sort). |
| Columns | Match the Receiving import schema (`kBatchImportColumns`) so exports round-trip back into Receiving → Import. |
| Permission | **Admin only** — the CSV includes `cost`, which is admin-sensitive (consistent with `importCsv` being admin-only). |

## Architecture

A pure CSV-builder utility + a thin screen action.

- `buildInventoryCsv(List<ProductEntity>)` is pure (products → CSV string) and reuses the
  existing `kBatchImportColumns` header, so the round-trip with `parseBatchImportCsv`
  (Receiving import) is guaranteed by construction and verifiable in a unit test.
- The inventory screen fetches the catalog, builds the CSV, and hands the bytes to
  `file_picker` to save. No domain "export use case" — this is a read plus a file write,
  and the admin gate lives in the UI alongside the menu.

## Components

### `lib/core/utils/inventory_export.dart` (new)

```dart
String buildInventoryCsv(List<ProductEntity> products)
```

- Uses `package:csv` `ListToCsvConverter`.
- Header row = `kBatchImportColumns` from `lib/core/utils/batch_import.dart`
  (`sku, name, category, unit, cost, price, quantity, reorder_level`).
- One row per product, in that column order:
  - `sku`, `name`, `category` (empty string if null/empty), `unit`,
    `cost` (`toStringAsFixed(2)`), `price` (`toStringAsFixed(2)`),
    `quantity` (int), `reorder_level` (int).
- Pure; no I/O. Returns the full CSV text (with a trailing newline acceptable).

### Inventory screen (`lib/presentation/mobile/screens/inventory/inventory_screen.dart`)

- **Remove** the `'import'` `PopupMenuItem` and its `case 'import'` branch in
  `_handleMenuAction`.
- The Export `PopupMenuItem` is shown **only when the current user is admin** (gate with
  the role already read for `canAddProduct`).
- `case 'export'` calls a new `Future<void> _handleExport()`:
  1. Fetch the full catalog: `await ref.read(productRepositoryProvider).getAllProducts()`.
  2. If empty → info snackbar "No products to export"; return.
  3. `final csv = buildInventoryCsv(products);`
  4. `final bytes = Uint8List.fromList(utf8.encode(csv));`
  5. `final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save inventory CSV',
        fileName: 'inventory_${yyyyMMdd}.csv',
        type: FileType.custom, allowedExtensions: ['csv'], bytes: bytes);`
  6. Platform-correct write:
     - If `path == null` → user cancelled → "Export cancelled" snackbar; return.
     - **Mobile** (`Platform.isAndroid || Platform.isIOS`): `saveFile` with `bytes`
       already wrote the file (the returned path may be a content URI — do **not**
       re-write it with `dart:io`).
     - **Desktop** (otherwise): `saveFile` only returns the chosen path without writing,
       so write it ourselves: `await File(path).writeAsBytes(bytes)`.
  7. Success → `context.showSuccessSnackBar('Inventory exported')`.
- Errors are caught and surfaced via `context.showErrorSnackBar('Export failed: $e')`.

Filename date uses the existing `intl` `DateFormat('yyyy-MM-dd')`.

## Error handling

- Empty catalog → friendly "No products to export", no file dialog.
- User cancels the picker (`path == null`) → "Export cancelled".
- Any exception (permission, I/O) → caught, "Export failed: <message>".

## Testing

- **`buildInventoryCsv`** (unit): given a couple of products (one with a null/empty
  category), assert the header is `kBatchImportColumns` and each row's cells match the
  expected formatting (cost/price 2-dp, ints for quantity/reorder).
- **Round-trip** (unit): `parseBatchImportCsv(buildInventoryCsv(products))` returns rows
  whose `sku/name/cost/price/quantity/reorderLevel` equal the source products' values —
  proving exports re-import cleanly into Receiving.
- File-save / picker flow and the admin-only menu visibility are verified manually.

## Out of scope

- Inventory CSV **import** (removed; use Receiving → Import).
- Adding `share_plus` or a share-sheet path.
- Exporting the current filtered view (always the full catalog).
- Exporting fields beyond the Receiving import schema (e.g., barcodes, images, supplier)
  — kept to the round-trippable column set.
- A dedicated `exportInventory` permission (gated on admin role instead).
