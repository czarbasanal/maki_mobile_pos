# Selling Options Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a product carry an optional list of selling options (label, piece count, set price) so the shop can sell a pulley ball "By 6" or "By 3" out of one piece-counted stock pool.

**Architecture:** A `SellingOption` value object lives in an array on the product doc. Stock stays a single piece count. Sale and job-order lines keep `quantity` in **pieces** — so every existing report, receipt and stock deduction is untouched — and gain a four-field option snapshot (`optionId`, `optionLabel`, `optionPieces`, `optionPrice`) for display and audit. `unitPrice` is derived as `optionPrice / optionPieces`. The POS opens a picker whenever a product has options, and the cart merges by product **and** option. Price history gains the same option fields plus a series split so the sparkline and deltas stay coherent.

**Tech Stack:** Flutter + Riverpod + Firestore (root, `lib/`); React + Vite + TypeScript + Zustand + Vitest (`web_admin/`); `@firebase/rules-unit-testing` (`tools/firestore-rules-test/`).

**Spec:** `docs/superpowers/specs/2026-07-29-selling-options-design.md`

## Global Constraints

- Every logic change is mirrored in Dart and TypeScript. Domain rules live in pure, framework-free modules with unit tests on both sides — the two must agree on names and behaviour.
- `SaleItem.quantity` **always means pieces**. Never change its meaning. No task in this plan may alter how an existing report reads `quantity`.
- Field names, exactly: `sellingOptions`, `optionId`, `optionLabel`, `optionPieces`, `optionPrice`.
- Validation limits, exactly: max **10** options per product; label trimmed, non-empty, max **24** characters, unique within the product case-insensitively; `pieces >= 1`; `price > 0`.
- Price-history reason literals, exactly, identical in Dart and TS: `'Price update'`, `'Option added'`, `'Option removed'`, `'Option changed'`.
- Selling options are **admin-only to edit**, enforced in `firestore.rules` *and* by omitting the key from non-admin update maps.
- Flutter checks: `flutter test`, `flutter analyze`. Web checks, run from inside `web_admin/`: `npm run typecheck`, `npm run test`, `npm run build`.
- Vitest does not resolve the `@/` alias in pure-domain test files. Pure domain modules under `web_admin/src/domain/` use **relative** imports.
- Branch is `feat/selling-options`, already created. Commit after every task. Do not push and do not deploy `firestore.rules` without asking.

## File Structure

**Flutter (`lib/`)**

| Path | Responsibility |
|---|---|
| `lib/domain/entities/selling_option_entity.dart` | *(new)* the value object |
| `lib/core/utils/selling_options.dart` | *(new)* pure validation, serialization, history-event diffing |
| `lib/domain/entities/entities.dart` | export the new entity |
| `lib/domain/entities/product_entity.dart` | `sellingOptions` field |
| `lib/data/models/product_model.dart` | serialize `sellingOptions`; omit for non-admin updates |
| `lib/domain/entities/sale_item_entity.dart` | option snapshot fields + derived getters |
| `lib/data/models/sale_item_model.dart` | serialize option fields; `fromProductOption` factory |
| `lib/presentation/providers/cart_provider.dart` | merge by product+option, step by set |
| `lib/presentation/mobile/widgets/pos/selling_option_sheet.dart` | *(new)* the picker |
| `lib/presentation/mobile/widgets/pos/cart_item_tile.dart` | render option label and sets |
| `lib/presentation/mobile/widgets/pos/receipt_widget.dart` | render option label on receipt |
| `lib/presentation/mobile/widgets/inventory/selling_options_editor.dart` | *(new)* admin editor |
| `lib/presentation/mobile/screens/inventory/product_form_screen.dart` | host the editor |
| `lib/domain/repositories/product_repository.dart` | `PriceHistoryEntry` option fields |
| `lib/data/repositories/product_repository_impl.dart` | write option history entries |
| `lib/core/utils/price_history_view.dart` | series split |
| `lib/presentation/mobile/screens/inventory/price_history_screen.dart` | series selector |

**Web (`web_admin/src/`)**

| Path | Responsibility |
|---|---|
| `domain/entities/SellingOption.ts` | *(new)* the interface + per-piece helper |
| `domain/products/sellingOptions.ts` | *(new)* validation, parse/serialize, history diffing |
| `domain/entities/Product.ts` | `sellingOptions` field |
| `domain/entities/SaleItem.ts` | option fields + derived helpers |
| `domain/sales/cart.ts` | `cartLineId`, per-product stock aggregation |
| `data/converters/productConverter.ts` | serialize `sellingOptions` |
| `data/converters/saleItemConverter.ts` | serialize option fields |
| `data/converters/jobOrderConverter.ts` | inline JO item maps carry option fields |
| `data/products/productWrites.ts` | omit `sellingOptions` for non-admins; write option history |
| `presentation/stores/cartStore.ts` | key lines by line id, not product id |
| `presentation/features/pos/SellingOptionDialog.tsx` | *(new)* the picker |
| `presentation/features/pos/CartBuilder.tsx` | open picker, pass line ids |
| `presentation/features/inventory/SellingOptionsEditor.tsx` | *(new)* admin editor |
| `presentation/features/inventory/InventoryFormPage.tsx` | host the editor |
| `domain/products/priceHistory.ts` | series split + new reason labels |
| `presentation/features/inventory/PriceHistoryView.tsx` | series selector |
| `presentation/features/reports/PriceChangeReportPage.tsx` | Option column |

**Rules**

| Path | Responsibility |
|---|---|
| `firestore.rules` | `sellingOptions` on the staff and cashier denylists |
| `tools/firestore-rules-test/test/rules.test.js` | permission coverage |

---

## Phase 1 — Domain foundation

### Task 1: `SellingOptionEntity` (Dart)

**Files:**
- Create: `lib/domain/entities/selling_option_entity.dart`
- Modify: `lib/domain/entities/entities.dart`
- Test: `test/domain/entities/selling_option_entity_test.dart`

**Interfaces:**
- Produces: `class SellingOptionEntity extends Equatable` with `String id`, `String label`, `int pieces`, `double price`, getter `double get pricePerPiece`, and `copyWith({String? id, String? label, int? pieces, double? price})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/selling_option_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('SellingOptionEntity', () {
    test('pricePerPiece divides the set price by the piece count', () {
      const option =
          SellingOptionEntity(id: 'a', label: 'By 3', pieces: 3, price: 330);
      expect(option.pricePerPiece, 110);
    });

    test('pricePerPiece keeps full precision for a non-terminating divide', () {
      const option =
          SellingOptionEntity(id: 'a', label: 'By 3', pieces: 3, price: 100);
      expect(option.pricePerPiece * 3, closeTo(100, 0.0001));
    });

    test('is value-equal on the same fields', () {
      const a = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      const b = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      expect(a, b);
    });

    test('copyWith replaces only the named field', () {
      const a = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      expect(a.copyWith(price: 650).price, 650);
      expect(a.copyWith(price: 650).label, 'By 6');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/selling_option_entity_test.dart`
Expected: FAIL — `SellingOptionEntity` isn't defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/entities/selling_option_entity.dart
import 'package:equatable/equatable.dart';

/// One way a product may be sold — a label, how many pieces of stock it
/// consumes, and the price of the whole set.
///
/// Options are optional and per-product. A product with no options sells at
/// its own [ProductEntity.price] per piece, exactly as before this existed.
/// A product WITH options can only be sold through one of them.
///
/// Distinct from the cost-variation mechanism (`ABC-1`, `ABC-2`), which
/// creates separate product docs. Options never split stock.
class SellingOptionEntity extends Equatable {
  /// Stable id, generated once at creation and never reused. Sale lines
  /// snapshot it so a later edit or deletion can't rewrite history.
  final String id;

  /// What the cashier sees, e.g. "By 6".
  final String label;

  /// How many pieces of stock this option consumes.
  final int pieces;

  /// Price of the WHOLE set, not per piece.
  final double price;

  const SellingOptionEntity({
    required this.id,
    required this.label,
    required this.pieces,
    required this.price,
  });

  /// Derived per-piece price. Shown as a caption in the picker so a
  /// mis-typed set price is obvious at the point of sale.
  double get pricePerPiece => pieces == 0 ? 0 : price / pieces;

  SellingOptionEntity copyWith({
    String? id,
    String? label,
    int? pieces,
    double? price,
  }) {
    return SellingOptionEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      pieces: pieces ?? this.pieces,
      price: price ?? this.price,
    );
  }

  @override
  List<Object?> get props => [id, label, pieces, price];

  @override
  String toString() =>
      'SellingOptionEntity(id: $id, label: $label, pieces: $pieces, price: $price)';
}
```

Add to `lib/domain/entities/entities.dart`, in the existing alphabetical export block:

```dart
export 'selling_option_entity.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/selling_option_entity_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/selling_option_entity.dart lib/domain/entities/entities.dart test/domain/entities/selling_option_entity_test.dart
git commit -m "feat(domain): add SellingOptionEntity"
```

---

### Task 2: Selling-option validation and serialization (Dart)

**Files:**
- Create: `lib/core/utils/selling_options.dart`
- Test: `test/core/utils/selling_options_test.dart`

**Interfaces:**
- Consumes: `SellingOptionEntity` (Task 1).
- Produces:
  - `const int kMaxSellingOptions = 10;`
  - `const int kMaxSellingOptionLabel = 24;`
  - `String? validateSellingOptions(List<SellingOptionEntity> options)` — `null` when valid, otherwise a user-facing message.
  - `List<SellingOptionEntity> sellingOptionsFromList(dynamic raw)` — tolerant parse of the Firestore array.
  - `List<Map<String, dynamic>> sellingOptionsToList(List<SellingOptionEntity> options)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/selling_options_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SellingOptionEntity opt(String id, String label, int pieces, double price) =>
    SellingOptionEntity(id: id, label: label, pieces: pieces, price: price);

