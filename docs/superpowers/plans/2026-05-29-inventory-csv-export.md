# Inventory CSV Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export the full product catalog to a CSV file (saved via the system file picker) from the inventory three-dots menu, and remove the dead "Import CSV" menu item.

**Architecture:** A pure `buildInventoryCsv(products)` utility reuses the receiving import's column schema (`kBatchImportColumns`) so exports round-trip back into Receiving → Import. The inventory screen's `export` action fetches the catalog, builds the CSV, and writes it via `file_picker`'s `saveFile`. Admin-only (CSV includes cost). No new dependency.

**Tech Stack:** Flutter, `csv`, `file_picker`, flutter_test.

**Spec:** `docs/superpowers/specs/2026-05-29-inventory-csv-export-design.md`

**Run tests with:** `flutter` is at `/Users/czar/flutter/bin`; prefix with `export PATH="$PATH:/Users/czar/flutter/bin" &&` if not on PATH.

### Key facts (verified)
- `ProductEntity`: `sku` (String), `name` (String), `category` (String?), `unit` (String), `cost` (double), `price` (double), `quantity` (int), `reorderLevel` (int).
- `kBatchImportColumns` (in `lib/core/utils/batch_import.dart`) = `['sku','name','category','unit','cost','price','quantity','reorder_level']`.
- `parseBatchImportCsv` uses `CsvToListConverter(eol: '\n')` — so the builder must emit with `eol: '\n'` for a clean round-trip.
- `ProductRepository.getAllProducts({bool includeInactive = false, int limit = 100})`.
- `inventory_screen.dart` is a `ConsumerState` (so `ref` is available in handlers); it already computes `final isAdmin = currentUser?.role == UserRole.admin;` in `build`, and imports `providers.dart` (exposes `productRepositoryProvider`), `go_router`, `enums` (`UserRole`), `navigation_extensions` (`showSuccessSnackBar`/`showErrorSnackBar`/`showSnackBar`).

---

## Task 1: Pure `buildInventoryCsv` utility + round-trip test

**Files:**
- Create: `lib/core/utils/inventory_export.dart`
- Test: `test/core/utils/inventory_export_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/inventory_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/core/utils/inventory_export.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

ProductEntity _product({
  required String sku,
  required String name,
  String? category,
  String unit = 'pcs',
  double cost = 10,
  double price = 15,
  int quantity = 5,
  int reorderLevel = 2,
}) =>
    ProductEntity(
      id: 'id-$sku',
      sku: sku,
      name: name,
      costCode: '',
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
      unit: unit,
      category: category,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('buildInventoryCsv', () {
    test('first row is the batch-import header', () {
      final csv = buildInventoryCsv([_product(sku: 'A', name: 'Apple')]);
      final firstLine = csv.split('\n').first.trim();
      expect(firstLine, kBatchImportColumns.join(','));
    });

    test('writes one row per product with formatted cells', () {
      final csv = buildInventoryCsv([
        _product(
          sku: 'A',
          name: 'Apple',
          category: 'Fruit',
          unit: 'kg',
          cost: 12.5,
          price: 20,
          quantity: 7,
          reorderLevel: 3,
        ),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1].trim(), 'A,Apple,Fruit,kg,12.50,20.00,7,3');
    });

    test('null category serializes as an empty cell', () {
      final csv = buildInventoryCsv([_product(sku: 'B', name: 'Bare')]);
      // sku,name,,unit,... -> two commas after name
      expect(csv, contains('B,Bare,,pcs,'));
    });

    test('round-trips cleanly back through parseBatchImportCsv', () {
      final products = [
        _product(sku: 'A', name: 'Apple', category: 'Fruit', cost: 12.5,
            price: 20, quantity: 7, reorderLevel: 3),
        _product(sku: 'B', name: 'Banana', cost: 5, price: 8,
            quantity: 2, reorderLevel: 1),
      ];

      final parsed = parseBatchImportCsv(buildInventoryCsv(products));

      expect(parsed.errors, isEmpty);
      expect(parsed.rows.length, 2);
      expect(parsed.rows[0].sku, 'A');
      expect(parsed.rows[0].name, 'Apple');
      expect(parsed.rows[0].cost, 12.5);
      expect(parsed.rows[0].price, 20);
      expect(parsed.rows[0].quantity, 7);
      expect(parsed.rows[0].reorderLevel, 3);
      expect(parsed.rows[1].sku, 'B');
      expect(parsed.rows[1].quantity, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/inventory_export_test.dart`
Expected: FAIL — `inventory_export.dart` / `buildInventoryCsv` does not exist.

- [ ] **Step 3: Create the utility**

Create `lib/core/utils/inventory_export.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/inventory_export_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/inventory_export.dart test/core/utils/inventory_export_test.dart
git commit -m "feat(inventory): buildInventoryCsv export utility"
```

---

## Task 2: Wire Export + remove Import in the inventory menu

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart`

UI + I/O; verified manually (the file picker can't be unit-tested).

- [ ] **Step 1: Add imports**

At the top of `lib/presentation/mobile/screens/inventory/inventory_screen.dart`, add (after the existing `package:` imports):

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/utils/inventory_export.dart';
```

(Dart convention: `dart:` imports first. Place the three `dart:` lines at the very top, above the `package:flutter/...` imports; place the three `package:`/project imports among the existing `package:` block.)

- [ ] **Step 2: Remove the Import CSV menu item; gate Export to admin**

Replace the import + export `PopupMenuItem`s (the block starting `const PopupMenuItem( value: 'import',` through the end of the `value: 'export'` item) with an admin-gated Export only:

```dart
              if (isAdmin)
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(CupertinoIcons.cloud_download),
                    title: Text('Export CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
```

(`isAdmin` is already in scope in `build` where the `itemBuilder` closure is defined.)

- [ ] **Step 3: Replace the menu handler branches**

In `_handleMenuAction`, remove the `import` and `export` cases and route export to a new async method:

```dart
  void _handleMenuAction(String action) {
    switch (action) {
      case 'add':
        context.push(RoutePaths.productAdd);
        break;
      case 'export':
        _handleExport();
        break;
    }
  }
```

- [ ] **Step 4: Implement `_handleExport`**

Add this method to `_InventoryScreenState`:

```dart
  Future<void> _handleExport() async {
    try {
      final products = await ref
          .read(productRepositoryProvider)
          .getAllProducts(includeInactive: true, limit: 100000);

      if (!mounted) return;
      if (products.isEmpty) {
        context.showSnackBar('No products to export');
        return;
      }

      final csv = buildInventoryCsv(products);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final fileName =
          'inventory_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save inventory CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (!mounted) return;
      if (path == null) {
        context.showSnackBar('Export cancelled');
        return;
      }

      // On mobile, saveFile(bytes:) already wrote the file (path may be a
      // content URI). On desktop, saveFile only returns the chosen path, so
      // write the bytes ourselves.
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes);
      }

      if (!mounted) return;
      context.showSuccessSnackBar('Inventory exported');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Export failed: $e');
    }
  }
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/inventory_screen.dart`
Expected: No errors. (If `showSnackBar` is not defined on the context extension, use the same snackbar helper the file already uses — confirm with `grep -n "showSnackBar\|showSuccessSnackBar" lib/core/extensions/navigation_extensions.dart`; `showSuccessSnackBar`/`showErrorSnackBar` are confirmed to exist. If plain `showSnackBar` is absent, replace the two info-snackbar calls with `showSuccessSnackBar`.)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/inventory_screen.dart
git commit -m "feat(inventory): CSV export menu action; remove dead import item"
```

---

## Task 3: Full verification

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: no new errors (pre-existing infos acceptable). Confirm no leftover reference to the removed `'import'` value or the old "coming soon" strings: `grep -rn "CSV import coming soon\|Export coming soon\|value: 'import'" lib` → no matches.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: new `inventory_export_test.dart` passes (4 tests). The 8 pre-existing failures (cart_item_tile, product_list_tile, update_product) remain and are unrelated; no *new* failures.

- [ ] **Step 3: Manual smoke test**

Run the app as **admin**: Inventory → three-dots → only **Export CSV** shows (no Import). Tap it → system save dialog with `inventory_<date>.csv` → save → "Inventory exported"; open the file and confirm the header + one row per product. Cancel the dialog → "Export cancelled". As a **non-admin** (cashier/staff): the three-dots menu shows no Export item.

---

## Self-Review notes

- **Spec coverage:** remove inventory import (T2 Step 2-3); pure `buildInventoryCsv` reusing `kBatchImportColumns` (T1); export action with `getAllProducts` + `file_picker saveFile` + platform-correct write (T2 Step 4); admin-only gate (T2 Step 2); round-trip + formatting tests (T1). All covered.
- **Round-trip safety:** builder emits `eol: '\n'` to match `parseBatchImportCsv`; verified by the round-trip test. Note: products with `quantity == 0` export fine but won't re-import via Receiving (its parser requires a positive quantity) — that's a Receiving-import rule, out of scope here; the round-trip test uses positive quantities.
- **Type consistency:** `buildInventoryCsv(List<ProductEntity>) -> String`, `kBatchImportColumns`, `getAllProducts(includeInactive:, limit:)`, `FilePicker.platform.saveFile(...)` used consistently. `isAdmin` reused from `build`.
- **Inactive products:** exported (`includeInactive: true`) for a full backup, per the spec.