void main() {
  group('validateSellingOptions', () {
    test('accepts an empty list', () {
      expect(validateSellingOptions(const []), isNull);
    });

    test('accepts a well-formed list', () {
      expect(
        validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)]),
        isNull,
      );
    });

    test('rejects a blank label', () {
      expect(validateSellingOptions([opt('a', '   ', 6, 600)]), isNotNull);
    });

    test('rejects a label over 24 characters', () {
      expect(validateSellingOptions([opt('a', 'x' * 25, 6, 600)]), isNotNull);
    });

    test('rejects duplicate labels case-insensitively', () {
      final error =
          validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'by 6', 3, 330)]);
      expect(error, isNotNull);
    });

    test('rejects pieces below 1', () {
      expect(validateSellingOptions([opt('a', 'By 6', 0, 600)]), isNotNull);
    });

    test('rejects a price of zero or less', () {
      expect(validateSellingOptions([opt('a', 'By 6', 6, 0)]), isNotNull);
    });

    test('rejects more than 10 options', () {
      final many = List.generate(11, (i) => opt('$i', 'By $i', i + 1, 100));
      expect(validateSellingOptions(many), isNotNull);
    });

    test('accepts exactly 10 options', () {
      final ten = List.generate(10, (i) => opt('$i', 'By $i', i + 1, 100));
      expect(validateSellingOptions(ten), isNull);
    });
  });

  group('sellingOptionsFromList', () {
    test('returns empty for null', () {
      expect(sellingOptionsFromList(null), isEmpty);
    });

    test('returns empty for a non-list', () {
      expect(sellingOptionsFromList('nope'), isEmpty);
    });

    test('parses well-formed maps', () {
      final parsed = sellingOptionsFromList([
        {'id': 'a', 'label': 'By 6', 'pieces': 6, 'price': 600},
      ]);
      expect(parsed, [opt('a', 'By 6', 6, 600)]);
    });

    test('skips entries missing an id or label', () {
      final parsed = sellingOptionsFromList([
        {'id': '', 'label': 'By 6', 'pieces': 6, 'price': 600},
        {'id': 'b', 'label': '', 'pieces': 3, 'price': 330},
        {'id': 'c', 'label': 'By 3', 'pieces': 3, 'price': 330},
      ]);
      expect(parsed, [opt('c', 'By 3', 3, 330)]);
    });

    test('round-trips through sellingOptionsToList', () {
      final options = [opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)];
      expect(sellingOptionsFromList(sellingOptionsToList(options)), options);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/selling_options_test.dart`
Expected: FAIL — `selling_options.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/selling_options.dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Most selling options one product may carry. Keeps the product doc small
/// and the picker sheet scrollable-free on a phone.
const int kMaxSellingOptions = 10;

/// Longest option label. Long enough for "By 6 (half box)".
const int kMaxSellingOptionLabel = 24;

/// Validates a product's selling options. Returns `null` when the list is
/// valid, otherwise a message suitable for showing in the product form.
///
/// An empty list is valid — it means "no options", which is how every
/// product behaved before this feature.
String? validateSellingOptions(List<SellingOptionEntity> options) {
  if (options.isEmpty) return null;
  if (options.length > kMaxSellingOptions) {
    return 'At most $kMaxSellingOptions selling options per product.';
  }

  final seen = <String>{};
  for (final option in options) {
    final label = option.label.trim();
    if (label.isEmpty) return 'Every selling option needs a label.';
    if (label.length > kMaxSellingOptionLabel) {
      return 'Option labels are limited to $kMaxSellingOptionLabel characters.';
    }
    if (!seen.add(label.toLowerCase())) {
      return 'Option labels must be unique — "$label" is used twice.';
    }
    if (option.pieces < 1) {
      return '"$label" must cover at least 1 piece.';
    }
    if (option.price <= 0) {
      return '"$label" needs a price above zero.';
    }
  }
  return null;
}

/// Parses the Firestore `sellingOptions` array. Tolerant by design: a missing
/// field, a wrong type, or a malformed entry yields no option rather than an
/// exception, so one bad doc can never break the POS product list.
List<SellingOptionEntity> sellingOptionsFromList(dynamic raw) {
  if (raw is! List) return const [];
  final result = <SellingOptionEntity>[];
  for (final item in raw) {
    if (item is! Map) continue;
    // Type-CHECK, don't cast. `as String?` throws on a wrong-typed value,
    // which would break the tolerance this function promises — and diverge
    // from the TypeScript mirror, which already checks.
    final id = item['id'] is String ? item['id'] as String : '';
    final label = item['label'] is String ? item['label'] as String : '';
    if (id.isEmpty || label.isEmpty) continue;
    result.add(SellingOptionEntity(
      id: id,
      label: label,
      pieces: item['pieces'] is num ? (item['pieces'] as num).toInt() : 1,
      price: item['price'] is num ? (item['price'] as num).toDouble() : 0.0,
    ));
  }
  return result;
}

/// Serializes selling options for the Firestore product doc.
List<Map<String, dynamic>> sellingOptionsToList(
  List<SellingOptionEntity> options,
) {
  return options
      .map((o) => <String, dynamic>{
            'id': o.id,
            'label': o.label,
            'pieces': o.pieces,
            'price': o.price,
          })
      .toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/selling_options_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/selling_options.dart test/core/utils/selling_options_test.dart
git commit -m "feat(domain): validate and serialize selling options"
```

---

### Task 3: `SellingOption` mirror (TypeScript)

**Files:**
- Create: `web_admin/src/domain/entities/SellingOption.ts`
- Create: `web_admin/src/domain/products/sellingOptions.ts`
- Create: `web_admin/src/domain/products/sellingOptions.test.ts`
- Modify: `web_admin/src/domain/entities/index.ts` (add the export alongside the existing entity exports)

**Interfaces:**
- Produces:
  - `interface SellingOption { id: string; label: string; pieces: number; price: number }`
  - `sellingOptionPricePerPiece(o: SellingOption): number`
  - `MAX_SELLING_OPTIONS = 10`, `MAX_SELLING_OPTION_LABEL = 24`
  - `validateSellingOptions(options: SellingOption[]): string | null`
  - `parseSellingOptions(raw: unknown): SellingOption[]`
  - `serializeSellingOptions(options: SellingOption[]): object[]`

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/products/sellingOptions.test.ts
import { describe, expect, it } from 'vitest';
import type { SellingOption } from '../entities/SellingOption';
import { sellingOptionPricePerPiece } from '../entities/SellingOption';
import {
  parseSellingOptions,
  serializeSellingOptions,
  validateSellingOptions,
} from './sellingOptions';

const opt = (id: string, label: string, pieces: number, price: number): SellingOption => ({
  id,
  label,
  pieces,
  price,
});

describe('sellingOptionPricePerPiece', () => {
  it('divides the set price by the piece count', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 3, 330))).toBe(110);
  });

  it('keeps full precision for a non-terminating divide', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 3, 100)) * 3).toBeCloseTo(100, 4);
  });

  it('returns 0 rather than Infinity when pieces is 0', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 0, 100))).toBe(0);
  });
});

describe('validateSellingOptions', () => {
  it('accepts an empty list', () => {
    expect(validateSellingOptions([])).toBeNull();
  });

  it('accepts a well-formed list', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)])).toBeNull();
  });

  it('rejects a blank label', () => {
    expect(validateSellingOptions([opt('a', '   ', 6, 600)])).not.toBeNull();
  });

  it('rejects a label over 24 characters', () => {
    expect(validateSellingOptions([opt('a', 'x'.repeat(25), 6, 600)])).not.toBeNull();
  });

  it('rejects duplicate labels case-insensitively', () => {
    expect(
      validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'by 6', 3, 330)]),
    ).not.toBeNull();
  });

  it('rejects pieces below 1', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 0, 600)])).not.toBeNull();
  });

  it('rejects a price of zero or less', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 6, 0)])).not.toBeNull();
  });

  it('rejects more than 10 options', () => {
    const many = Array.from({ length: 11 }, (_, i) => opt(`${i}`, `By ${i}`, i + 1, 100));
    expect(validateSellingOptions(many)).not.toBeNull();
  });

  it('accepts exactly 10 options', () => {
    const ten = Array.from({ length: 10 }, (_, i) => opt(`${i}`, `By ${i}`, i + 1, 100));
    expect(validateSellingOptions(ten)).toBeNull();
  });
});

describe('parseSellingOptions', () => {
  it('returns empty for undefined', () => {
    expect(parseSellingOptions(undefined)).toEqual([]);
  });

  it('returns empty for a non-array', () => {
    expect(parseSellingOptions('nope')).toEqual([]);
  });

  it('skips entries missing an id or label', () => {
    expect(
      parseSellingOptions([
        { id: '', label: 'By 6', pieces: 6, price: 600 },
        { id: 'b', label: '', pieces: 3, price: 330 },
        { id: 'c', label: 'By 3', pieces: 3, price: 330 },
      ]),
    ).toEqual([opt('c', 'By 3', 3, 330)]);
  });

  it('round-trips through serializeSellingOptions', () => {
    const options = [opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)];
    expect(parseSellingOptions(serializeSellingOptions(options))).toEqual(options);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- sellingOptions`
Expected: FAIL — modules not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// web_admin/src/domain/entities/SellingOption.ts
// Mirror of lib/domain/entities/selling_option_entity.dart.

/** One way a product may be sold. `price` is for the WHOLE set. */
export interface SellingOption {
  id: string;
  label: string;
  pieces: number;
  price: number;
}

/** Derived per-piece price, shown as a caption in the POS picker. */
export function sellingOptionPricePerPiece(option: SellingOption): number {
  return option.pieces === 0 ? 0 : option.price / option.pieces;
}
```

```ts
// web_admin/src/domain/products/sellingOptions.ts
// Port of lib/core/utils/selling_options.dart. Pure -> relative imports.
import type { SellingOption } from '../entities/SellingOption';

export const MAX_SELLING_OPTIONS = 10;
export const MAX_SELLING_OPTION_LABEL = 24;

/** Returns null when valid, otherwise a message for the product form. */
export function validateSellingOptions(options: SellingOption[]): string | null {
  if (options.length === 0) return null;
  if (options.length > MAX_SELLING_OPTIONS) {
    return `At most ${MAX_SELLING_OPTIONS} selling options per product.`;
  }

  const seen = new Set<string>();
  for (const option of options) {
    const label = option.label.trim();
    if (label === '') return 'Every selling option needs a label.';
    if (label.length > MAX_SELLING_OPTION_LABEL) {
      return `Option labels are limited to ${MAX_SELLING_OPTION_LABEL} characters.`;
    }
    const key = label.toLowerCase();
    if (seen.has(key)) return `Option labels must be unique — "${label}" is used twice.`;
    seen.add(key);
    if (option.pieces < 1) return `"${label}" must cover at least 1 piece.`;
    if (option.price <= 0) return `"${label}" needs a price above zero.`;
  }
  return null;
}

/**
 * Tolerant parse of the Firestore `sellingOptions` array. A missing field,
 * wrong type or malformed entry yields no option rather than throwing, so one
 * bad doc can never break the product list.
 */
export function parseSellingOptions(raw: unknown): SellingOption[] {
  if (!Array.isArray(raw)) return [];
  const result: SellingOption[] = [];
  for (const item of raw) {
    if (typeof item !== 'object' || item === null) continue;
    const rec = item as Record<string, unknown>;
    const id = typeof rec.id === 'string' ? rec.id : '';
    const label = typeof rec.label === 'string' ? rec.label : '';
    if (id === '' || label === '') continue;
    // Type-GUARD, don't coerce. `Number("abc")` is NaN and `Number(true)` is 1,
    // where Dart falls back to the literal default for any non-numeric value.
    // Math.trunc mirrors Dart's `.toInt()` on a fractional piece count.
    result.push({
      id,
      label,
      pieces:
        typeof rec.pieces === 'number' && Number.isFinite(rec.pieces)
          ? Math.trunc(rec.pieces)
          : 1,
      price: typeof rec.price === 'number' && Number.isFinite(rec.price) ? rec.price : 0,
    });
  }
  return result;
}

export function serializeSellingOptions(options: SellingOption[]): object[] {
  return options.map((o) => ({
    id: o.id,
    label: o.label,
    pieces: o.pieces,
    price: o.price,
  }));
}
```

Add to `web_admin/src/domain/entities/index.ts`, alongside the existing exports:

```ts
export * from './SellingOption';
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test -- sellingOptions && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/entities/SellingOption.ts web_admin/src/domain/entities/index.ts web_admin/src/domain/products/sellingOptions.ts web_admin/src/domain/products/sellingOptions.test.ts
git commit -m "feat(web): add SellingOption domain model and validation"
```

---

### Task 4: `sellingOptions` on the product (Dart)

**Files:**
- Modify: `lib/domain/entities/product_entity.dart`
- Modify: `lib/data/models/product_model.dart`
- Test: `test/data/models/product_model_selling_options_test.dart`

**Interfaces:**
- Consumes: `SellingOptionEntity` (Task 1), `sellingOptionsFromList` / `sellingOptionsToList` (Task 2).
- Produces: `ProductEntity.sellingOptions` (`List<SellingOptionEntity>`, defaults `const []`), `ProductEntity.hasSellingOptions` (`bool`), and `ProductModel.toUpdateMap(userId, {updatedByDisplayName, bool includeSellingOptions = false})`.

The `includeSellingOptions` flag is load-bearing, not cosmetic. `toUpdateMap` writes every product field. Once `sellingOptions` joins the rules denylist (Task 12), a staff or cashier edit that *added* the key to a doc lacking it would land in `diff().affectedKeys()` and be rejected — an edit they are entitled to make. Defaulting to `false` keeps the key out of non-admin writes entirely.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/models/product_model_selling_options_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductModel model({List<SellingOptionEntity> options = const []}) {
  return ProductModel(
    id: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    costCode: 'NBF',
    cost: 60,
    price: 120,
    quantity: 12,
    reorderLevel: 3,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2026, 7, 29),
    sellingOptions: options,
  );
}

void main() {
  group('ProductModel selling options', () {
    const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
    const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

    test('a doc with no sellingOptions field parses to an empty list', () {
      final parsed = ProductModel.fromMap({
        'sku': 'ABC-1',
        'name': 'Pulley Ball',
        'costCode': 'NBF',
        'cost': 60,
        'price': 120,
        'quantity': 12,
        'reorderLevel': 3,
        'unit': 'pcs',
        'isActive': true,
      }, 'p1');
      expect(parsed.sellingOptions, isEmpty);
      expect(parsed.toEntity().hasSellingOptions, isFalse);
    });

    test('round-trips options through toMap/fromMap', () {
      final map = model(options: [by6, by3]).toMap();
      final parsed = ProductModel.fromMap(map, 'p1');
      expect(parsed.sellingOptions, [by6, by3]);
      expect(parsed.toEntity().hasSellingOptions, isTrue);
    });

    test('toUpdateMap omits sellingOptions by default', () {
      final map = model(options: [by6]).toUpdateMap('u1');
      expect(map.containsKey('sellingOptions'), isFalse);
    });

    test('toUpdateMap includes sellingOptions when asked', () {
      final map = model(options: [by6])
          .toUpdateMap('u1', includeSellingOptions: true);
      expect(map['sellingOptions'], hasLength(1));
    });

    test('entity round-trips through fromEntity/toEntity', () {
      final entity = model(options: [by6, by3]).toEntity();
      expect(ProductModel.fromEntity(entity).sellingOptions, [by6, by3]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/product_model_selling_options_test.dart`
Expected: FAIL — no `sellingOptions` named parameter.

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/entities/product_entity.dart`, add the field, the constructor parameter (`this.sellingOptions = const []`), the `copyWith` parameter and passthrough, and the `props` entry — mirroring exactly how `barcodes` is already threaded through all four places. Then add the computed property next to `isVariation`:

```dart
  /// Optional ways this product may be sold, e.g. "By 6" and "By 3".
  ///
  /// Empty means the product sells at [price] per piece, which is how every
  /// product behaved before selling options existed. When NON-empty the POS
  /// requires the cashier to pick an option — [price] is then used only for
  /// inventory valuation and the reorder engine, never charged directly.
  final List<SellingOptionEntity> sellingOptions;
```

```dart
  /// Whether the POS must show the option picker for this product.
  bool get hasSellingOptions => sellingOptions.isNotEmpty;
```

In `lib/data/models/product_model.dart`:
- add `final List<SellingOptionEntity> sellingOptions;` with `this.sellingOptions = const []` in the constructor
- in `fromMap`: `sellingOptions: sellingOptionsFromList(map['sellingOptions']),`
- in `toMap`: `'sellingOptions': sellingOptionsToList(sellingOptions),`
- thread it through `copyWith`, `toEntity` and `fromEntity`
- import `package:maki_mobile_pos/core/utils/selling_options.dart`
- change the update map:

```dart
  /// Converts to a Map for updating a product. [updatedByDisplayName] is
  /// denormalized onto the doc to keep audit info readable for non-admins.
  ///
  /// [includeSellingOptions] must stay false for non-admin writers. Selling
  /// options are admin-only in firestore.rules; because this map writes every
  /// field, including the key on a doc that lacks it would put it in
  /// `diff().affectedKeys()` and get an otherwise-legitimate staff or cashier
  /// edit rejected. Same hazard the cashier rule comment documents.
  Map<String, dynamic> toUpdateMap(
    String updatedByUserId, {
    String? updatedByDisplayName,
    bool includeSellingOptions = false,
  }) {
    final map = copyWith(
      updatedBy: updatedByUserId,
      updatedByName: updatedByDisplayName,
      searchKeywords: _generateSearchKeywords(),
    ).toMap(forUpdate: true);
    if (!includeSellingOptions) map.remove('sellingOptions');
    return map;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/models/ && flutter analyze`
Expected: PASS, and no existing product-model test regresses.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/product_entity.dart lib/data/models/product_model.dart test/data/models/product_model_selling_options_test.dart
git commit -m "feat(domain): carry sellingOptions on ProductEntity and ProductModel"
```

---

### Task 5: `sellingOptions` on the product (TypeScript)

**Files:**
- Modify: `web_admin/src/domain/entities/Product.ts`
- Modify: `web_admin/src/data/converters/productConverter.ts`
- Test: `web_admin/src/data/converters/productConverter.test.ts` (create if absent)

**Interfaces:**
- Consumes: `parseSellingOptions` / `serializeSellingOptions` (Task 3).
- Produces: `Product.sellingOptions: SellingOption[]`, `productHasSellingOptions(p: Product): boolean`.

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/data/converters/productConverter.test.ts
import { describe, expect, it } from 'vitest';
import { productConverter } from './productConverter';
import type { QueryDocumentSnapshot, DocumentData } from 'firebase/firestore';

function snap(data: Record<string, unknown>): QueryDocumentSnapshot<DocumentData> {
  return {
    id: 'p1',
    data: () => ({
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      // A plain Date — `timestamps.ts` accepts Date / Timestamp / ISO string /
      // {seconds,nanoseconds} and nothing else, so a duck-typed
      // `{ toDate: () => ... }` stub falls through to null and requireDate
      // throws, failing the RED for the wrong reason. Matches every sibling
      // converter test.
      createdAt: new Date('2026-07-29'),
      ...data,
    }),
  } as unknown as QueryDocumentSnapshot<DocumentData>;
}

describe('productConverter selling options', () => {
  it('reads a missing sellingOptions field as an empty list', () => {
    expect(productConverter.fromFirestore(snap({})).sellingOptions).toEqual([]);
  });

  it('reads well-formed options', () => {
    const p = productConverter.fromFirestore(
      snap({ sellingOptions: [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }] }),
    );
    expect(p.sellingOptions).toEqual([{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }]);
  });

  it('writes options back out', () => {
    const p = productConverter.fromFirestore(
      snap({ sellingOptions: [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }] }),
    );
    const out = productConverter.toFirestore(p) as Record<string, unknown>;
    expect(out.sellingOptions).toEqual([{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- productConverter`
Expected: FAIL — `sellingOptions` is undefined on the parsed product.

- [ ] **Step 3: Write minimal implementation**

In `web_admin/src/domain/entities/Product.ts`, add the field to the interface after `barcodes` and add the helper:

```ts
  sellingOptions: SellingOption[];
```

```ts
/** Whether the POS must show the option picker for this product. */
export function productHasSellingOptions(p: Product): boolean {
  return p.sellingOptions.length > 0;
}
```

Import `SellingOption` from `./SellingOption`.

In `web_admin/src/data/converters/productConverter.ts`, import `parseSellingOptions` and `serializeSellingOptions` from `@/domain/products/sellingOptions`, then add to `toFirestore`:

```ts
      sellingOptions: serializeSellingOptions(product.sellingOptions),
```

and to `fromFirestore`:

```ts
      sellingOptions: parseSellingOptions(d.sellingOptions),
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck`
Expected: PASS. `npm run typecheck` will flag every place that builds a `Product` literal without `sellingOptions` — add `sellingOptions: []` at each, including test fixtures.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/entities/Product.ts web_admin/src/data/converters/productConverter.ts web_admin/src/data/converters/productConverter.test.ts
git commit -m "feat(web): carry sellingOptions on Product and its converter"
```

---

### Task 6: Option snapshot on sale lines (Dart)

**Files:**
- Modify: `lib/domain/entities/sale_item_entity.dart`
- Modify: `lib/data/models/sale_item_model.dart`
- Test: `test/domain/entities/sale_item_option_test.dart`

**Interfaces:**
- Consumes: `SellingOptionEntity` (Task 1).
- Produces on `SaleItemEntity`: `String? optionId`, `String? optionLabel`, `int? optionPieces`, `double? optionPrice`, `bool get hasOption`, `int? get optionSets`, `int get quantityStep`. On `SaleItemModel`: the same four fields, serialized, plus factory `SaleItemModel.fromProductOption({required String itemId, required ProductEntity product, required SellingOptionEntity option, int sets = 1})`.

`quantity` stays in **pieces**. `unitPrice` is `option.pricePerPiece`. Job-order docs reuse `SaleItemModel.fromMap`, so this task covers them on the Flutter side.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/sale_item_option_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity product() => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
    );

void main() {
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  group('SaleItemEntity option snapshot', () {
    test('quantity stays in pieces and unitPrice is per piece', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.quantity, 3);
      expect(item.unitPrice, 110);
      expect(item.grossAmount, 330);
    });

    test('two sets means six pieces', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
        sets: 2,
      ).toEntity();
      expect(item.quantity, 6);
      expect(item.optionSets, 2);
      expect(item.grossAmount, 660);
    });

    test('a non-terminating per-piece price still totals the set price', () {
      const odd = SellingOptionEntity(id: 'o3', label: 'By 3', pieces: 3, price: 100);
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: odd,
      ).toEntity();
      expect(item.grossAmount, closeTo(100, 0.0001));
    });

    test('unit cost is per piece so line cost is pieces x cost', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.unitCost, 60);
      expect(item.totalCost, 180);
    });

    test('a line with no option has null option fields and steps by 1', () {
      final item = SaleItemModel.fromProduct(
        itemId: 'i1',
        product: product(),
      ).toEntity();
      expect(item.hasOption, isFalse);
      expect(item.optionSets, isNull);
      expect(item.quantityStep, 1);
    });

    test('a line with an option steps by its piece count', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.hasOption, isTrue);
      expect(item.quantityStep, 3);
    });

    test('round-trips option fields through toMap/fromMap', () {
      final model = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      );
      final parsed = SaleItemModel.fromMap(model.toMap(), 'i1');
      expect(parsed.optionId, 'o2');
      expect(parsed.optionLabel, 'By 3');
      expect(parsed.optionPieces, 3);
      expect(parsed.optionPrice, 330);
    });

    test('a legacy map with no option fields parses to nulls', () {
      final parsed = SaleItemModel.fromMap({
        'productId': 'p1',
        'sku': 'ABC-1',
        'name': 'Pulley Ball',
        'unitPrice': 120.0,
        'unitCost': 60.0,
        'quantity': 2,
      }, 'i1');
      expect(parsed.optionId, isNull);
      expect(parsed.toEntity().hasOption, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/sale_item_option_test.dart`
Expected: FAIL — `fromProductOption` isn't defined.

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/entities/sale_item_entity.dart`, add the four fields (all optional, defaulting to `null`), thread them through the constructor, `copyWith` and `props`, and add:

```dart
  /// Snapshot of the selling option used for this line, if any. Kept on the
  /// line rather than looked up, so editing or deleting the option later
  /// never rewrites a past receipt.
  final String? optionId;
  final String? optionLabel;
  final int? optionPieces;

  /// Price of one whole set, as typed by the admin. [unitPrice] is this
  /// divided by [optionPieces]; this field is what the receipt shows.
  final double? optionPrice;
```

```dart
  /// Whether this line was rung up through a selling option.
  bool get hasOption => optionId != null && optionPieces != null && optionPieces! > 0;

  /// Number of whole sets on this line, or null when there's no option.
  /// [quantity] is always pieces, so sets is quantity / pieces.
  int? get optionSets => hasOption ? quantity ~/ optionPieces! : null;

  /// How much the +/- buttons move this line. A "By 3" line steps 3 -> 6.
  int get quantityStep => hasOption ? optionPieces! : 1;
```

In `lib/data/models/sale_item_model.dart`, add the same four fields, thread through the constructor / `copyWith` / `toEntity` / `fromEntity`, and:

`fromMap`:
```dart
      optionId: map['optionId'] as String?,
      optionLabel: map['optionLabel'] as String?,
      optionPieces: (map['optionPieces'] as num?)?.toInt(),
      optionPrice: (map['optionPrice'] as num?)?.toDouble(),
```

`toMap` — only write the keys when an option is present, so lines without one keep exactly the shape they have today:
```dart
    if (optionId != null) {
      map['optionId'] = optionId;
      map['optionLabel'] = optionLabel;
      map['optionPieces'] = optionPieces;
      map['optionPrice'] = optionPrice;
    }
```

New factory, beside `fromProduct`:
```dart
  /// Creates a cart line for a product sold through a selling option.
  ///
  /// [sets] is the number of whole sets; the resulting [quantity] is in
  /// PIECES ([sets] x option pieces) so every downstream report, receipt and
  /// stock deduction keeps working unchanged.
  factory SaleItemModel.fromProductOption({
    required String itemId,
    required ProductEntity product,
    required SellingOptionEntity option,
    int sets = 1,
  }) {
    return SaleItemModel(
      id: itemId,
      productId: product.id,
      sku: product.sku,
      name: product.name,
      unitPrice: option.pricePerPiece,
      unitCost: product.cost,
      quantity: option.pieces * sets,
      discountValue: 0,
      unit: product.unit,
      optionId: option.id,
      optionLabel: option.label,
      optionPieces: option.pieces,
      optionPrice: option.price,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`
Expected: PASS across the whole suite — no existing sale/JO test regresses.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/sale_item_entity.dart lib/data/models/sale_item_model.dart test/domain/entities/sale_item_option_test.dart
git commit -m "feat(domain): snapshot the selling option on sale lines"
```

---

### Task 7: Option snapshot on sale lines (TypeScript)

**Files:**
- Modify: `web_admin/src/domain/entities/SaleItem.ts`
- Modify: `web_admin/src/data/converters/saleItemConverter.ts`
- Modify: `web_admin/src/data/converters/jobOrderConverter.ts`
- Test: `web_admin/src/data/converters/saleItemConverter.test.ts` (create if absent)

**Interfaces:**
- Produces on `SaleItem`: `optionId: string | null`, `optionLabel: string | null`, `optionPieces: number | null`, `optionPrice: number | null`; plus `saleItemHasOption(i)`, `saleItemOptionSets(i): number | null`, `saleItemQuantityStep(i): number`.

The web has **two** item serializers — `saleItemConverter` for `sales/{id}/items`, and `jobOrderItemsToMaps` / `parseJobOrderItems` in `jobOrderConverter.ts` for the inline JO array. Both must carry the fields or a job order loses its option on bill-out.

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/data/converters/saleItemConverter.test.ts
import { describe, expect, it } from 'vitest';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { saleItemConverter } from './saleItemConverter';
import { jobOrderItemsToMaps, parseJobOrderItems } from './jobOrderConverter';
import {
  saleItemHasOption,
  saleItemOptionSets,
  saleItemQuantityStep,
  type SaleItem,
} from '@/domain/entities/SaleItem';

const withOption: SaleItem = {
  id: 'i1',
  productId: 'p1',
  sku: 'ABC-1',
  name: 'Pulley Ball',
  unitPrice: 110,
  unitCost: 60,
  quantity: 6,
  discountValue: 0,
  unit: 'pcs',
  optionId: 'o2',
  optionLabel: 'By 3',
  optionPieces: 3,
  optionPrice: 330,
};

function snap(data: Record<string, unknown>): QueryDocumentSnapshot<DocumentData> {
  return { id: 'i1', data: () => data } as unknown as QueryDocumentSnapshot<DocumentData>;
}

describe('SaleItem option helpers', () => {
  it('derives sets from pieces', () => {
    expect(saleItemOptionSets(withOption)).toBe(2);
    expect(saleItemHasOption(withOption)).toBe(true);
    expect(saleItemQuantityStep(withOption)).toBe(3);
  });

  it('returns null sets and a step of 1 with no option', () => {
    const plain = { ...withOption, optionId: null, optionPieces: null, optionPrice: null, optionLabel: null };
    expect(saleItemOptionSets(plain)).toBeNull();
    expect(saleItemHasOption(plain)).toBe(false);
    expect(saleItemQuantityStep(plain)).toBe(1);
  });

  // The two cases above CANNOT discriminate a correct implementation from a
  // wrong one: 6 / 3 === 2 exactly, so Math.floor and plain `/` agree, and the
  // no-option case fails clause 1 of hasOption on its own, so clause 3 could be
  // deleted with every test still green. These two can fail.

  it('truncates a non-exact multiple instead of returning a fraction', () => {
    // Plain `/` would give 2.333…; only Math.floor gives 2.
    expect(saleItemOptionSets({ ...withOption, quantity: 7 })).toBe(2);
  });

  it('treats optionPieces: 0 as no option, not a division by zero', () => {
    // optionId stays non-null, so only hasOption's third clause can reject this.
    const zeroPieces = { ...withOption, optionPieces: 0 };
    expect(saleItemHasOption(zeroPieces)).toBe(false);
    expect(saleItemOptionSets(zeroPieces)).toBeNull();
  });
});

describe('saleItemConverter option fields', () => {
  it('round-trips option fields', () => {
    const out = saleItemConverter.toFirestore(withOption) as Record<string, unknown>;
    const back = saleItemConverter.fromFirestore(snap(out));
    expect(back.optionLabel).toBe('By 3');
    expect(back.optionPieces).toBe(3);
    expect(back.optionPrice).toBe(330);
  });

  it('reads a legacy doc with no option fields as nulls', () => {
    const back = saleItemConverter.fromFirestore(
      snap({ productId: 'p1', sku: 'ABC-1', name: 'x', unitPrice: 120, unitCost: 60, quantity: 2 }),
    );
    expect(back.optionId).toBeNull();
    expect(saleItemHasOption(back)).toBe(false);
  });
});

describe('jobOrderConverter option fields', () => {
  it('round-trips option fields through the inline items array', () => {
    const [back] = parseJobOrderItems(jobOrderItemsToMaps([withOption]));
    expect(back.optionLabel).toBe('By 3');
    expect(back.optionPieces).toBe(3);
    expect(saleItemOptionSets(back)).toBe(2);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- saleItemConverter`
Expected: FAIL — helpers not exported, option fields undefined.

- [ ] **Step 3: Write minimal implementation**

In `web_admin/src/domain/entities/SaleItem.ts`, add the four fields to the interface and append:

```ts
/** Whether this line was rung up through a selling option. */
export function saleItemHasOption(item: SaleItem): boolean {
  return item.optionId !== null && item.optionPieces !== null && item.optionPieces > 0;
}

/** Whole sets on this line, or null with no option. quantity is always pieces. */
export function saleItemOptionSets(item: SaleItem): number | null {
  return saleItemHasOption(item) ? Math.floor(item.quantity / (item.optionPieces as number)) : null;
}

/** How much +/- moves this line. A "By 3" line steps 3 -> 6. */
export function saleItemQuantityStep(item: SaleItem): number {
  return saleItemHasOption(item) ? (item.optionPieces as number) : 1;
}
```

In `saleItemConverter.ts`, add to `toFirestore` and `fromFirestore`:

```ts
      optionId: item.optionId,
      optionLabel: item.optionLabel,
      optionPieces: item.optionPieces,
      optionPrice: item.optionPrice,
```

```ts
      optionId: d.optionId ?? null,
      optionLabel: d.optionLabel ?? null,
      optionPieces: d.optionPieces ?? null,
      optionPrice: d.optionPrice ?? null,
```

Apply the same two blocks inside `jobOrderItemsToMaps` and `parseJobOrderItems` in `jobOrderConverter.ts`.

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck`
Expected: PASS. `typecheck` will flag `SaleItem` literals missing the four fields — add `optionId: null, optionLabel: null, optionPieces: null, optionPrice: null` at each.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/entities/SaleItem.ts web_admin/src/data/converters/saleItemConverter.ts web_admin/src/data/converters/jobOrderConverter.ts web_admin/src/data/converters/saleItemConverter.test.ts
git commit -m "feat(web): snapshot the selling option on sale and job-order lines"
```

---

## Phase 2 — Cart behaviour

### Task 8: Mobile cart merges by product and option

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_selling_options_test.dart`

**Interfaces:**
- Consumes: `SaleItemModel.fromProductOption` (Task 6), `SaleItemEntity.quantityStep` (Task 6).
- Produces: `CartNotifier.addProductOption(ProductEntity product, SellingOptionEntity option, {int sets = 1})`; `incrementItemQuantity` / `decrementItemQuantity` step by `item.quantityStep`.

Today `addProduct` and `addItem` merge on `productId` alone. A By 6 and a By 3 of the same product would fold into one line and silently lose a price. The merge key becomes `(productId, optionId)`.

**Note on the steppers:** the POS and job-order screens do **not** call `incrementItemQuantity` / `decrementItemQuantity`. `CartItemTile` owns a private `_QuantityControls` that computes `quantity - 1` / `quantity + 1` itself and hands the absolute result to `onQuantityChanged`, which lands in `updateItemQuantity`. Making the notifier's steppers option-aware here is still correct for any other caller, but the stepping the cashier actually sees is wired in Task 12. Neither task is sufficient alone.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/providers/cart_selling_options_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity product() => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
    );

void main() {
  const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  late ProviderContainer container;
  CartNotifier notifier() => container.read(cartProvider.notifier);
  CartState state() => container.read(cartProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('cart with selling options', () {
    test('the same option twice merges into one line of six pieces', () {
      notifier().addProductOption(product(), by3);
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(1));
      expect(state().items.first.quantity, 6);
      expect(state().items.first.optionSets, 2);
    });

    test('two different options of one product stay separate lines', () {
      notifier().addProductOption(product(), by6);
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(2));
      expect(state().items.map((i) => i.optionLabel), ['By 6', 'By 3']);
    });

    test('an option line and a plain line stay separate', () {
      notifier().addProduct(product());
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(2));
    });

    test('plain lines still merge on product as before', () {
      notifier().addProduct(product());
      notifier().addProduct(product());
      expect(state().items, hasLength(1));
      expect(state().items.first.quantity, 2);
    });

    test('increment steps by the option piece count', () {
      notifier().addProductOption(product(), by3);
      notifier().incrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 6);
    });

    test('decrement steps down by the option piece count', () {
      notifier().addProductOption(product(), by3, sets: 2);
      notifier().decrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 3);
    });

    test('decrementing the last set removes the line', () {
      notifier().addProductOption(product(), by3);
      notifier().decrementItemQuantity(state().items.first.id);
      expect(state().items, isEmpty);
    });

    test('plain lines still step by one', () {
      notifier().addProduct(product());
      notifier().incrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/cart_selling_options_test.dart`
Expected: FAIL — `addProductOption` isn't defined.

- [ ] **Step 3: Write minimal implementation**

In `lib/presentation/providers/cart_provider.dart`:

Change the lookup in `addProduct` so a plain add never merges into an option line:

```dart
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id && item.optionId == null,
    );
```

Change the lookup in `addItem` the same way, matching on both keys:

```dart
    final existingIndex = state.items.indexWhere(
      (i) => i.productId == item.productId && i.optionId == item.optionId,
    );
```

Add the new method after `addProduct`:

```dart
  /// Adds [sets] of a selling option to the cart.
  ///
  /// Lines are keyed by (product, option): the same option merges, a
  /// different option of the same product becomes its own line — they carry
  /// different prices, so folding them would lose money.
  void addProductOption(
    ProductEntity product,
    SellingOptionEntity option, {
    int sets = 1,
  }) {
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id && item.optionId == option.id,
    );

    final updatedItems = List<SaleItemEntity>.from(state.items);
    if (existingIndex >= 0) {
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + option.pieces * sets,
      );
    } else {
      updatedItems.add(SaleItemModel.fromProductOption(
        itemId: _uuid.v4(),
        product: product,
        option: option,
        sets: sets,
      ).toEntity());
    }
    state = state.copyWith(items: updatedItems, clearErrorMessage: true);
  }
```

Make the steppers option-aware:

```dart
  /// Increments by one whole set (one piece when there's no option).
  void incrementItemQuantity(String itemId) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final item = state.items[index];
    updateItemQuantity(itemId, item.quantity + item.quantityStep);
  }

  /// Decrements by one whole set. Dropping below one set removes the line.
  void decrementItemQuantity(String itemId) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;

    final item = state.items[index];
    updateItemQuantity(itemId, item.quantity - item.quantityStep);
  }
```

Import `SaleItemModel` from `package:maki_mobile_pos/data/models/models.dart` if it isn't already imported.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`
Expected: PASS across the suite.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_selling_options_test.dart
git commit -m "feat(pos): merge cart lines by product and selling option"
```

---

### Task 9: Web cart store keys lines by line id

**Files:**
- Modify: `web_admin/src/domain/sales/cart.ts`
- Modify: `web_admin/src/presentation/stores/cartStore.ts`
- Modify: `web_admin/src/presentation/features/pos/CartBuilder.tsx`
- Test: `web_admin/src/domain/sales/cart.test.ts` (create if absent)
- Test: `web_admin/src/presentation/stores/cartStore.test.ts` (create if absent)

**Interfaces:**
- Consumes: `SellingOption` (Task 3), `saleItemQuantityStep` (Task 7).
- Produces: `cartLineId(productId: string, optionId: string | null): string` in `cart.ts`; `cartStore.addLineWithOption(product: Product, option: SellingOption): void`; `setQty`, `setLineDiscount` and `removeLine` take a **line id** instead of a product id.

`lowStockLines` currently compares each line against on-hand stock individually. With two option lines for one product that under-warns, so it must sum quantity per product first.

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/sales/cart.test.ts
import { describe, expect, it } from 'vitest';
import { cartLineId, lowStockLines } from './cart';
import type { CartLine } from './cart';
import type { Product } from '@/domain/entities/Product';

const line = (id: string, productId: string, quantity: number): CartLine =>
  ({
    id,
    productId,
    sku: 'ABC-1',
    name: 'Pulley Ball',
    unitPrice: 110,
    unitCost: 60,
    quantity,
    discountValue: 0,
    unit: 'pcs',
    optionId: null,
    optionLabel: null,
    optionPieces: null,
    optionPrice: null,
  }) as CartLine;

const product = (quantity: number) => ({ id: 'p1', quantity }) as Product;

describe('cartLineId', () => {
  it('is the product id when there is no option', () => {
    expect(cartLineId('p1', null)).toBe('p1');
  });

  it('combines product and option ids when there is one', () => {
    expect(cartLineId('p1', 'o2')).toBe('p1::o2');
  });
});

describe('lowStockLines', () => {
  it('sums quantity across option lines of the same product', () => {
    const lines = [line('p1::o1', 'p1', 6), line('p1::o2', 'p1', 3)];
    expect(lowStockLines(lines, [product(8)])).toEqual(new Set(['p1']));
  });

  it('does not flag when the summed quantity fits', () => {
    const lines = [line('p1::o1', 'p1', 6), line('p1::o2', 'p1', 3)];
    expect(lowStockLines(lines, [product(9)])).toEqual(new Set());
  });
});
```

```ts
// web_admin/src/presentation/stores/cartStore.test.ts
import { describe, expect, it } from 'vitest';
import { createCartStore } from './cartStore';
import type { Product } from '@/domain/entities/Product';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

const product = () =>
  ({
    id: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    cost: 60,
    price: 120,
    unit: 'pcs',
    quantity: 12,
    sellingOptions: [by6, by3],
  }) as Product;

describe('cartStore selling options', () => {
  it('merges the same option and keeps quantity in pieces', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(product(), by3);
    store.getState().addLineWithOption(product(), by3);
    const { lines } = store.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].quantity).toBe(6);
    expect(lines[0].unitPrice).toBe(110);
  });

  it('keeps two different options of one product as separate lines', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(product(), by6);
    store.getState().addLineWithOption(product(), by3);
    expect(store.getState().lines.map((l) => l.id)).toEqual(['p1::o1', 'p1::o2']);
  });

  it('keeps a plain line separate from an option line', () => {
    const store = createCartStore();
    store.getState().addLine(product());
    store.getState().addLineWithOption(product(), by3);
    expect(store.getState().lines).toHaveLength(2);
  });

  it('setQty targets one option line by its line id', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(product(), by6);
    store.getState().addLineWithOption(product(), by3);
    store.getState().setQty('p1::o2', 2);
    const byLine = Object.fromEntries(store.getState().lines.map((l) => [l.id, l.quantity]));
    expect(byLine['p1::o2']).toBe(6);
    expect(byLine['p1::o1']).toBe(6);
  });

  it('setQty on an option line is in sets and stores pieces', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(product(), by3);
    store.getState().setQty('p1::o2', 3);
    expect(store.getState().lines[0].quantity).toBe(9);
  });

  it('removeLine targets one option line', () => {
    const store = createCartStore();
    store.getState().addLineWithOption(product(), by6);
    store.getState().addLineWithOption(product(), by3);
    store.getState().removeLine('p1::o1');
    expect(store.getState().lines.map((l) => l.id)).toEqual(['p1::o2']);
  });

  it('a plain line still uses the product id as its line id', () => {
    const store = createCartStore();
    store.getState().addLine(product());
    expect(store.getState().lines[0].id).toBe('p1');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- cart`
Expected: FAIL — `cartLineId` and `addLineWithOption` don't exist.

- [ ] **Step 3: Write minimal implementation**

In `web_admin/src/domain/sales/cart.ts`, add:

```ts
/**
 * Stable identity for a cart line. Plain lines keep the product id, so
 * nothing changes for products without options; an option line appends the
 * option id, because a By 6 and a By 3 of one product are different prices
 * and must not merge.
 */
export function cartLineId(productId: string, optionId: string | null): string {
  return optionId === null ? productId : `${productId}::${optionId}`;
}
```

and rewrite `lowStockLines` to aggregate per product first:

```ts
/** Product ids whose TOTAL cart quantity exceeds on-hand stock. Summed across
 *  option lines — two lines of one product draw on the same pieces. */
export function lowStockLines(lines: CartLine[], products: Product[]): Set<string> {
  const onHand = new Map(products.map((p) => [p.id, p.quantity]));
  const wanted = new Map<string, number>();
  for (const l of lines) {
    wanted.set(l.productId, (wanted.get(l.productId) ?? 0) + l.quantity);
  }
  const flagged = new Set<string>();
  for (const [productId, qty] of wanted) {
    if (qty > (onHand.get(productId) ?? 0)) flagged.add(productId);
  }
  return flagged;
}
```

In `cartStore.ts`:
- change the `CartState` signatures to `setQty: (lineId: string, quantity: number) => void`, `setLineDiscount: (lineId: string, discountValue: number) => void`, `removeLine: (lineId: string) => void`, and add `addLineWithOption: (product: Product, option: SellingOption) => void`
- in `addLine`, match on `l.id === product.id` and set `id: product.id`, plus the four option fields as `null`
- swap `l.productId === productId` for `l.id === lineId` in `setQty`, `setLineDiscount` and `removeLine`
- make `setQty` set-aware:

```ts
    setQty: (lineId, quantity) =>
      set((s) => ({
        lines: s.lines.map((l) => {
          if (l.id !== lineId) return l;
          // On an option line the typed number is SETS; stored quantity is pieces.
          const step = saleItemQuantityStep(l);
          const n = Math.max(1, Math.floor(quantity) || 1);
          return { ...l, quantity: n * step };
        }),
      })),
```

- add the new action:

```ts
    addLineWithOption: (product, option) =>
      set((s) => {
        const id = cartLineId(product.id, option.id);
        if (s.lines.some((l) => l.id === id)) {
          return {
            lines: s.lines.map((l) =>
              l.id === id ? { ...l, quantity: l.quantity + option.pieces } : l,
            ),
          };
        }
        const line: CartLine = {
          id,
          productId: product.id,
          sku: product.sku,
          name: product.name,
          // Per-piece, so every existing report that multiplies unitPrice by
          // quantity keeps working. optionPrice below is what the UI shows.
          unitPrice: sellingOptionPricePerPiece(option),
          unitCost: product.cost,
          quantity: option.pieces,
          discountValue: 0,
          unit: product.unit,
          optionId: option.id,
          optionLabel: option.label,
          optionPieces: option.pieces,
          optionPrice: option.price,
        };
        return { lines: [...s.lines, line] };
      }),
```

In `CartBuilder.tsx`, change the three call sites at lines 93, 101 and 107 from `l.productId` to `l.id`. For an option line, the quantity input must show **sets**: bind its value to `saleItemOptionSets(l) ?? l.quantity`.

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck && npm run build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/sales/cart.ts web_admin/src/domain/sales/cart.test.ts web_admin/src/presentation/stores/cartStore.ts web_admin/src/presentation/stores/cartStore.test.ts web_admin/src/presentation/features/pos/CartBuilder.tsx
git commit -m "feat(web): key cart lines by line id so options don't merge"
```

---

## Phase 3 — The picker and line rendering

### Task 10: Mobile option picker

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/selling_option_sheet.dart`
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart`
- Modify: `lib/presentation/mobile/screens/job_orders/job_order_edit_screen.dart`
- Test: `test/presentation/mobile/widgets/pos/selling_option_sheet_test.dart`

**Interfaces:**
- Consumes: `ProductEntity.hasSellingOptions` (Task 4), `SellingOptionEntity.pricePerPiece` (Task 1), `CartNotifier.addProductOption` (Task 8).
- Produces: `Future<SellingOptionEntity?> showSellingOptionSheet(BuildContext context, ProductEntity product)` — resolves to the chosen option, or `null` if dismissed.

Follow the existing sheet styling: `AppCard`, the `*Style` helper pattern, Lucide icons, Figtree for text and the `monoFontFamily` token for the SKU. Colour stays neutral — no accent colour on the option rows.

**Wiring rules:** every path that puts a product on a ticket must route through the picker when `product.hasSellingOptions` — the product grid tap, the search-result tap, **and** the barcode-scan resolve. Missing the scanner turns it into a back door around the must-pick-an-option rule. Resuming a saved job order does **not** re-open the picker; those lines already carry their snapshot.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/widgets/pos/selling_option_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/selling_option_sheet.dart';

ProductEntity product(List<SellingOptionEntity> options) => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
      sellingOptions: options,
    );

void main() {
  const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  Future<void> open(WidgetTester tester, ProductEntity p,
      {required void Function(SellingOptionEntity?) onResult}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => onResult(await showSellingOptionSheet(context, p)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every option with its label and set price', (tester) async {
    await open(tester, product([by6, by3]), onResult: (_) {});
    expect(find.text('By 6'), findsOneWidget);
    expect(find.text('By 3'), findsOneWidget);
    expect(find.textContaining('600'), findsOneWidget);
    expect(find.textContaining('330'), findsOneWidget);
  });

  testWidgets('shows the per-piece price as a caption', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.textContaining('110'), findsOneWidget);
  });

  testWidgets('shows on-hand pieces in the header', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    // findsOneWidget, not findsWidgets — the loose form would still pass if the
    // header rendered twice, which is exactly the bug worth catching here.
    expect(find.textContaining('12'), findsOneWidget);
  });

  testWidgets('returns the tapped option', (tester) async {
    SellingOptionEntity? result;
    await open(tester, product([by6, by3]), onResult: (r) => result = r);
    await tester.tap(find.text('By 3'));
    await tester.pumpAndSettle();
    expect(result, by3);
  });

  testWidgets('returns null when dismissed', (tester) async {
    SellingOptionEntity? result = by6;
    await open(tester, product([by6]), onResult: (r) => result = r);
    Navigator.of(tester.element(find.text('By 6'))).pop();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('opens even for a single option so the price is shown', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.text('By 3'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/pos/selling_option_sheet_test.dart`
Expected: FAIL — `showSellingOptionSheet` isn't defined.

- [ ] **Step 3: Write minimal implementation**

Create the sheet. Each row shows `label` on the left, set price on the right, and `pieces` plus the per-piece price as captions. Header carries the product name, SKU in the mono token, and `${product.quantity} ${product.unit} on hand`. An option whose `pieces` exceeds `product.quantity` stays tappable and shows the existing low-stock chip — the POS warns rather than blocks, and this must not become the one place that hard-stops a sale.

```dart
Future<SellingOptionEntity?> showSellingOptionSheet(
  BuildContext context,
  ProductEntity product,
) {
  return showModalBottomSheet<SellingOptionEntity>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SellingOptionSheet(product: product),
  );
}
```

Then wire the three entry points. In `pos_screen.dart`, wherever the code currently calls `cartNotifier.addProduct(product)` — the grid tap, the search-result tap and the barcode-scan handler — replace with:

```dart
  Future<void> _addToCart(ProductEntity product) async {
    if (!product.hasSellingOptions) {
      ref.read(cartProvider.notifier).addProduct(product);
      return;
    }
    final option = await showSellingOptionSheet(context, product);
    if (option == null) return;
    if (!mounted) return;
    ref.read(cartProvider.notifier).addProductOption(product, option);
  }
```

Apply the same helper in `job_order_edit_screen.dart` for its add-part path. Leave the job-order **resume** path alone — those lines carry their own snapshot.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/selling_option_sheet.dart lib/presentation/mobile/screens/pos/pos_screen.dart lib/presentation/mobile/screens/job_orders/job_order_edit_screen.dart test/presentation/mobile/widgets/pos/selling_option_sheet_test.dart
git commit -m "feat(pos): mobile selling-option picker on tap, search and scan"
```

---

### Task 11: Web option picker

**Files:**
- Create: `web_admin/src/presentation/features/pos/SellingOptionDialog.tsx`
- Create: `web_admin/src/presentation/features/pos/SellingOptionDialog.test.tsx`
- Modify: `web_admin/src/presentation/features/pos/CartBuilder.tsx`

**Interfaces:**
- Consumes: `productHasSellingOptions` (Task 5), `sellingOptionPricePerPiece` (Task 3), `cartStore.addLineWithOption` (Task 9).
- Produces: `<SellingOptionDialog product={product} onPick={(option) => void} onClose={() => void} />`.

Match the existing web dialog patterns and design tokens (`bg-light-subtle`, `text-bodySmall`, `gap-tk-md`) used in the POS feature folder.

- [ ] **Step 1: Write the failing test**

```tsx
// web_admin/src/presentation/features/pos/SellingOptionDialog.test.tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SellingOptionDialog } from './SellingOptionDialog';
import type { Product } from '@/domain/entities/Product';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

const product = () =>
  ({
    id: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    cost: 60,
    price: 120,
    unit: 'pcs',
    quantity: 12,
    sellingOptions: [by6, by3],
  }) as Product;

describe('SellingOptionDialog', () => {
  it('lists every option with its set price', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText('By 6')).toBeInTheDocument();
    expect(screen.getByText('By 3')).toBeInTheDocument();
    expect(screen.getByText(/600/)).toBeInTheDocument();
    expect(screen.getByText(/330/)).toBeInTheDocument();
  });

  it('shows the per-piece price as a caption', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText(/110/)).toBeInTheDocument();
  });

  it('shows on-hand pieces', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText(/12/)).toBeInTheDocument();
  });

  it('calls onPick with the chosen option', async () => {
    const onPick = vi.fn();
    render(<SellingOptionDialog product={product()} onPick={onPick} onClose={vi.fn()} />);
    await userEvent.click(screen.getByText('By 3'));
    expect(onPick).toHaveBeenCalledWith(by3);
  });

  it('calls onClose when cancelled', async () => {
    const onClose = vi.fn();
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={onClose} />);
    await userEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(onClose).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- SellingOptionDialog`
Expected: FAIL — component doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Build the dialog with one button per option (label, pieces, set price, per-piece caption) plus a Cancel button. Then in `CartBuilder.tsx`, replace the direct `addLine(p)` at line 57 with a handler that opens the dialog when the product has options:

```tsx
  const [pending, setPending] = useState<Product | null>(null);

  const handlePick = (p: Product) => {
    if (!productHasSellingOptions(p)) {
      addLine(p);
      return;
    }
    setPending(p);
  };
```

and render `{pending && <SellingOptionDialog product={pending} onPick={(o) => { addLineWithOption(pending, o); setPending(null); }} onClose={() => setPending(null)} />}`.

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck && npm run build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/pos/SellingOptionDialog.tsx web_admin/src/presentation/features/pos/SellingOptionDialog.test.tsx web_admin/src/presentation/features/pos/CartBuilder.tsx
git commit -m "feat(web): selling-option picker in the POS cart builder"
```

---

### Task 12: Render the option on cart tiles and receipts

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/cart_item_tile.dart`
- Modify: `lib/presentation/mobile/widgets/pos/receipt_widget.dart`
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
- Modify: `web_admin/src/presentation/features/reports/Receipt.tsx`
- Modify: `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`
- Test: `test/presentation/mobile/widgets/pos/cart_item_tile_test.dart`
- Test: `web_admin/src/presentation/features/reports/Receipt.test.tsx` (extend the existing file)

**Interfaces:**
- Consumes: `SaleItemEntity.optionSets` / `hasOption` / `quantityStep` (Task 6), `saleItemOptionSets` / `saleItemHasOption` (Task 7).
- Produces: `_QuantityControls` in `cart_item_tile.dart` gains `required int step`.

Display rule, both surfaces: a line with no option renders exactly as it does today. A line with an option renders the label beside the name and, when more than one set, the set count and total pieces.

- One set: `Pulley Ball · By 3` … `₱330.00`
- Two sets: `Pulley Ball · By 3` / `By 3 × 2 (6 pcs)` … `₱660.00`

**This task carries the stepping the cashier actually sees.** `_QuantityControls` currently hard-codes `onChanged(quantity - 1)` / `onChanged(quantity + 1)` and disables minus at `quantity > 1`. On a By 3 line that walks 3 → 2 — a broken half-set at a price that was never quoted. It must step by the option's piece count, disable minus at one whole set, and display **sets** rather than pieces.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/widgets/pos/cart_item_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_item_tile.dart';

SaleItemEntity item({String? label, int? pieces, double? optionPrice, int quantity = 1}) {
  return SaleItemEntity(
    id: 'i1',
    productId: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    unitPrice: pieces == null ? 120 : (optionPrice ?? 0) / pieces,
    unitCost: 60,
    quantity: quantity,
    unit: 'pcs',
    optionId: label == null ? null : 'o2',
    optionLabel: label,
    optionPieces: pieces,
    optionPrice: optionPrice,
  );
}

Future<List<int>> pumpTile(WidgetTester tester, SaleItemEntity value) async {
  final emitted = <int>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CartItemTile(
        item: value,
        discountType: DiscountType.amount,
        onQuantityChanged: emitted.add,
        onDiscountTap: () {},
        onRemove: () {},
      ),
    ),
  ));
  return emitted;
}

void main() {
  group('CartItemTile with a selling option', () {
    testWidgets('shows the option label beside the name', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      expect(find.textContaining('By 3'), findsWidgets);
    });

    testWidgets('shows sets and total pieces for more than one set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      expect(find.textContaining('By 3 × 2'), findsOneWidget);
      expect(find.textContaining('6 pcs'), findsOneWidget);
    });

    testWidgets('does not show a set count for a single set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      expect(find.textContaining('× 2'), findsNothing);
    });

    testWidgets('a line with no option renders unchanged', (tester) async {
      await pumpTile(tester, item(quantity: 2));
      expect(find.textContaining('By'), findsNothing);
    });
  });

  group('CartItemTile quantity stepping', () {
    testWidgets('plus steps a By 3 line by three pieces', (tester) async {
      final emitted =
          await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(emitted, [6]);
    });

    testWidgets('minus steps a By 3 line down by three pieces', (tester) async {
      final emitted =
          await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      expect(emitted, [3]);
    });

    testWidgets('minus is disabled at one whole set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      final minus = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(LucideIcons.minus), matching: find.byType(IconButton)),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('the control displays sets, not pieces', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('a plain line still steps by one', (tester) async {
      final emitted = await pumpTile(tester, item(quantity: 2));
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(emitted, [3]);
    });
  });
}
```

Add `import 'package:lucide_icons_flutter/lucide_icons.dart';` to the test file for the icon finders.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/pos/cart_item_tile_test.dart`
Expected: FAIL — the option label isn't rendered and the plus button emits 4, not 6.

- [ ] **Step 3: Write minimal implementation**

In `cart_item_tile.dart`:

- add the option label beside the name and the sets caption, both guarded by `item.hasOption`, using the existing caption text style
- give `_QuantityControls` a `required int step` field, pass `step: item.quantityStep` from `CartItemTile`, and use it throughout:

```dart
          IconButton(
            icon: const Icon(LucideIcons.minus),
            // Disabled at one whole set — stepping below it would price a
            // partial set the shop never quoted.
            onPressed: quantity > step ? () => onChanged(quantity - step) : null,
```

and the same `quantity + step` on the plus button. The number between them displays `quantity ~/ step`, so a By 3 line at 6 pieces reads `2`.

Mirror the guarded label rendering in `receipt_widget.dart`, `sale_detail_screen.dart`, `Receipt.tsx` and `SaleDetailPage.tsx`. Keep it neutral-coloured — this is information, not status.

Check the job-order edit screen too: it feeds its own tile's `onQuantityChanged` into `JobOrderEntity.updateItemQuantity`. Whatever quantity widget it uses needs the same `step`, or a By 3 part on a job order steps by one.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`, then from `web_admin/`: `npm run test && npm run typecheck && npm run build`
Expected: PASS on both surfaces.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/ lib/presentation/mobile/screens/sales/sale_detail_screen.dart web_admin/src/presentation/features/reports/Receipt.tsx web_admin/src/presentation/features/reports/SaleDetailPage.tsx test/presentation/mobile/widgets/pos/cart_item_tile_test.dart web_admin/src/presentation/features/reports/Receipt.test.tsx
git commit -m "feat(pos): show the selling option on cart tiles and receipts"
```

---

## Phase 4 — Authoring and permissions

### Task 13: Lock selling options to admins

**Files:**
- Modify: `firestore.rules`
- Modify: `web_admin/src/data/products/productWrites.ts`
- Test: `tools/firestore-rules-test/test/rules.test.js`

**Interfaces:**
- Consumes: `ProductModel.toUpdateMap(..., includeSellingOptions:)` (Task 4).
- Produces: `sellingOptions` denied to staff and cashier on product update.

`create` stays unrestricted, matching how `price` already works — staff may set a price at creation but not edit it afterwards. That is the existing posture; this task does not change it.

- [ ] **Step 1: Write the failing test**

Add to `tools/firestore-rules-test/test/rules.test.js`, following the file's existing helper style for seeding a product and getting a role-scoped context:

```js
describe('products: sellingOptions is admin-only', () => {
  const options = [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }];

  it('admin can set sellingOptions', async () => {
    await assertSucceeds(adminDb().doc('products/p1').update({ sellingOptions: options }));
  });

  it('staff cannot set sellingOptions', async () => {
    await assertFails(staffDb().doc('products/p1').update({ sellingOptions: options }));
  });

  it('cashier cannot set sellingOptions', async () => {
    await assertFails(cashierDb().doc('products/p1').update({ sellingOptions: options }));
  });

  it('staff can still edit permitted fields on a product with no sellingOptions field', async () => {
    await assertSucceeds(staffDb().doc('products/p1').update({ name: 'Renamed', notes: 'x' }));
  });

  it('cashier can still edit name on a product with no sellingOptions field', async () => {
    await assertSucceeds(cashierDb().doc('products/p1').update({ name: 'Renamed' }));
  });

  it('any valid user can still deduct stock during a sale', async () => {
    await assertSucceeds(
      cashierDb().doc('products/p1').update({
        quantity: 9,
        updatedAt: new Date(),
        updatedBy: 'u1',
        updatedByName: 'Cashier',
      }),
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `tools/firestore-rules-test/`): `npm test`
Expected: FAIL — the staff and cashier `sellingOptions` writes currently succeed.

- [ ] **Step 3: Write minimal implementation**

In `firestore.rules`, add `'sellingOptions'` to both denylists under `match /products/{productId}`:

```
      // Staff can update product fields EXCEPT sku, price, cost, costCode, and
      // sellingOptions (SKU edits are admin-only; selling options set prices,
      // so they carry the same lock as price). Unchanged values never appear
      // in affectedKeys(), so a staff edit that leaves them alone still passes.
      allow update: if hasRole('staff') && isActiveUser() &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['sku', 'price', 'cost', 'costCode', 'sellingOptions']);
```

and add `'sellingOptions'` to the cashier `hasAny([...])` list.

Both client write paths must keep the key out of non-admin updates, or a staff edit to a doc lacking the field would add it and be rejected. The Dart side is already handled by `includeSellingOptions` (Task 4) — audit every `toUpdateMap` caller and pass `includeSellingOptions: true` only on the admin edit path. In `web_admin/src/data/products/productWrites.ts`, do the same: build the update payload without `sellingOptions` unless the caller is an admin.

- [ ] **Step 4: Run test to verify it passes**

Run (from `tools/firestore-rules-test/`): `npm test`
Then `flutter test && flutter analyze`, and from `web_admin/`: `npm run test && npm run typecheck`
Expected: PASS everywhere.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js web_admin/src/data/products/productWrites.ts
git commit -m "feat(rules): lock sellingOptions to admins on product update"
```

**Do not deploy the rules.** `CLAUDE.md` requires confirmation before deploying `firestore.rules`. Flag it for the user at the end of the phase.

---

### Task 14: Options editor in the mobile product form

**Files:**
- Create: `lib/presentation/mobile/widgets/inventory/selling_options_editor.dart`
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`
- Test: `test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart`

**Interfaces:**
- Consumes: `validateSellingOptions`, `kMaxSellingOptions` (Task 2).
- Produces: `SellingOptionsEditor({required List<SellingOptionEntity> value, required ValueChanged<List<SellingOptionEntity>> onChanged, required double unitCost, required String unit})`.

Visible only when the signed-in user is an admin — mirror how the form already gates the cost field. New rows get an id from the same `Uuid` the cart uses.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/selling_options_editor.dart';

void main() {
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  Future<List<SellingOptionEntity>> pump(
    WidgetTester tester,
    List<SellingOptionEntity> initial,
  ) async {
    var current = initial;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SellingOptionsEditor(
            value: current,
            onChanged: (next) => setState(() => current = next),
            unitCost: 60,
            unit: 'pcs',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return current;
  }

  testWidgets('renders one row per option', (tester) async {
    await pump(tester, [by3]);
    expect(find.text('By 3'), findsOneWidget);
  });

  testWidgets('shows the derived per-piece price', (tester) async {
    await pump(tester, [by3]);
    expect(find.textContaining('110'), findsWidgets);
  });

  testWidgets('adding a row appends an option with a fresh id', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(const Key('add-selling-option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selling-option-row-0')), findsOneWidget);
  });

  testWidgets('removing a row drops it', (tester) async {
    await pump(tester, [by3]);
    await tester.tap(find.byKey(const Key('remove-selling-option-0')));
    await tester.pumpAndSettle();
    expect(find.text('By 3'), findsNothing);
  });

  testWidgets('hides the add button at the 10-option cap', (tester) async {
    final ten = List.generate(
      10,
      (i) => SellingOptionEntity(id: '$i', label: 'By $i', pieces: i + 1, price: 100),
    );
    await pump(tester, ten);
    expect(find.byKey(const Key('add-selling-option')), findsNothing);
  });

  testWidgets('shows the validation message for a duplicate label', (tester) async {
    await pump(tester, [by3, by3.copyWith(id: 'o9')]);
    expect(find.textContaining('unique'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart`
Expected: FAIL — `SellingOptionsEditor` isn't defined.

- [ ] **Step 3: Write minimal implementation**

Build the editor with an `AppCard` per row: a label field, a pieces field (integer), a price field (currency), a remove button keyed `remove-selling-option-$index`, and a caption showing `pricePerPiece` and the margin against `unitCost`. An add button keyed `add-selling-option`, hidden once `value.length == kMaxSellingOptions`. Surface `validateSellingOptions(value)` below the list when it returns non-null.

In `product_form_screen.dart`, render the editor inside the existing admin-only section, hold the options in form state, block save when `validateSellingOptions` returns a message, and pass `includeSellingOptions: true` on the admin save path.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/inventory/selling_options_editor.dart lib/presentation/mobile/screens/inventory/product_form_screen.dart test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart
git commit -m "feat(inventory): selling-options editor in the mobile product form"
```

---

### Task 15: Options editor in the web product form

**Files:**
- Create: `web_admin/src/presentation/features/inventory/SellingOptionsEditor.tsx`
- Create: `web_admin/src/presentation/features/inventory/SellingOptionsEditor.test.tsx`
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts`

**Interfaces:**
- Consumes: `validateSellingOptions`, `MAX_SELLING_OPTIONS` (Task 3), `sellingOptionPricePerPiece` (Task 3).
- Produces: `<SellingOptionsEditor value={SellingOption[]} onChange={(next) => void} unitCost={number} unit={string} />`.

- [ ] **Step 1: Write the failing test**

```tsx
// web_admin/src/presentation/features/inventory/SellingOptionsEditor.test.tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SellingOptionsEditor } from './SellingOptionsEditor';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

describe('SellingOptionsEditor', () => {
  it('renders one row per option', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.getByDisplayValue('By 3')).toBeInTheDocument();
  });

  it('shows the derived per-piece price', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.getByText(/110/)).toBeInTheDocument();
  });

  it('adds a row with a fresh id', async () => {
    const onChange = vi.fn();
    render(<SellingOptionsEditor value={[]} onChange={onChange} unitCost={60} unit="pcs" />);
    await userEvent.click(screen.getByRole('button', { name: /add option/i }));
    expect(onChange).toHaveBeenCalledWith([expect.objectContaining({ id: expect.any(String) })]);
  });

  it('removes a row', async () => {
    const onChange = vi.fn();
    render(<SellingOptionsEditor value={[by3]} onChange={onChange} unitCost={60} unit="pcs" />);
    await userEvent.click(screen.getByRole('button', { name: /remove/i }));
    expect(onChange).toHaveBeenCalledWith([]);
  });

  it('hides the add button at the 10-option cap', () => {
    const ten = Array.from({ length: 10 }, (_, i) => ({
      id: `${i}`,
      label: `By ${i}`,
      pieces: i + 1,
      price: 100,
    }));
    render(<SellingOptionsEditor value={ten} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.queryByRole('button', { name: /add option/i })).toBeNull();
  });

  it('shows the validation message for a duplicate label', () => {
    render(
      <SellingOptionsEditor
        value={[by3, { ...by3, id: 'o9' }]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
      />,
    );
    expect(screen.getByText(/unique/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- SellingOptionsEditor`
Expected: FAIL — component doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Build the editor as a table of rows (label / pieces / price / per-piece caption / remove), an "Add option" button hidden at `MAX_SELLING_OPTIONS`, and the `validateSellingOptions` message beneath. Use `crypto.randomUUID()` for new ids, matching `addLaborLine` in `cartStore.ts`.

Mount it in `InventoryFormPage.tsx` inside the admin-only section, block submit while validation returns a message, and thread `sellingOptions` through `useProductMutations.ts` — writing the key only on the admin path, per Task 13.

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck && npm run build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/inventory/SellingOptionsEditor.tsx web_admin/src/presentation/features/inventory/SellingOptionsEditor.test.tsx web_admin/src/presentation/features/inventory/InventoryFormPage.tsx web_admin/src/presentation/hooks/useProductMutations.ts
git commit -m "feat(inventory): selling-options editor in the web product form"
```

---

## Phase 5 — Price history

### Task 16: Option-aware price-history events (both surfaces)

**Files:**
- Modify: `lib/core/utils/selling_options.dart`
- Modify: `lib/domain/repositories/product_repository.dart`
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Modify: `web_admin/src/domain/products/sellingOptions.ts`
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/data/products/productWrites.ts`
- Test: `test/core/utils/selling_options_history_test.dart`
- Test: `web_admin/src/domain/products/sellingOptions.test.ts` (extend)

**Interfaces:**
- Produces, both surfaces, same semantics:
  - `PriceHistoryEntry` gains `String? optionId`, `String? optionLabel`, `int? optionPieces` (TS: `optionId: string | null`, `optionLabel: string | null`, `optionPieces: number | null`).
  - Dart: `List<SellingOptionHistoryEvent> sellingOptionHistoryEvents(List<SellingOptionEntity> before, List<SellingOptionEntity> after, double unitCost)`
  - TS: `sellingOptionHistoryEvents(before: SellingOption[], after: SellingOption[], unitCost: number): SellingOptionHistoryEvent[]`
  - Event shape: `{optionId, optionLabel, optionPieces, price, cost, reason}` where `cost = optionPieces * unitCost`.

Reason mapping, exactly:

| Change | reason |
|---|---|
| option present in `after` only | `'Option added'` |
| option present in `before` only | `'Option removed'` (price, pieces from `before`) |
| `pieces` changed (with or without price) | `'Option changed'` |
| `price` changed only | `'Price update'` |
| nothing changed | no event |

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/selling_options_history_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SellingOptionEntity opt(String id, String label, int pieces, double price) =>
    SellingOptionEntity(id: id, label: label, pieces: pieces, price: price);

void main() {
  final by3 = opt('o2', 'By 3', 3, 330);

  group('sellingOptionHistoryEvents', () {
    test('no change yields no events', () {
      expect(sellingOptionHistoryEvents([by3], [by3], 60), isEmpty);
    });

    test('an added option logs Option added with its set cost', () {
      final events = sellingOptionHistoryEvents(const [], [by3], 60);
      expect(events, hasLength(1));
      expect(events.single.reason, 'Option added');
      expect(events.single.price, 330);
      expect(events.single.cost, 180);
      expect(events.single.optionPieces, 3);
    });

    test('a removed option logs Option removed with its last known price', () {
      final events = sellingOptionHistoryEvents([by3], const [], 60);
      expect(events.single.reason, 'Option removed');
      expect(events.single.price, 330);
      expect(events.single.optionLabel, 'By 3');
    });

    test('a price-only change logs Price update', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(price: 360)], 60);
      expect(events.single.reason, 'Price update');
      expect(events.single.price, 360);
    });

    test('a piece-count change logs Option changed', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(pieces: 4, price: 440)], 60);
      expect(events.single.reason, 'Option changed');
      expect(events.single.optionPieces, 4);
      expect(events.single.cost, 240);
    });

    test('a label-only rename logs nothing', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(label: 'Half box')], 60);
      expect(events, isEmpty);
    });

    test('sub-centavo price drift logs nothing', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(price: 330.005)], 60);
      expect(events, isEmpty);
    });

    test('handles several options changing at once', () {
      final by6 = opt('o1', 'By 6', 6, 600);
      final events = sellingOptionHistoryEvents(
        [by6, by3],
        [by6.copyWith(price: 650)],
        60,
      );
      expect(events.map((e) => e.reason).toSet(), {'Price update', 'Option removed'});
    });
  });
}
```

Mirror every case in `sellingOptions.test.ts` using the TS names.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/selling_options_history_test.dart`
Then from `web_admin/`: `npm run test -- sellingOptions`
Expected: FAIL on both — `sellingOptionHistoryEvents` isn't defined.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/core/utils/selling_options.dart`:

```dart
/// One price_history entry to write for a selling-option change.
class SellingOptionHistoryEvent {
  const SellingOptionHistoryEvent({
    required this.optionId,
    required this.optionLabel,
    required this.optionPieces,
    required this.price,
    required this.cost,
    required this.reason,
  });

  final String optionId;
  final String optionLabel;
  final int optionPieces;

  /// Price of the whole set.
  final double price;

  /// Cost of the whole set — pieces x unit cost — so the report's margin
  /// column compares like with like against [price].
  final double cost;

  final String reason;
}

/// One centavo. Matches the threshold priceHistoryReason already uses, so a
/// rounding wobble never writes a history entry.
const double _historyEps = 0.01;

/// Diffs a product's selling options and returns the price_history entries to
/// write. Label-only renames produce nothing — a rename isn't a price event.
List<SellingOptionHistoryEvent> sellingOptionHistoryEvents(
  List<SellingOptionEntity> before,
  List<SellingOptionEntity> after,
  double unitCost,
) {
  final beforeById = {for (final o in before) o.id: o};
  final afterById = {for (final o in after) o.id: o};
  final events = <SellingOptionHistoryEvent>[];

  SellingOptionHistoryEvent event(SellingOptionEntity o, String reason) {
    return SellingOptionHistoryEvent(
      optionId: o.id,
      optionLabel: o.label,
      optionPieces: o.pieces,
      price: o.price,
      cost: o.pieces * unitCost,
      reason: reason,
    );
  }

  for (final o in after) {
    final prior = beforeById[o.id];
    if (prior == null) {
      events.add(event(o, 'Option added'));
      continue;
    }
    final piecesChanged = prior.pieces != o.pieces;
    final priceChanged = (prior.price - o.price).abs() > _historyEps;
    if (piecesChanged) {
      events.add(event(o, 'Option changed'));
    } else if (priceChanged) {
      events.add(event(o, 'Price update'));
    }
  }

  for (final o in before) {
    if (!afterById.containsKey(o.id)) events.add(event(o, 'Option removed'));
  }

  return events;
}
```

Port the same function to `web_admin/src/domain/products/sellingOptions.ts` with the TS interface `SellingOptionHistoryEvent`.

Add the three optional fields to `PriceHistoryEntry` on both surfaces. Then, on the admin product-save path — `product_repository_impl.dart` for Flutter and `productWrites.ts` for web — call `sellingOptionHistoryEvents(oldOptions, newOptions, unitCost)` and write one `price_history` doc per event, alongside the existing base-price entry. Base entries leave the three option fields absent.

Do **not** touch the receiving path: a cost change still writes exactly one base entry, never one per option.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`, then from `web_admin/`: `npm run test && npm run typecheck && npm run build`
Expected: PASS.

Then prove the receiving path stayed put. Add to the existing receiving repository tests on both surfaces (`web_admin/src/data/receiving/executeReceivePlan.test.ts` and its Dart counterpart) a case asserting that receiving a product **with** selling options writes exactly one `price_history` entry, with no option fields:

```ts
it('writes one base price_history entry for a product with selling options', async () => {
  const product = { ...baseProduct, sellingOptions: [by6, by3] };
  const writes = await runReceivePlan(product, { newCost: 70 });
  const history = writes.filter((w) => w.path.includes('price_history'));
  expect(history).toHaveLength(1);
  expect(history[0].data.optionId).toBeUndefined();
});
```

Shape the fixture and `runReceivePlan` helper to match the file's existing harness.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/selling_options.dart lib/domain/repositories/product_repository.dart lib/data/repositories/product_repository_impl.dart web_admin/src/domain/products/sellingOptions.ts web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/products/productWrites.ts test/core/utils/selling_options_history_test.dart web_admin/src/domain/products/sellingOptions.test.ts
git commit -m "feat(inventory): log price history for selling-option changes"
```

---

### Task 17: Split price history into series

**Files:**
- Modify: `lib/core/utils/price_history_view.dart`
- Modify: `web_admin/src/domain/products/priceHistory.ts`
- Test: `test/core/utils/price_history_series_test.dart`
- Test: `web_admin/src/domain/products/priceHistory.test.ts` (extend, create if absent)

**Interfaces:**
- Produces, both surfaces:
  - `PriceHistorySeries { String? optionId; String label; List<PriceHistoryEntry> entries; }` (TS: `optionId: string | null`)
  - `List<PriceHistorySeries> splitPriceHistorySeries(List<PriceHistoryEntry> entriesNewestFirst)` — base series first (label `'Base price'`), then one per option in first-seen order, each preserving newest-first ordering.
  - `derivePriceHistorySource` gains cases for the three new reasons.

`buildPriceHistoryRows` and `sparklineSeries` already assume one continuous stream — they subtract each entry from the next. Feeding them mixed base and option entries makes every delta and the whole sparkline meaningless. Callers must split first, then call the existing functions per series. Neither existing function changes.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/price_history_series_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_history_view.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

// PriceHistoryEntry requires `id` — see lib/domain/repositories/product_repository.dart.
PriceHistoryEntry entry({
  required double price,
  double cost = 60,
  String? optionId,
  String? optionLabel,
  int? optionPieces,
  int day = 1,
}) {
  return PriceHistoryEntry(
    id: 'e$day${optionId ?? ''}',
    price: price,
    cost: cost,
    changedAt: DateTime(2026, 7, day),
    changedBy: 'u1',
    reason: 'Price update',
    optionId: optionId,
    optionLabel: optionLabel,
    optionPieces: optionPieces,
  );
}

void main() {
  group('splitPriceHistorySeries', () {
    test('entries with no option fields form a single base series', () {
      final series = splitPriceHistorySeries([
        entry(price: 130, day: 2),
        entry(price: 120, day: 1),
      ]);
      expect(series, hasLength(1));
      expect(series.single.optionId, isNull);
      expect(series.single.label, 'Base price');
      expect(series.single.entries, hasLength(2));
    });

    test('separates base and option entries', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 130, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.map((s) => s.label), ['Base price', 'By 3']);
      expect(series[0].entries, hasLength(1));
      expect(series[1].entries, hasLength(2));
    });

    test('keeps each series newest-first', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.single.entries.first.price, 360);
    });

    test('omits the base series when there are no base entries', () {
      final series = splitPriceHistorySeries([
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
      ]);
      expect(series.map((s) => s.label), ['By 3']);
    });

    test('deltas computed per series never mix base and option prices', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 130, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      final optionRows =
          buildPriceHistoryRows(series[1].entries, PriceMetric.price);
      expect(optionRows.first.priceDelta, 30);
    });

    test('several options each get their own series', () {
      final series = splitPriceHistorySeries([
        entry(price: 600, optionId: 'o1', optionLabel: 'By 6', optionPieces: 6, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.map((s) => s.label), ['By 6', 'By 3']);
    });
  });
}
```

Mirror the same cases in `web_admin/src/domain/products/priceHistory.test.ts`, plus:

```ts
it('labels the new reasons on the Source column', () => {
  expect(derivePriceHistorySource('Option added', null)).toBe('Option added');
  expect(derivePriceHistorySource('Option removed', null)).toBe('Option removed');
  expect(derivePriceHistorySource('Option changed', null)).toBe('Option changed');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/price_history_series_test.dart`
Then from `web_admin/`: `npm run test -- priceHistory`
Expected: FAIL — `splitPriceHistorySeries` isn't defined.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/core/utils/price_history_view.dart`:

```dart
/// One continuous price series — the base price, or one selling option.
///
/// [buildPriceHistoryRows] and the sparkline both subtract each entry from
/// the next, so they are only meaningful within a single series. Mixing base
/// and option entries produces a chart that zigzags between the per-piece
/// base price and the whole-set option price, with deltas to match.
class PriceHistorySeries {
  const PriceHistorySeries({
    required this.optionId,
    required this.label,
    required this.entries,
  });

  /// Null for the base price series.
  final String? optionId;

  /// Display name — 'Base price', or the option's label.
  final String label;

  /// Newest-first, matching the order the repository returns.
  final List<PriceHistoryEntry> entries;
}

/// Splits [entriesNewestFirst] into independent series: base first (when it
/// has any entries), then one per option in first-seen order.
List<PriceHistorySeries> splitPriceHistorySeries(
  List<PriceHistoryEntry> entriesNewestFirst,
) {
  final base = <PriceHistoryEntry>[];
  final byOption = <String, List<PriceHistoryEntry>>{};
  final labels = <String, String>{};

  for (final entry in entriesNewestFirst) {
    final optionId = entry.optionId;
    if (optionId == null) {
      base.add(entry);
      continue;
    }
    byOption.putIfAbsent(optionId, () => <PriceHistoryEntry>[]).add(entry);
    labels[optionId] ??= entry.optionLabel ?? optionId;
  }

  return [
    if (base.isNotEmpty)
      PriceHistorySeries(optionId: null, label: 'Base price', entries: base),
    for (final id in byOption.keys)
      PriceHistorySeries(optionId: id, label: labels[id]!, entries: byOption[id]!),
  ];
}
```

Port the same to `priceHistory.ts`, and extend `derivePriceHistorySource` — the existing `default: return reason;` branch already returns the three new literals verbatim, so add explicit cases only if you want different display text. The test above asserts the pass-through, so no change is strictly needed; confirm the test passes before touching it.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`, then from `web_admin/`: `npm run test && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/price_history_view.dart web_admin/src/domain/products/priceHistory.ts test/core/utils/price_history_series_test.dart web_admin/src/domain/products/priceHistory.test.ts
git commit -m "feat(inventory): split price history into base and per-option series"
```

---

### Task 18: Series selector on the price-history views

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/price_history_screen.dart`
- Modify: `web_admin/src/presentation/features/inventory/PriceHistoryView.tsx`
- Test: `test/presentation/mobile/screens/inventory/price_history_screen_test.dart` (extend — the harness is already there)
- Test: `web_admin/src/presentation/features/inventory/PriceHistoryView.test.tsx` (create if absent)

**Interfaces:**
- Consumes: `splitPriceHistorySeries`, `PriceHistorySeries` (Task 17), the unchanged `buildPriceHistoryRows` and `sparklineSeries`.

Both views currently pass the raw entry list straight into `buildPriceHistoryRows`. They must call `splitPriceHistorySeries` first, render a selector when there is more than one series, and feed only the selected series into the existing row and sparkline functions. With a single series, no selector renders and the view looks exactly as it does today.

- [ ] **Step 1: Write the failing test**

Extend `test/presentation/mobile/screens/inventory/price_history_screen_test.dart`. It already has the harness: a `_pump(tester, entries)` that overrides `priceHistoryProvider('p-1')` and `userByIdProvider('u1')` inside a `ProviderScope`, and an `_e(id, price, cost, at, {reason})` builder. Widen `_e` to take the option fields, then add:

```dart
PriceHistoryEntry _o(
  String id,
  double price,
  DateTime at, {
  required String optionId,
  required String optionLabel,
  required int optionPieces,
}) =>
    PriceHistoryEntry(
      id: id,
      price: price,
      cost: 180,
      changedAt: at,
      changedBy: 'u1',
      reason: 'Price update',
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
    );

void main() {
  // ... existing tests ...

  group('selling-option series', () {
    final baseOnly = [
      _e('e2', 130, 60, DateTime(2026, 7, 2)),
      _e('e1', 120, 60, DateTime(2026, 7, 1)),
    ];
    final mixed = [
      _o('o-e2', 360, DateTime(2026, 7, 3),
          optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
      _e('e2', 130, 60, DateTime(2026, 7, 2)),
      _o('o-e1', 330, DateTime(2026, 7, 1),
          optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
    ];

    testWidgets('renders no selector when there is only a base series',
        (tester) async {
      await _pump(tester, baseOnly);
      expect(find.text('Base price'), findsNothing);
      expect(find.text('By 3'), findsNothing);
    });

    testWidgets('renders a chip per series when options are present',
        (tester) async {
      await _pump(tester, mixed);
      expect(find.text('Base price'), findsOneWidget);
      expect(find.text('By 3'), findsOneWidget);
    });

    testWidgets('defaults to the base series', (tester) async {
      await _pump(tester, mixed);
      expect(find.textContaining('130'), findsWidgets);
      expect(find.textContaining('360'), findsNothing);
    });

    testWidgets('selecting an option shows only that series', (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      expect(find.textContaining('360'), findsWidgets);
      expect(find.textContaining('130'), findsNothing);
    });

    testWidgets('the option series delta is 30, not a base-to-option jump',
        (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      expect(find.textContaining('30'), findsWidgets);
      expect(find.textContaining('230'), findsNothing);
    });

    testWidgets('the chart plots only the selected series', (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.first.spots;
      expect(spots.map((s) => s.y), [330, 360]);
    });
  });
}
```

The last case uses `fl_chart`, already imported by that file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/inventory/price_history_screen_test.dart`
Expected: FAIL — no selector exists, and the chart plots base and option prices in one series.

- [ ] **Step 3: Write minimal implementation**

Mobile: hold `selectedSeriesIndex` in screen state, render a horizontal chip row when `series.length > 1` (neutral chips, per the colour discipline — selection is state, not status), and pass `series[selected].entries` into `buildPriceHistoryRows` and the sparkline.

Web: same shape in `PriceHistoryView.tsx` with a segmented control or a `<select>`, matching the surrounding component style.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test && flutter analyze`, then from `web_admin/`: `npm run test && npm run typecheck && npm run build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/price_history_screen.dart web_admin/src/presentation/features/inventory/PriceHistoryView.tsx test/presentation/mobile/screens/inventory/price_history_screen_test.dart web_admin/src/presentation/features/inventory/PriceHistoryView.test.tsx
git commit -m "feat(inventory): series selector on the price-history views"
```

---

### Task 19: Option column on the price-change report

**Files:**
- Modify: `web_admin/src/domain/products/priceChangeReport.ts`
- Create: `web_admin/src/domain/products/priceChangeReport.test.ts`
- Modify: `web_admin/src/presentation/features/reports/PriceChangeReportPage.tsx`
- Modify: `web_admin/src/presentation/features/reports/PriceChangeReportPage.test.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (carry the option fields onto `PriceChangeEntry`)

**Interfaces:**
- Consumes: the `PriceHistoryEntry` option fields (Task 16); `PriceChangeEntry extends PriceHistoryEntry`, so it inherits them for free.
- Produces: `priceChangeRowsInRange` groups by `(productId, optionId)`; an **Option** column in the table and the CSV, blank for base rows.

`priceChangeRowsInRange` in `priceChangeReport.ts` groups by `productId` alone. With options that subtracts a By-6 set price from a base per-piece price and prints a swing that never happened.

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/products/priceChangeReport.test.ts
import { describe, expect, it } from 'vitest';
import { priceChangeRowsInRange, type PriceChangeEntry } from './priceChangeReport';

function entry(
  id: string,
  price: number,
  day: number,
  option?: { id: string; label: string; pieces: number },
): PriceChangeEntry {
  return {
    id,
    productId: 'p1',
    price,
    cost: 60,
    changedAt: new Date(`2026-07-0${day}T00:00:00Z`),
    changedBy: 'u1',
    reason: 'Price update',
    optionId: option?.id ?? null,
    optionLabel: option?.label ?? null,
    optionPieces: option?.pieces ?? null,
  };
}

const by3 = { id: 'o2', label: 'By 3', pieces: 3 };
const by6 = { id: 'o1', label: 'By 6', pieces: 6 };

describe('priceChangeRowsInRange with selling options', () => {
  it('computes an option delta against the same option only', () => {
    const rows = priceChangeRowsInRange([
      entry('e1', 330, 1, by3),
      entry('e2', 130, 2),
      entry('e3', 360, 3, by3),
    ]);
    const optionRow = rows.find((r) => r.entry.id === 'e3');
    expect(optionRow?.priceDelta).toBe(30);
    expect(optionRow?.hasPrior).toBe(true);
  });

  it('never subtracts an option price from a base price', () => {
    const rows = priceChangeRowsInRange([
      entry('e1', 120, 1),
      entry('e2', 330, 2, by3),
    ]);
    const optionRow = rows.find((r) => r.entry.id === 'e2');
    expect(optionRow?.priceDelta).toBe(0);
    expect(optionRow?.hasPrior).toBe(false);
  });

  it('computes a base delta ignoring option entries in between', () => {
    const rows = priceChangeRowsInRange([
      entry('e1', 120, 1),
      entry('e2', 330, 2, by3),
      entry('e3', 130, 3),
    ]);
    expect(rows.find((r) => r.entry.id === 'e3')?.priceDelta).toBe(10);
  });

  it('keeps two options of one product in separate groups', () => {
    const rows = priceChangeRowsInRange([
      entry('e1', 600, 1, by6),
      entry('e2', 330, 2, by3),
      entry('e3', 650, 3, by6),
    ]);
    expect(rows.find((r) => r.entry.id === 'e3')?.priceDelta).toBe(50);
    expect(rows.find((r) => r.entry.id === 'e2')?.hasPrior).toBe(false);
  });

  it('is unchanged for a product with no options', () => {
    const rows = priceChangeRowsInRange([entry('e1', 120, 1), entry('e2', 130, 2)]);
    expect(rows.map((r) => r.entry.id)).toEqual(['e2', 'e1']);
    expect(rows[0].priceDelta).toBe(10);
  });

  it('still returns rows newest-first across groups', () => {
    const rows = priceChangeRowsInRange([
      entry('e1', 120, 1),
      entry('e3', 360, 3, by3),
      entry('e2', 330, 2, by3),
    ]);
    expect(rows.map((r) => r.entry.id)).toEqual(['e3', 'e2', 'e1']);
  });
});
```

Add one case to the existing `PriceChangeReportPage.test.ts`, matching its `row()` fixture style:

```ts
it('puts the option label in the CSV and leaves it blank for base rows', () => {
  const optionRow = row({ optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 });
  expect(priceChangeCsvRow(optionRow, { name: 'Pulley Ball', sku: 'ABC-1' })).toContain('By 3');
  expect(priceChangeCsvRow(row(), { name: 'Pulley Ball', sku: 'ABC-1' })).toContain('');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- priceChangeReport`
Expected: FAIL — option entries are grouped with base entries, so `e2`'s delta is `210`, not `0`.

- [ ] **Step 3: Write minimal implementation**

In `priceChangeReport.ts`, change the grouping key only — the rest of the function is already correct:

```ts
  const byProduct = new Map<string, PriceChangeEntry[]>();
  for (const e of entries) {
    // Group by product AND option: a By-6 set price and the base per-piece
    // price are different series, and subtracting one from the other prints
    // a change that never happened.
    const key = `${e.productId}::${e.optionId ?? ''}`;
    const list = byProduct.get(key) ?? [];
    list.push(e);
    byProduct.set(key, list);
  }
```

`PriceChangeEntry extends PriceHistoryEntry`, so the option fields arrive with Task 16 — just confirm `FirestoreProductRepository.ts` reads them off the collection-group snapshot rather than dropping them. Then add the Option column to the table in `PriceChangeReportPage.tsx` and to `priceChangeCsvRow`, blank for base rows.

- [ ] **Step 4: Run test to verify it passes**

Run (from `web_admin/`): `npm run test && npm run typecheck && npm run build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/reports/PriceChangeReportPage.tsx web_admin/src/presentation/features/reports/PriceChangeReportPage.test.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(reports): option column on the price-change report"
```

---

## Final verification

- [ ] `flutter test` — full suite green
- [ ] `flutter analyze` — no issues
- [ ] From `web_admin/`: `npm run typecheck`, `npm run test`, `npm run build` — all green
- [ ] From `tools/firestore-rules-test/`: `npm test` — all green
- [ ] Run `/code-review` on the branch diff
- [ ] Ask the user before deploying `firestore.rules` — it is production-affecting
- [ ] Device smoke on the mobile side is the user's gate, per their standing preference

## Deliberate non-goals

Confirmed in the spec; do not build these:

- Reusable option templates shared across products
- Options in Receiving or Purchase Orders
- Per-option stock counts
- A "sold by option" analytics report
- Options on labor lines or shop fees
