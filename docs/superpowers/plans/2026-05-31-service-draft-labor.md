# POS Service-Draft Labor Lines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a cashier add mechanic labor charges to a service draft on top of parts, with labor reported as a separate revenue/profit track and never discounted.

**Architecture:** A new `LaborLineEntity` ({id, description, fee}) plus `mechanicId`/`mechanicName` are added to `CartState`, `DraftEntity`, and `SaleEntity`. `grandTotal` becomes `partsRevenue + laborRevenue` (reimplemented identically in DraftEntity, SaleEntity, DraftModel, SaleModel, CartState). Labor persists INLINE on draft and sale docs. Reporting keeps merchandise top-line parts-only and adds a parallel labor track; cash reconciliation includes labor. UI adds a labor section + mechanic picker to the cart and draft editor, with labor itemized on checkout/receipt/sale-detail.

**Tech Stack:** Flutter, Riverpod, cloud_firestore; tests use flutter_test + fake_cloud_firestore + mocktail; integration_test harness for the end-to-end flow.

**Spec:** docs/superpowers/specs/2026-05-30-pos-labor-mechanics-design.md

**Prerequisite:** Mechanics Admin List plan (provides `activeMechanicsProvider` for the picker). Execute that plan first.

---

## Corrections & canonical signatures — READ FIRST

This plan was drafted in parallel slices and checked by a critic. The items below resolve every cross-slice inconsistency it found. **Where a task below differs from these, follow these.**

### C1 · `MechanicPicker` — one canonical, presentation-only signature

Build the picker once (POS/checkout slice) with this exact signature and reuse it verbatim in the draft editor:

```dart
class MechanicPicker extends ConsumerWidget {
  const MechanicPicker({super.key, this.selectedMechanicId, required this.onChanged});
  final String? selectedMechanicId;
  final void Function(MechanicEntity? mechanic) onChanged; // null = "— None —"

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mechanicsAsync = ref.watch(activeMechanicsProvider);
    return mechanicsAsync.when(
      data: (mechanics) => DropdownButtonFormField<String?>(
        value: selectedMechanicId,
        decoration: const InputDecoration(
          labelText: 'Mechanic',
          prefixIcon: Icon(CupertinoIcons.wrench),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
          for (final m in mechanics)
            DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
        ],
        onChanged: (id) =>
            onChanged(id == null ? null : mechanics.firstWhere((m) => m.id == id)),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load mechanics: $e'),
    );
  }
}
```

- **Cart usage:** `MechanicPicker(selectedMechanicId: cart.mechanicId, onChanged: (m) => m == null ? notifier.clearMechanic() : notifier.setMechanic(m.id, m.name))`
- **Draft-editor usage:** the same widget, with `onChanged` wired to the editor's own handler.
- Any task showing `const MechanicPicker()` or `MechanicPicker(mechanicId:, onChanged:)` must use THIS signature (`find.byType(MechanicPicker)` in tests still works).

### C2 · Canonical test fixtures — paste into every test that needs them

```dart
ProductEntity _product({String id = 'p1', String sku = 'SKU-1', String name = 'Spark Plug', double price = 100, double cost = 60, int qty = 10}) =>
    ProductEntity(id: id, sku: sku, name: name, costCode: 'AAA', cost: cost, price: price,
        quantity: qty, reorderLevel: 0, unit: 'pcs', isActive: true, createdAt: DateTime(2026, 1, 1));

MechanicEntity _mechanic({String id = 'mech-1', String name = 'Juan Dela Cruz', bool isActive = true}) =>
    MechanicEntity(id: id, name: name, isActive: isActive, createdAt: DateTime(2026, 1, 1));
```

`ProductEntity` REQUIRES `costCode`, `reorderLevel`, `isActive`, `createdAt`; `MechanicEntity` REQUIRES `createdAt` (so a list of mechanics can NOT be `const`). Replace any fixture that omits these.

### C3 · Cart conversion calls take required args

- `cart.toSale(saleNumber: <n>, cashierId: <id>, cashierName: <name>)` — `saleNumber` is REQUIRED.
- `cart.toDraft(name: <name>, createdBy: <id>, createdByName: <name>)` — all three REQUIRED.

Update any integration/unit test that calls these with missing args.

### C4 · `cart_provider.dart` has ONE owner

All `CartState` fields/getters and `canCheckout`/`canSaveAsDraft` are defined once, in the **Cart layer** task. The POS/checkout "labor validation" must be folded into that same task (extend the getters there) — do not redefine them in a second task that overwrites the first. Execution order: Cart-layer task BEFORE the POS-UI tasks.

### C5 · Integration test calls the real `getSalesSummary`

The end-to-end test must invoke the real `SaleRepositoryImpl.getSalesSummary` against `FakeFirebaseFirestore` — do NOT hand-roll a `_summarize` copy (it can silently diverge from the real parts-only/labor logic).

### C6 · Barrel-edit ordering

Run the **Mechanics Admin List** plan before this one (both touch `entities.dart`/`models.dart`). Within this plan, the foundation tasks (LaborLineEntity/Model + barrels) run first.

---

<!-- slice: B-labor-foundation (Labor foundation: entity + model) -->

### Task 1: LaborLineEntity (domain entity + barrel export)

**Files:**
- Create: `lib/domain/entities/labor_line_entity.dart`
- Modify: `lib/domain/entities/entities.dart`
- Test: `test/domain/entities/labor_line_entity_test.dart`

- [ ] **Step 1: Write the failing test** — covers equality, `copyWith`, and the `fee` default.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('LaborLineEntity', () {
    late LaborLineEntity line;

    setUp(() {
      line = const LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
    });

    test('holds the constructor values', () {
      expect(line.id, 'labor-1');
      expect(line.description, 'Engine tune-up');
      expect(line.fee, 450.0);
    });

    test('fee defaults to 0 when omitted', () {
      const noFee = LaborLineEntity(id: 'labor-2', description: 'Diagnostics');
      expect(noFee.fee, 0);
    });

    test('value equality holds for identical field values', () {
      const same = LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
      expect(line, same);
      expect(line.hashCode, same.hashCode);
    });

    test('value equality fails when a field differs', () {
      const differentFee = LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 500.0,
      );
      expect(line == differentFee, isFalse);
    });

    test('copyWith overrides only the supplied fields', () {
      final updated = line.copyWith(description: 'Brake bleed', fee: 200.0);
      expect(updated.id, 'labor-1'); // unchanged
      expect(updated.description, 'Brake bleed');
      expect(updated.fee, 200.0);
    });

    test('copyWith with no args returns an equal instance', () {
      expect(line.copyWith(), line);
    });

    test('props expose id, description, fee', () {
      expect(line.props, ['labor-1', 'Engine tune-up', 450.0]);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/entities/labor_line_entity_test.dart`. Expected failure: compile error / `Undefined name 'LaborLineEntity'` because the entity does not exist yet.

- [ ] **Step 3: Implement** the entity.

```dart
import 'package:equatable/equatable.dart';

/// A single free-form labor/service charge on a draft, sale, or cart.
///
/// Labor is full price and is **never discounted** — it lives on a different
/// code path from item discounts (see spec decision #4). There is no cost
/// field: labor cost is always zero (pure margin).
class LaborLineEntity extends Equatable {
  /// Unique identifier for this labor line (uuid, like cart items).
  final String id;

  /// What was done, e.g. "Engine tune-up", "Brake bleed".
  final String description;

  /// Peso amount charged for this labor line. Full price, never discounted.
  final double fee;

  const LaborLineEntity({
    required this.id,
    required this.description,
    this.fee = 0,
  });

  LaborLineEntity copyWith({
    String? id,
    String? description,
    double? fee,
  }) {
    return LaborLineEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      fee: fee ?? this.fee,
    );
  }

  @override
  List<Object?> get props => [id, description, fee];

  @override
  String toString() {
    return 'LaborLineEntity(id: $id, description: $description, fee: $fee)';
  }
}
```

Add the export to `lib/domain/entities/entities.dart` (insert after the `sale_item_entity.dart` export line):

```dart
export 'sale_item_entity.dart';
export 'labor_line_entity.dart';
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/entities/labor_line_entity_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/domain/entities/labor_line_entity.dart lib/domain/entities/entities.dart test/domain/entities/labor_line_entity_test.dart && git commit -m "feat(labor): add LaborLineEntity + barrel export"`

---

### Task 2: LaborLineModel (Firestore model + barrel export)

**Files:**
- Create: `lib/data/models/labor_line_model.dart`
- Modify: `lib/data/models/models.dart`
- Test: `test/data/models/labor_line_model_test.dart`

- [ ] **Step 1: Write the failing test** — round-trips `fromMap`/`toMap`/`toEntity`/`fromEntity` and asserts `toMap` omits `id` unless `includeId: true`, mirroring `SaleItemModel`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('LaborLineModel', () {
    late LaborLineModel model;

    setUp(() {
      model = const LaborLineModel(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
    });

    test('fromMap reads description and fee, id comes from documentId', () {
      final m = LaborLineModel.fromMap(
        {'description': 'Brake bleed', 'fee': 200.0},
        'labor-9',
      );
      expect(m.id, 'labor-9');
      expect(m.description, 'Brake bleed');
      expect(m.fee, 200.0);
    });

    test('fromMap defaults are safe for legacy/partial docs', () {
      final m = LaborLineModel.fromMap(<String, dynamic>{}, 'labor-x');
      expect(m.id, 'labor-x');
      expect(m.description, '');
      expect(m.fee, 0.0);
    });

    test('fromMap coerces an int fee to double', () {
      final m = LaborLineModel.fromMap(
        {'description': 'Oil change', 'fee': 300},
        'labor-int',
      );
      expect(m.fee, 300.0);
    });

    test('toMap omits id by default', () {
      final map = model.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map['description'], 'Engine tune-up');
      expect(map['fee'], 450.0);
    });

    test('toMap includes id when includeId is true', () {
      final map = model.toMap(includeId: true);
      expect(map['id'], 'labor-1');
      expect(map['description'], 'Engine tune-up');
      expect(map['fee'], 450.0);
    });

    test('toEntity maps all fields', () {
      final entity = model.toEntity();
      expect(entity, isA<LaborLineEntity>());
      expect(entity.id, 'labor-1');
      expect(entity.description, 'Engine tune-up');
      expect(entity.fee, 450.0);
    });

    test('fromEntity maps all fields', () {
      const entity = LaborLineEntity(
        id: 'labor-2',
        description: 'Chain adjust',
        fee: 150.0,
      );
      final m = LaborLineModel.fromEntity(entity);
      expect(m.id, 'labor-2');
      expect(m.description, 'Chain adjust');
      expect(m.fee, 150.0);
    });

    test('round-trips entity -> model -> map(includeId) -> model -> entity', () {
      const entity = LaborLineEntity(
        id: 'labor-3',
        description: 'Carb clean',
        fee: 320.0,
      );
      final map = LaborLineModel.fromEntity(entity).toMap(includeId: true);
      final restored =
          LaborLineModel.fromMap(map, map['id'] as String).toEntity();
      expect(restored, entity);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/models/labor_line_model_test.dart`. Expected failure: compile error / `Undefined name 'LaborLineModel'` because the model does not exist yet.

- [ ] **Step 3: Implement** the model (mirrors `SaleItemModel`: `id` from `documentId`, `toMap` emits `description`/`fee` and only adds `id` when `includeId`).

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for a labor line with Firestore serialization.
///
/// Labor lines are stored **inline** inside the parent draft/sale document's
/// `laborLines` array (see spec §4.1), so [toMap] is called with
/// `includeId: true` to keep the line's id inside the array element. Mirrors
/// [SaleItemModel] for serialization shape.
class LaborLineModel {
  final String id;
  final String description;
  final double fee;

  const LaborLineModel({
    required this.id,
    required this.description,
    this.fee = 0,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (an element of the inline `laborLines` array).
  ///
  /// Defaults [description] to `''` and [fee] to `0` so legacy / partial docs
  /// deserialize without throwing.
  factory LaborLineModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LaborLineModel(
      id: documentId,
      description: map['description'] as String? ?? '',
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Creates from a Firestore document (when stored as a standalone doc).
  factory LaborLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return LaborLineModel.fromMap(doc.data()!, doc.id);
  }

  /// Converts to a Map for Firestore.
  ///
  /// Emits `description` and `fee`; includes `id` only when [includeId] is true
  /// (set when serializing inline inside the parent's `laborLines` array).
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'description': description,
      'fee': fee,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  LaborLineEntity toEntity() {
    return LaborLineEntity(
      id: id,
      description: description,
      fee: fee,
    );
  }

  /// Creates from domain entity.
  factory LaborLineModel.fromEntity(LaborLineEntity entity) {
    return LaborLineModel(
      id: entity.id,
      description: entity.description,
      fee: entity.fee,
    );
  }

  // ==================== COPY WITH ====================

  LaborLineModel copyWith({
    String? id,
    String? description,
    double? fee,
  }) {
    return LaborLineModel(
      id: id ?? this.id,
      description: description ?? this.description,
      fee: fee ?? this.fee,
    );
  }

  @override
  String toString() {
    return 'LaborLineModel(id: $id, description: $description, fee: $fee)';
  }
}
```

Add the export to `lib/data/models/models.dart` (insert after the `sale_item_model.dart` export line):

```dart
export 'sale_item_model.dart';
export 'labor_line_model.dart';
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/models/labor_line_model_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/data/models/labor_line_model.dart lib/data/models/models.dart test/data/models/labor_line_model_test.dart && git commit -m "feat(labor): add LaborLineModel + barrel export"`



<!-- slice: C-domain-math (Domain money math: DraftEntity + SaleEntity) -->

### Task 3: DraftEntity: labor lines, mechanic fields, and money-math getters

**Files:**
- Modify: `lib/domain/entities/draft_entity.dart`
- Test: `test/domain/entities/draft_entity_test.dart`

> Depends on `LaborLineEntity` (`lib/domain/entities/labor_line_entity.dart`) and its barrel export in `lib/domain/entities/entities.dart`, both delivered by the Foundation slice.

- [ ] **Step 1: Write the failing test** — append a new `group` to `test/domain/entities/draft_entity_test.dart` (keep the existing `group('DraftEntity', …)` untouched; the existing tests don't assert any money totals so they stay green):

```dart
  group('DraftEntity labor + money math', () {
    late DraftEntity draft;

    setUp(() {
      draft = DraftEntity(
        id: 'draft-1',
        name: 'Bike repair',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
            discountValue: 10.0, // 10 peso off (amount type)
          ),
        ],
        discountType: DiscountType.amount,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    });

    test('laborLines defaults to empty and mechanic fields default to null', () {
      expect(draft.laborLines, isEmpty);
      expect(draft.mechanicId, isNull);
      expect(draft.mechanicName, isNull);
    });

    test('parts getters with no labor', () {
      // subtotal: 100 * 2 = 200; discount: 10
      expect(draft.partsSubtotal, 200.0);
      expect(draft.laborSubtotal, 0.0);
      expect(draft.partsRevenue, 190.0); // 200 - 10
      expect(draft.laborRevenue, 0.0);
      expect(draft.grandTotal, 190.0); // partsRevenue + laborRevenue
      // cost: 60 * 2 = 120
      expect(draft.totalCost, 120.0);
      expect(draft.partsProfit, 70.0); // 190 - 120
      expect(draft.laborProfit, 0.0);
      expect(draft.totalProfit, 70.0);
    });

    test('addLaborLine adds a labor line and feeds laborSubtotal', () {
      final updated = draft.addLaborLine(
        const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
      );
      expect(updated.laborLines.length, 1);
      expect(updated.laborSubtotal, 300.0);
      // Original is unchanged (immutability).
      expect(draft.laborLines, isEmpty);
    });

    test('labor lines raise revenue/profit/grandTotal but not parts/discount/cost',
        () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .addLaborLine(
            const LaborLineEntity(id: 'lab-2', description: 'Bleed', fee: 150.0),
          );

      // Labor does NOT touch parts-only figures.
      expect(updated.partsSubtotal, 200.0);
      expect(updated.totalDiscount, 10.0);
      expect(updated.totalCost, 120.0);
      expect(updated.partsRevenue, 190.0);
      expect(updated.partsProfit, 70.0);

      // Labor track.
      expect(updated.laborSubtotal, 450.0);
      expect(updated.laborRevenue, 450.0);
      expect(updated.laborProfit, 450.0); // zero labor cost

      // Combined.
      expect(updated.grandTotal, 640.0); // 190 + 450
      expect(updated.totalProfit, 520.0); // 70 + 450
    });

    test('updateLaborLine replaces a matching line by id', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .updateLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 500.0),
          );
      expect(updated.laborLines.single.fee, 500.0);
      expect(updated.laborSubtotal, 500.0);
    });

    test('updateLaborLine on a missing id is a no-op', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .updateLaborLine(
            const LaborLineEntity(id: 'nope', description: 'X', fee: 999.0),
          );
      expect(updated.laborLines.single.fee, 300.0);
    });

    test('removeLaborLine drops the matching line', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .addLaborLine(
            const LaborLineEntity(id: 'lab-2', description: 'Bleed', fee: 150.0),
          )
          .removeLaborLine('lab-1');
      expect(updated.laborLines.single.id, 'lab-2');
      expect(updated.laborSubtotal, 150.0);
    });

    test('copyWith sets and clears mechanic fields', () {
      final assigned =
          draft.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan Dela Cruz');
      expect(assigned.mechanicId, 'mech-1');
      expect(assigned.mechanicName, 'Juan Dela Cruz');

      final cleared = assigned.copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
    });

    test('props include laborLines and mechanic fields', () {
      final a = draft.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan');
      final b = draft.copyWith(mechanicId: 'mech-2', mechanicName: 'Pedro');
      expect(a == b, false);

      final withLabor = draft.addLaborLine(
        const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
      );
      expect(withLabor == draft, false);
    });
  });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/entities/draft_entity_test.dart`. Expected: compile errors / failures on `partsSubtotal`, `laborSubtotal`, `partsRevenue`, `laborRevenue`, `partsProfit`, `laborProfit`, `totalProfit`, `addLaborLine`, `updateLaborLine`, `removeLaborLine`, `laborLines`, `mechanicId`, `mechanicName`, and the `clearMechanic` copyWith flag — none exist yet on `DraftEntity`.

- [ ] **Step 3: Implement** — edit `lib/domain/entities/draft_entity.dart`. Add the import, three new fields, the getters, the labor helpers, the copyWith params/flag, and props entries.

Add the import after the existing `sale_item_entity.dart` import (line 3):

```dart
import 'package:maki_mobile_pos/domain/entities/labor_line_entity.dart';
```

Add the three fields to the field block (after `items`, around line 27):

```dart
  /// Line items in this draft
  final List<SaleItemEntity> items;

  /// Free-form labor/service lines (full price, never discounted)
  final List<LaborLineEntity> laborLines;

  /// Mechanic assigned to this job (one per ticket); null until assigned
  final String? mechanicId;

  /// Mechanic display name (snapshot, like createdByName)
  final String? mechanicName;
```

Add them to the constructor (after `required this.items,`):

```dart
  const DraftEntity({
    required this.id,
    required this.name,
    required this.items,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.discountType = DiscountType.amount,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.isConverted = false,
    this.convertedToSaleId,
    this.convertedAt,
    this.notes,
  });
```

Replace the existing `grandTotal` getter (line 104) and add the new money-math getters right after it:

```dart
  // ==================== MONEY MATH ====================

  /// Parts gross before discount (items only). Alias of [subtotal].
  double get partsSubtotal => subtotal;

  /// Sum of all labor fees (full price, never discounted).
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Net merchandise revenue (parts gross minus item discounts).
  double get partsRevenue => partsSubtotal - totalDiscount;

  /// Labor revenue (pure margin — zero cost).
  double get laborRevenue => laborSubtotal;

  /// Grand total after discounts, including labor.
  double get grandTotal => partsRevenue + laborRevenue;

  /// Merchandise profit (parts revenue minus parts cost).
  double get partsProfit => partsRevenue - totalCost;

  /// Labor profit (labor has zero cost).
  double get laborProfit => laborRevenue;

  /// True per-transaction profit (parts + labor).
  double get totalProfit => partsProfit + laborProfit;
```

Add the labor helpers after `clearItems()` (after line 212), mirroring the item helpers:

```dart
  // ==================== LABOR MANAGEMENT ====================

  /// Adds a labor line to the draft (returns new instance)
  DraftEntity addLaborLine(LaborLineEntity line) {
    return copyWith(
      laborLines: [...laborLines, line],
      updatedAt: DateTime.now(),
    );
  }

  /// Updates a labor line by id (returns new instance; no-op if not found)
  DraftEntity updateLaborLine(LaborLineEntity line) {
    final index = laborLines.indexWhere((l) => l.id == line.id);
    if (index < 0) return this;

    final updated = List<LaborLineEntity>.from(laborLines);
    updated[index] = line;
    return copyWith(laborLines: updated, updatedAt: DateTime.now());
  }

  /// Removes a labor line by id (returns new instance)
  DraftEntity removeLaborLine(String lineId) {
    return copyWith(
      laborLines: laborLines.where((l) => l.id != lineId).toList(),
      updatedAt: DateTime.now(),
    );
  }
```

Update `copyWith` — add the three params plus a `clearMechanic` flag, and wire them in the returned `DraftEntity`:

```dart
  DraftEntity copyWith({
    String? id,
    String? name,
    List<SaleItemEntity>? items,
    List<LaborLineEntity>? laborLines,
    String? mechanicId,
    String? mechanicName,
    DiscountType? discountType,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isConverted,
    String? convertedToSaleId,
    DateTime? convertedAt,
    String? notes,
    // Clear flags
    bool clearNotes = false,
    bool clearConversionInfo = false,
    bool clearMechanic = false,
  }) {
    return DraftEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      discountType: discountType ?? this.discountType,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isConverted: isConverted ?? this.isConverted,
      convertedToSaleId: clearConversionInfo
          ? null
          : (convertedToSaleId ?? this.convertedToSaleId),
      convertedAt:
          clearConversionInfo ? null : (convertedAt ?? this.convertedAt),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
```

Update `props` — add the three fields after `items`:

```dart
  @override
  List<Object?> get props => [
        id,
        name,
        items,
        laborLines,
        mechanicId,
        mechanicName,
        discountType,
        createdBy,
        createdByName,
        createdAt,
        updatedAt,
        updatedBy,
        isConverted,
        convertedToSaleId,
        convertedAt,
        notes,
      ];
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/entities/draft_entity_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/domain/entities/draft_entity.dart test/domain/entities/draft_entity_test.dart && git commit -m "feat(domain): labor lines + mechanic + money-math getters on DraftEntity"`

---

### Task 4: SaleEntity: labor lines, mechanic fields, and money-math getters

**Files:**
- Modify: `lib/domain/entities/sale_entity.dart`
- Test: `test/domain/entities/sale_entity_test.dart` (update the two breaking expectations + add new coverage)
- Test: `test/domain/entities/sale_entity_tenders_test.dart` (verify-only — labor stays empty, so `grandTotal` unchanged)

> The `tenders` test fixtures never add labor, so `grandTotal` stays `1000` there — they must remain green untouched. Run them in Step 4 as a regression guard.

- [ ] **Step 1: Write the failing test** — in `test/domain/entities/sale_entity_test.dart`, update the two existing expectations that change by design, and append a new labor group.

Update `totalProfit calculates correctly` (currently expects `125.0`; with the contract, `totalProfit = partsProfit + laborProfit`, and with no labor that is still `335 - 210 = 125`, so this assertion is unchanged — but make its comment match the new definition):

```dart
    test('totalProfit calculates correctly', () {
      // No labor: totalProfit == partsProfit == partsRevenue - totalCost
      // = (350 - 15) - 210 = 125
      expect(sale.totalProfit, 125.0);
    });
```

Append the new group (after the existing tests, before the closing `});` of `group('SaleEntity', …)`):

```dart
    test('parts getters with no labor', () {
      expect(sale.partsSubtotal, 350.0);
      expect(sale.laborSubtotal, 0.0);
      expect(sale.partsRevenue, 335.0); // 350 - 15
      expect(sale.laborRevenue, 0.0);
      expect(sale.grandTotal, 335.0);
      expect(sale.partsProfit, 125.0); // 335 - 210
      expect(sale.laborProfit, 0.0);
      expect(sale.totalProfit, 125.0);
    });

    test('labor raises revenue/profit/grandTotal but not parts/discount/cost', () {
      final withLabor = sale.copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          LaborLineEntity(id: 'lab-2', description: 'Bleed', fee: 150.0),
        ],
      );

      // Parts-only figures are untouched by labor.
      expect(withLabor.partsSubtotal, 350.0);
      expect(withLabor.totalDiscount, 15.0);
      expect(withLabor.totalCost, 210.0);
      expect(withLabor.partsRevenue, 335.0);
      expect(withLabor.partsProfit, 125.0);

      // Labor track.
      expect(withLabor.laborSubtotal, 450.0);
      expect(withLabor.laborRevenue, 450.0);
      expect(withLabor.laborProfit, 450.0);

      // Combined.
      expect(withLabor.grandTotal, 785.0); // 335 + 450
      expect(withLabor.totalProfit, 575.0); // 125 + 450
    });

    test('labor fields default to empty/null and copyWith clears mechanic', () {
      expect(sale.laborLines, isEmpty);
      expect(sale.mechanicId, isNull);
      expect(sale.mechanicName, isNull);

      final assigned =
          sale.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan Dela Cruz');
      expect(assigned.mechanicId, 'mech-1');
      expect(assigned.mechanicName, 'Juan Dela Cruz');

      final cleared = assigned.copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
    });

    test('effectiveTenders falls back to labor-inclusive grandTotal', () {
      // Legacy fallback attributes the whole (labor-inclusive) grandTotal.
      final withLabor = sale.copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
        ],
      );
      // grandTotal = 335 + 300 = 635
      expect(withLabor.effectiveTenders, {PaymentMethod.cash: 635.0});
    });

    test('props include laborLines and mechanic fields', () {
      final a = sale.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan');
      final b = sale.copyWith(mechanicId: 'mech-2', mechanicName: 'Pedro');
      expect(a == b, false);

      final withLabor = sale.copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
        ],
      );
      expect(withLabor == sale, false);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/entities/sale_entity_test.dart`. Expected: compile errors on `partsSubtotal`, `laborSubtotal`, `partsRevenue`, `laborRevenue`, `partsProfit`, `laborProfit`, `laborLines`, `mechanicId`, `mechanicName`, and the `clearMechanic`/`laborLines` copyWith params — none exist yet on `SaleEntity`.

- [ ] **Step 3: Implement** — edit `lib/domain/entities/sale_entity.dart`.

Add the import after `sale_item_entity.dart` (line 3):

```dart
import 'package:maki_mobile_pos/domain/entities/labor_line_entity.dart';
```

Add the three fields after `items` (around line 25):

```dart
  /// Line items in this sale
  final List<SaleItemEntity> items;

  /// Free-form labor/service lines (full price, never discounted).
  /// Stored INLINE on the sale doc (not in the items subcollection).
  final List<LaborLineEntity> laborLines;

  /// Mechanic assigned to this job (one per ticket); null when none.
  final String? mechanicId;

  /// Mechanic display name (snapshot, like cashierName).
  final String? mechanicName;
```

Add them to the constructor (after `required this.items,`):

```dart
  const SaleEntity({
    required this.id,
    required this.saleNumber,
    required this.items,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.discountType = DiscountType.amount,
    required this.paymentMethod,
    this.tenders = const {},
    required this.amountReceived,
    required this.changeGiven,
    this.status = SaleStatus.completed,
    required this.cashierId,
    required this.cashierName,
    required this.createdAt,
    this.updatedAt,
    this.draftId,
    this.notes,
    this.voidedAt,
    this.voidedBy,
    this.voidedByName,
    this.voidReason,
  });
```

Replace the existing `grandTotal` getter (line 130) with the labor-aware getters. The `effectiveTenders`/`cashCollected`/`salmonBalance`/`isTenderValid` block (lines 132–147) stays unchanged — it already reads `grandTotal`, which now includes labor:

```dart
  /// Parts gross before discount (items only). Alias of [subtotal].
  double get partsSubtotal => subtotal;

  /// Sum of all labor fees (full price, never discounted).
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Net merchandise revenue (parts gross minus item discounts).
  double get partsRevenue => partsSubtotal - totalDiscount;

  /// Labor revenue (pure margin — zero cost).
  double get laborRevenue => laborSubtotal;

  /// Grand total after discounts, including labor.
  double get grandTotal => partsRevenue + laborRevenue;
```

Replace the existing `totalProfit` getter (line 155) with the parts/labor split (leave `totalCost` at line 150 and `profitMargin` at line 158 unchanged — `profitMargin` keeps dividing the combined profit by the combined grandTotal, which is acceptable here):

```dart
  /// Merchandise profit (parts revenue minus parts cost).
  double get partsProfit => partsRevenue - totalCost;

  /// Labor profit (labor has zero cost).
  double get laborProfit => laborRevenue;

  /// Total profit from this sale (parts + labor).
  double get totalProfit => partsProfit + laborProfit;
```

Update `copyWith` — add params + `clearMechanic` flag and wire them in:

```dart
  SaleEntity copyWith({
    String? id,
    String? saleNumber,
    List<SaleItemEntity>? items,
    List<LaborLineEntity>? laborLines,
    String? mechanicId,
    String? mechanicName,
    DiscountType? discountType,
    PaymentMethod? paymentMethod,
    Map<PaymentMethod, double>? tenders,
    double? amountReceived,
    double? changeGiven,
    SaleStatus? status,
    String? cashierId,
    String? cashierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? draftId,
    String? notes,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidedByName,
    String? voidReason,
    // Clear flags for nullable fields
    bool clearDraftId = false,
    bool clearNotes = false,
    bool clearVoidInfo = false,
    bool clearMechanic = false,
  }) {
    return SaleEntity(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenders: tenders ?? this.tenders,
      amountReceived: amountReceived ?? this.amountReceived,
      changeGiven: changeGiven ?? this.changeGiven,
      status: status ?? this.status,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftId: clearDraftId ? null : (draftId ?? this.draftId),
      notes: clearNotes ? null : (notes ?? this.notes),
      voidedAt: clearVoidInfo ? null : (voidedAt ?? this.voidedAt),
      voidedBy: clearVoidInfo ? null : (voidedBy ?? this.voidedBy),
      voidedByName: clearVoidInfo ? null : (voidedByName ?? this.voidedByName),
      voidReason: clearVoidInfo ? null : (voidReason ?? this.voidReason),
    );
  }
```

Update `props` — add the three fields after `items`:

```dart
  @override
  List<Object?> get props => [
        id,
        saleNumber,
        items,
        laborLines,
        mechanicId,
        mechanicName,
        discountType,
        paymentMethod,
        tenders,
        amountReceived,
        changeGiven,
        status,
        cashierId,
        cashierName,
        createdAt,
        updatedAt,
        draftId,
        notes,
        voidedAt,
        voidedBy,
        voidedByName,
        voidReason,
      ];
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/entities/sale_entity_test.dart test/domain/entities/sale_entity_tenders_test.dart`. Both files must pass (the tenders file is the labor-empty regression guard — its `grandTotal == 1000` assertions stay valid since no labor is added).

- [ ] **Step 5: Commit** — `git add lib/domain/entities/sale_entity.dart test/domain/entities/sale_entity_test.dart && git commit -m "feat(domain): labor lines + mechanic + money-math getters on SaleEntity"`



<!-- slice: D-data-models (Data models + sale repository persistence) -->

### Task 5: Add labor + mechanic fields and `laborSubtotal`/`grandTotal` to `DraftModel`

**Files:**
- Modify: `lib/data/models/draft_model.dart`
- Test: `test/data/models/draft_model_test.dart`

This task assumes Plan 1 has already landed `LaborLineEntity` (exported via `lib/domain/entities/entities.dart`), `LaborLineModel` (exported via `lib/data/models/models.dart`), and the `laborLines`/`mechanicId`/`mechanicName` fields + `clearMechanic` flag + money-math getters on `DraftEntity`.

- [ ] **Step 1: Write the failing test** — create `test/data/models/draft_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/draft_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  const item = SaleItemModel(
    id: 'item-1',
    productId: 'prod-1',
    sku: 'SKU-001',
    name: 'Spark Plug',
    unitPrice: 100.0,
    unitCost: 60.0,
    quantity: 2,
  );

  const labor = LaborLineModel(
    id: 'labor-1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  DraftModel buildModel() => DraftModel(
        id: 'draft-1',
        name: 'Service Job',
        items: const [item],
        laborLines: const [labor],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  group('DraftModel labor + mechanic', () {
    test('laborSubtotal sums labor fees; grandTotal adds labor to net parts',
        () {
      final model = buildModel();
      expect(model.laborSubtotal, 450.0);
      // parts: 100*2 = 200, no discount; +450 labor
      expect(model.grandTotal, 650.0);
    });

    test('toMap emits inline laborLines + mechanic fields', () {
      final map = buildModel().toMap();
      final laborMaps = map['laborLines'] as List<dynamic>;
      expect(laborMaps.length, 1);
      final l = laborMaps.first as Map<String, dynamic>;
      expect(l['id'], 'labor-1');
      expect(l['description'], 'Engine tune-up');
      expect(l['fee'], 450.0);
      expect(map['mechanicId'], 'mech-1');
      expect(map['mechanicName'], 'Juan Dela Cruz');
    });

    test('fromMap parses laborLines array + mechanic fields', () {
      final model = DraftModel.fromMap({
        'name': 'Service Job',
        'items': [item.toMap(includeId: true)],
        'laborLines': [labor.toMap(includeId: true)],
        'mechanicId': 'mech-1',
        'mechanicName': 'Juan Dela Cruz',
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-1');

      expect(model.laborLines.length, 1);
      expect(model.laborLines.first.description, 'Engine tune-up');
      expect(model.laborLines.first.fee, 450.0);
      expect(model.mechanicId, 'mech-1');
      expect(model.mechanicName, 'Juan Dela Cruz');
    });

    test('fromMap defaults labor to [] and mechanic to null for legacy docs',
        () {
      final model = DraftModel.fromMap({
        'name': 'Legacy Draft',
        'items': [item.toMap(includeId: true)],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-legacy');

      expect(model.laborLines, isEmpty);
      expect(model.mechanicId, isNull);
      expect(model.mechanicName, isNull);
    });

    test('toEntity / fromEntity round-trips labor + mechanic', () {
      final entity = buildModel().toEntity();
      expect(entity.laborLines.single.description, 'Engine tune-up');
      expect(entity.mechanicId, 'mech-1');
      expect(entity.mechanicName, 'Juan Dela Cruz');

      final back = DraftModel.fromEntity(entity);
      expect(back.laborLines.single.fee, 450.0);
      expect(back.mechanicId, 'mech-1');
      expect(back.mechanicName, 'Juan Dela Cruz');
    });

    test('copyWith clearMechanic nulls mechanic fields', () {
      final cleared = buildModel().copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
      // labor untouched
      expect(cleared.laborLines.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/models/draft_model_test.dart`. Expect compile errors: `DraftModel` has no named param `laborLines`/`mechanicId`/`mechanicName`, no `laborSubtotal` getter, and `copyWith` has no `clearMechanic`.

- [ ] **Step 3: Implement** — edit `lib/data/models/draft_model.dart`. Add the import, three fields + constructor params, `fromMap` parsing, `toMap` emission, `toEntity`/`fromEntity`, the `laborSubtotal` getter, updated `grandTotal`, `copyWith`, and `create`.

Add the import near the top (after the `sale_item_model.dart` import):

```dart
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
```

Add the three fields after `final List<SaleItemModel> items;`:

```dart
  final List<SaleItemModel> items;
  final List<LaborLineModel> laborLines;
  final String? mechanicId;
  final String? mechanicName;
```

Add the constructor params after `required this.items,`:

```dart
    required this.items,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
```

In `fromMap`, after the existing `items` parse loop (right before `return DraftModel(`), add the labor parse loop:

```dart
    // Parse labor lines array (inline, like items). Legacy docs -> [].
    final laborList = <LaborLineModel>[];
    final laborData = map['laborLines'] as List<dynamic>? ?? [];
    for (int i = 0; i < laborData.length; i++) {
      final laborMap = laborData[i] as Map<String, dynamic>;
      final laborId = laborMap['id'] as String? ?? 'labor-$i';
      laborList.add(LaborLineModel.fromMap(laborMap, laborId));
    }

    return DraftModel(
      id: documentId,
      name: map['name'] as String? ?? 'Unnamed Draft',
      items: itemsList,
      laborLines: laborList,
      mechanicId: map['mechanicId'] as String?,
      mechanicName: map['mechanicName'] as String?,
      discountType: DiscountType.fromString(map['discountType'] as String?),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
      isConverted: map['isConverted'] as bool? ?? false,
      convertedToSaleId: map['convertedToSaleId'] as String?,
      convertedAt: _parseTimestamp(map['convertedAt']),
      notes: map['notes'] as String?,
    );
```

In `toMap`, add labor + mechanic to the inline map literal (after the `'items': ...` line):

```dart
    final map = <String, dynamic>{
      'name': name,
      'items': items.map((item) => item.toMap(includeId: true)).toList(),
      'laborLines':
          laborLines.map((l) => l.toMap(includeId: true)).toList(),
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'discountType': discountType.value,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isConverted': isConverted,
      'convertedToSaleId': convertedToSaleId,
      'notes': notes,
    };
```

In `toEntity`, add the three fields (after `items: ...`):

```dart
      items: items.map((item) => item.toEntity()).toList(),
      laborLines: laborLines.map((l) => l.toEntity()).toList(),
      mechanicId: mechanicId,
      mechanicName: mechanicName,
```

In `fromEntity`, add the three fields (after the `items:` mapping):

```dart
      items:
          entity.items.map((item) => SaleItemModel.fromEntity(item)).toList(),
      laborLines: entity.laborLines
          .map((l) => LaborLineModel.fromEntity(l))
          .toList(),
      mechanicId: entity.mechanicId,
      mechanicName: entity.mechanicName,
```

Add `laborSubtotal` and update `grandTotal` (replace the existing `grandTotal` getter):

```dart
  /// Labor subtotal (sum of labor fees; never discounted)
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Grand total: net parts (after discount) + labor
  double get grandTotal => (subtotal - totalDiscount) + laborSubtotal;
```

Update `copyWith` — add the three params + a `clearMechanic` flag, and the body:

```dart
  DraftModel copyWith({
    String? id,
    String? name,
    List<SaleItemModel>? items,
    List<LaborLineModel>? laborLines,
    String? mechanicId,
    String? mechanicName,
    DiscountType? discountType,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isConverted,
    String? convertedToSaleId,
    DateTime? convertedAt,
    String? notes,
    bool clearMechanic = false,
  }) {
    return DraftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName:
          clearMechanic ? null : (mechanicName ?? this.mechanicName),
      discountType: discountType ?? this.discountType,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isConverted: isConverted ?? this.isConverted,
      convertedToSaleId: convertedToSaleId ?? this.convertedToSaleId,
      convertedAt: convertedAt ?? this.convertedAt,
      notes: notes ?? this.notes,
    );
  }
```

Update the `create` factory to accept and pass labor + mechanic (add params after `items` and pass them through):

```dart
  factory DraftModel.create({
    required String name,
    required List<SaleItemModel> items,
    List<LaborLineModel> laborLines = const [],
    String? mechanicId,
    String? mechanicName,
    DiscountType discountType = DiscountType.amount,
    required String createdBy,
    required String createdByName,
    String? notes,
  }) {
    return DraftModel(
      id: '', // Will be set by Firestore
      name: name,
      items: items,
      laborLines: laborLines,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      discountType: discountType,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }
```

(`DraftModel.empty` needs no change — `laborLines` defaults to `const []` and mechanic fields to `null`.)

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/models/draft_model_test.dart`

- [ ] **Step 5: Commit** — `git add lib/data/models/draft_model.dart test/data/models/draft_model_test.dart && git commit -m "feat(data): add labor lines + mechanic to DraftModel with inline serialization"`

---

### Task 6: Add labor + mechanic fields and `laborSubtotal`/`grandTotal` to `SaleModel` (inline, not via items subcollection)

**Files:**
- Modify: `lib/data/models/sale_model.dart`
- Test: `test/data/models/sale_model_test.dart`

The critical constraint: `SaleModel.fromMap` reads `map['laborLines']` **directly** off the doc map — labor must NOT flow through the `items:` subcollection parameter.

- [ ] **Step 1: Write the failing test** — create `test/data/models/sale_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/sale_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  const item = SaleItemModel(
    id: 'item-1',
    productId: 'prod-1',
    sku: 'SKU-001',
    name: 'Spark Plug',
    unitPrice: 100.0,
    unitCost: 60.0,
    quantity: 2,
  );

  const labor = LaborLineModel(
    id: 'labor-1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  SaleModel buildModel() => SaleModel(
        id: 'sale-1',
        saleNumber: 'SALE-20260530-001',
        items: const [item],
        laborLines: const [labor],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  group('SaleModel labor + mechanic', () {
    test('laborSubtotal sums fees; grandTotal adds labor to net parts', () {
      final model = buildModel();
      expect(model.laborSubtotal, 450.0);
      expect(model.grandTotal, 650.0); // 200 parts + 450 labor
    });

    test('toMap emits inline laborLines + mechanic fields', () {
      final map = buildModel().toMap();
      final laborMaps = map['laborLines'] as List<dynamic>;
      expect(laborMaps.length, 1);
      expect((laborMaps.first as Map<String, dynamic>)['fee'], 450.0);
      expect(map['mechanicId'], 'mech-1');
      expect(map['mechanicName'], 'Juan Dela Cruz');
    });

    test('fromMap parses laborLines DIRECTLY off the map, not via items param',
        () {
      // items come from the subcollection param; labor must come from the map
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-20260530-001',
          'laborLines': [labor.toMap(includeId: true)],
          'mechanicId': 'mech-1',
          'mechanicName': 'Juan Dela Cruz',
          'discountType': 'amount',
          'paymentMethod': 'cash',
          'amountReceived': 650.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'cashier-1',
          'cashierName': 'John Doe',
        },
        'sale-1',
        items: const [item], // subcollection items only
      );

      expect(model.items.length, 1);
      expect(model.laborLines.length, 1);
      expect(model.laborLines.first.description, 'Engine tune-up');
      expect(model.mechanicId, 'mech-1');
      expect(model.mechanicName, 'Juan Dela Cruz');
    });

    test('fromMap defaults labor to [] and mechanic to null for legacy docs',
        () {
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-LEGACY',
          'discountType': 'amount',
          'paymentMethod': 'cash',
          'amountReceived': 200.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'cashier-1',
          'cashierName': 'John Doe',
        },
        'sale-legacy',
        items: const [item],
      );

      expect(model.laborLines, isEmpty);
      expect(model.mechanicId, isNull);
      expect(model.mechanicName, isNull);
    });

    test('toEntity / fromEntity round-trips labor + mechanic', () {
      final entity = buildModel().toEntity();
      expect(entity.laborLines.single.fee, 450.0);
      expect(entity.mechanicId, 'mech-1');
      expect(entity.mechanicName, 'Juan Dela Cruz');

      final back = SaleModel.fromEntity(entity);
      expect(back.laborLines.single.description, 'Engine tune-up');
      expect(back.mechanicName, 'Juan Dela Cruz');
    });

    test('copyWith clearMechanic nulls mechanic fields', () {
      final cleared = buildModel().copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
      expect(cleared.laborLines.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/models/sale_model_test.dart`. Expect compile errors: `SaleModel` has no `laborLines`/`mechanicId`/`mechanicName` params, no `laborSubtotal`, no `clearMechanic`.

- [ ] **Step 3: Implement** — edit `lib/data/models/sale_model.dart`.

Add the import after the `sale_item_model.dart` import:

```dart
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
```

Add the three fields after `final List<SaleItemModel> items;`:

```dart
  final List<SaleItemModel> items;
  final List<LaborLineModel> laborLines;
  final String? mechanicId;
  final String? mechanicName;
```

Add constructor params after `required this.items,`:

```dart
    required this.items,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
```

In `fromMap`, parse labor from the map directly (NOT from the `items:` param) — replace the `return SaleModel(` block:

```dart
  factory SaleModel.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    List<SaleItemModel>? items,
  }) {
    // Labor lines are stored INLINE on the sale doc (unlike items, which live
    // in the subcollection). Parse them directly off the map. Legacy -> [].
    final laborList = <LaborLineModel>[];
    final laborData = map['laborLines'] as List<dynamic>? ?? [];
    for (int i = 0; i < laborData.length; i++) {
      final laborMap = laborData[i] as Map<String, dynamic>;
      final laborId = laborMap['id'] as String? ?? 'labor-$i';
      laborList.add(LaborLineModel.fromMap(laborMap, laborId));
    }

    return SaleModel(
      id: documentId,
      saleNumber: map['saleNumber'] as String? ?? '',
      items: items ?? [],
      laborLines: laborList,
      mechanicId: map['mechanicId'] as String?,
      mechanicName: map['mechanicName'] as String?,
      discountType: DiscountType.fromString(map['discountType'] as String?),
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] as String?),
      tenders: _parseTenders(map['tenders']),
      amountReceived: (map['amountReceived'] as num?)?.toDouble() ?? 0.0,
      changeGiven: (map['changeGiven'] as num?)?.toDouble() ?? 0.0,
      status: SaleStatus.fromString(map['status'] as String?),
      cashierId: map['cashierId'] as String? ?? '',
      cashierName: map['cashierName'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      draftId: map['draftId'] as String?,
      notes: map['notes'] as String?,
      voidedAt: _parseTimestamp(map['voidedAt']),
      voidedBy: map['voidedBy'] as String?,
      voidedByName: map['voidedByName'] as String?,
      voidReason: map['voidReason'] as String?,
    );
  }
```

In `toMap`, add labor + mechanic to the inline map literal (after the `'saleNumber': saleNumber,` line) — note items are deliberately NOT in this map (subcollection), but labor IS:

```dart
    final map = <String, dynamic>{
      'saleNumber': saleNumber,
      'laborLines':
          laborLines.map((l) => l.toMap(includeId: true)).toList(),
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'discountType': discountType.value,
      'paymentMethod': paymentMethod.value,
      'amountReceived': amountReceived,
      'changeGiven': changeGiven,
      'status': status.value,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'draftId': draftId,
      'notes': notes,
      'voidedBy': voidedBy,
      'voidedByName': voidedByName,
      'voidReason': voidReason,
    };
```

In `toEntity`, add the three fields after `items: ...`:

```dart
      items: items.map((item) => item.toEntity()).toList(),
      laborLines: laborLines.map((l) => l.toEntity()).toList(),
      mechanicId: mechanicId,
      mechanicName: mechanicName,
```

In `fromEntity`, add the three fields after the `items:` mapping:

```dart
      items:
          entity.items.map((item) => SaleItemModel.fromEntity(item)).toList(),
      laborLines: entity.laborLines
          .map((l) => LaborLineModel.fromEntity(l))
          .toList(),
      mechanicId: entity.mechanicId,
      mechanicName: entity.mechanicName,
```

Add the `create` factory params + pass-through (after `required List<SaleItemModel> items,`):

```dart
    required List<SaleItemModel> items,
    List<LaborLineModel> laborLines = const [],
    String? mechanicId,
    String? mechanicName,
```

and in its body after `items: items,`:

```dart
      items: items,
      laborLines: laborLines,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
```

Add `laborSubtotal` and update `grandTotal` (replace the existing `grandTotal` getter):

```dart
  /// Labor subtotal (sum of labor fees; never discounted)
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Grand total: net parts (after discount) + labor
  double get grandTotal => (subtotal - totalDiscount) + laborSubtotal;
```

Update `copyWith` — add the three params + `clearMechanic` flag and body:

```dart
  SaleModel copyWith({
    String? id,
    String? saleNumber,
    List<SaleItemModel>? items,
    List<LaborLineModel>? laborLines,
    String? mechanicId,
    String? mechanicName,
    DiscountType? discountType,
    PaymentMethod? paymentMethod,
    Map<PaymentMethod, double>? tenders,
    double? amountReceived,
    double? changeGiven,
    SaleStatus? status,
    String? cashierId,
    String? cashierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? draftId,
    String? notes,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidedByName,
    String? voidReason,
    bool clearMechanic = false,
  }) {
    return SaleModel(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName:
          clearMechanic ? null : (mechanicName ?? this.mechanicName),
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenders: tenders ?? this.tenders,
      amountReceived: amountReceived ?? this.amountReceived,
      changeGiven: changeGiven ?? this.changeGiven,
      status: status ?? this.status,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftId: draftId ?? this.draftId,
      notes: notes ?? this.notes,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedByName: voidedByName ?? this.voidedByName,
      voidReason: voidReason ?? this.voidReason,
    );
  }
```

(`SaleModel.empty` needs no change — labor defaults to `const []`, mechanic to `null`.)

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/models/sale_model_test.dart`

- [ ] **Step 5: Commit** — `git add lib/data/models/sale_model.dart test/data/models/sale_model_test.dart && git commit -m "feat(data): add inline labor lines + mechanic to SaleModel (parsed off doc map, not items subcollection)"`

---

### Task 7: Persist labor + mechanic inline through `SaleRepositoryImpl` create/read round-trip

**Files:**
- Modify: `lib/data/repositories/sale_repository_impl.dart`
- Test: `test/data/repositories/sale_repository_impl_test.dart`

`createSale` already calls `transaction.set(saleDocRef, saleModel.toCreateMap())`, and `toCreateMap` now emits `laborLines`/`mechanicId`/`mechanicName` (previous task) — so labor is written inline with no code change to `createSale`. The read paths (`getSaleById`/`getSaleBySaleNumber`/`_loadSalesWithItems`) already build the model via `SaleModel.fromFirestore(doc, items: itemModels)`, and `fromMap` now reads labor off the doc map — so labor loads with no extra query. This task adds the round-trip tests proving it, including the legacy-doc default.

- [ ] **Step 1: Write the failing test** — append these to the existing `group('SaleRepositoryImpl', ...)` in `test/data/repositories/sale_repository_impl_test.dart` (add the import `import 'package:cloud_firestore/cloud_firestore.dart';` at the top, and a labor-bearing factory inside the group):

```dart
    SaleEntity createServiceSale() {
      return SaleEntity(
        id: '',
        saleNumber: '',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(
            id: 'labor-1',
            description: 'Engine tune-up',
            fee: 450.0,
          ),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createSale persists labor + mechanic inline on the sale doc',
        () async {
      final created = await repository.createSale(createServiceSale());

      // Read the raw doc: labor must be inline; items must NOT be on the doc.
      final doc = await fakeFirestore.collection('sales').doc(created.id).get();
      final data = doc.data()!;
      expect(data['laborLines'], isA<List<dynamic>>());
      expect((data['laborLines'] as List).length, 1);
      expect(data['mechanicId'], 'mech-1');
      expect(data['mechanicName'], 'Juan Dela Cruz');
      expect(data.containsKey('items'), isFalse);
    });

    test('getSaleById loads inline labor + mechanic with items', () async {
      final created = await repository.createSale(createServiceSale());

      final retrieved = await repository.getSaleById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.items.length, 1);
      expect(retrieved.laborLines.length, 1);
      expect(retrieved.laborLines.first.description, 'Engine tune-up');
      expect(retrieved.laborLines.first.fee, 450.0);
      expect(retrieved.mechanicId, 'mech-1');
      expect(retrieved.mechanicName, 'Juan Dela Cruz');
      // grandTotal = 200 parts + 450 labor
      expect(retrieved.grandTotal, 650.0);
    });

    test('getRecentSales loads inline labor for each sale', () async {
      await repository.createSale(createServiceSale());

      final sales = await repository.getRecentSales();

      expect(sales, isNotEmpty);
      expect(sales.first.laborLines.length, 1);
      expect(sales.first.mechanicName, 'Juan Dela Cruz');
    });

    test('legacy sale doc without laborLines loads as []', () async {
      // Write a doc directly with no labor/mechanic fields.
      final ref = await fakeFirestore.collection('sales').add({
        'saleNumber': 'SALE-LEGACY-001',
        'discountType': 'amount',
        'paymentMethod': 'cash',
        'amountReceived': 200.0,
        'changeGiven': 0.0,
        'status': 'completed',
        'cashierId': 'cashier-1',
        'cashierName': 'John Doe',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final retrieved = await repository.getSaleById(ref.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines, isEmpty);
      expect(retrieved.mechanicId, isNull);
      expect(retrieved.mechanicName, isNull);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/repositories/sale_repository_impl_test.dart`. Expect FAIL until the `SaleModel` task lands: before that, `SaleEntity` has no `laborLines` (compile error). After the model task it should already pass if `createSale`/read paths are untouched — but run first to confirm the assertions hold (the `containsKey('items') == false` and inline-labor checks verify the divergence is correct).

- [ ] **Step 3: Implement** — no production change is required in `createSale`, `getSaleById`, `getSaleBySaleNumber`, or `_loadSalesWithItems`: labor flows inline through `toCreateMap`/`fromMap` automatically. Add a clarifying doc comment above `_loadSalesWithItems` in `lib/data/repositories/sale_repository_impl.dart` so future edits do not route labor through the items subcollection:

```dart
  /// Loads sales documents with their items.
  ///
  /// Items come from the `sales/{id}/items` subcollection. Labor lines are
  /// stored INLINE on the sale doc and are parsed by [SaleModel.fromMap]
  /// directly off `doc.data()` — they are NOT passed via the `items:` param,
  /// so no extra subcollection read is needed for labor.
  Future<List<SaleEntity>> _loadSalesWithItems(
```

If the assertions in step 1 already pass against the current read/write code, this comment is the only change. If `data.containsKey('items')` is unexpectedly true, that indicates a regression where items leaked into `toMap` — fix by ensuring `SaleModel.toMap` does not emit `items` (it must not, per the subcollection design).

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/repositories/sale_repository_impl_test.dart`

- [ ] **Step 5: Commit** — `git add lib/data/repositories/sale_repository_impl.dart test/data/repositories/sale_repository_impl_test.dart && git commit -m "test(data): prove labor + mechanic persist inline on sale doc round-trip"`

---

### Task 8: Prove labor + mechanic round-trip inline through `DraftRepositoryImpl`

**Files:**
- Modify: `test/data/repositories/draft_repository_impl_test.dart`
- Test: `test/data/repositories/draft_repository_impl_test.dart`

Drafts already serialize `items` inline via `DraftModel.toCreateMap`/`toUpdateMap`, and the previous `DraftModel` task added `laborLines`/`mechanicId`/`mechanicName` to those maps and to `fromMap`. So `createDraft`/`getDraftById`/`updateDraft` carry labor with no production change. This task adds the proving tests, including the legacy-doc default and the full-`updateDraft` path (the spec warns labor must go through the full `updateDraft`, not `updateDraftItems`).

- [ ] **Step 1: Write the failing test** — append to the existing `group('DraftRepositoryImpl', ...)` in `test/data/repositories/draft_repository_impl_test.dart` (add `import 'package:cloud_firestore/cloud_firestore.dart';` at the top):

```dart
    DraftEntity createServiceDraft() {
      return DraftEntity(
        id: '',
        name: 'Service Job',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(
            id: 'labor-1',
            description: 'Engine tune-up',
            fee: 450.0,
          ),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        discountType: DiscountType.amount,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createDraft persists labor + mechanic inline on the draft doc',
        () async {
      final created = await repository.createDraft(createServiceDraft());

      final doc =
          await fakeFirestore.collection('drafts').doc(created.id).get();
      final data = doc.data()!;
      expect((data['laborLines'] as List).length, 1);
      expect(data['mechanicId'], 'mech-1');
      expect(data['mechanicName'], 'Juan Dela Cruz');
    });

    test('getDraftById round-trips labor + mechanic', () async {
      final created = await repository.createDraft(createServiceDraft());

      final retrieved = await repository.getDraftById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines.length, 1);
      expect(retrieved.laborLines.first.description, 'Engine tune-up');
      expect(retrieved.laborLines.first.fee, 450.0);
      expect(retrieved.mechanicId, 'mech-1');
      expect(retrieved.mechanicName, 'Juan Dela Cruz');
      // grandTotal = 200 parts + 450 labor
      expect(retrieved.grandTotal, 650.0);
    });

    test('updateDraft persists changed labor + mechanic', () async {
      final created = await repository.createDraft(createServiceDraft());

      final updated = await repository.updateDraft(
        draft: created.copyWith(
          laborLines: const [
            LaborLineEntity(
              id: 'labor-1',
              description: 'Engine tune-up',
              fee: 450.0,
            ),
            LaborLineEntity(
              id: 'labor-2',
              description: 'Brake bleed',
              fee: 200.0,
            ),
          ],
          mechanicId: 'mech-2',
          mechanicName: 'Pedro Santos',
        ),
        updatedBy: 'cashier-1',
      );

      expect(updated.laborLines.length, 2);
      expect(updated.laborSubtotal, 650.0);
      expect(updated.mechanicId, 'mech-2');
      expect(updated.mechanicName, 'Pedro Santos');
      // 200 parts + 650 labor
      expect(updated.grandTotal, 850.0);
    });

    test('legacy draft doc without laborLines loads as []', () async {
      final ref = await fakeFirestore.collection('drafts').add({
        'name': 'Legacy Draft',
        'items': const [
          {
            'id': 'item-1',
            'productId': 'prod-1',
            'sku': 'SKU-001',
            'name': 'Test Product',
            'unitPrice': 100.0,
            'unitCost': 60.0,
            'quantity': 2,
            'discountValue': 0.0,
            'unit': 'pcs',
          },
        ],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
        'isConverted': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final retrieved = await repository.getDraftById(ref.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines, isEmpty);
      expect(retrieved.mechanicId, isNull);
      expect(retrieved.mechanicName, isNull);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/repositories/draft_repository_impl_test.dart`. Before the `DraftModel` + entity tasks land, expect a compile error (`DraftEntity` / `LaborLineEntity` have no labor params). After those land, the round-trip assertions verify persistence with no `DraftRepositoryImpl` change.

- [ ] **Step 3: Implement** — no production change to `DraftRepositoryImpl`: `createDraft` uses `DraftModel.fromEntity(draft).toCreateMap()` and `updateDraft` uses `toUpdateMap`, both of which now emit labor + mechanic, and `getDraftById` reads them back via `DraftModel.fromFirestore`. (Tests are the deliverable here; if any assertion fails it points to a `DraftModel` serialization gap to fix in that file, not here.)

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/repositories/draft_repository_impl_test.dart`

- [ ] **Step 5: Commit** — `git add test/data/repositories/draft_repository_impl_test.dart && git commit -m "test(data): prove labor + mechanic round-trip inline through DraftRepositoryImpl"`



<!-- slice: E-reporting (Reporting rollup (parts-only) + daily closing + dashboard card) -->

### Task 9: SalesSummary gains laborRevenue / laborProfit (parts-only top-line)

**Files:**
- Modify: `lib/domain/repositories/sale_repository.dart`
- Test: `test/domain/repositories/sales_summary_labor_fields_test.dart` (Create)

- [ ] **Step 1: Write the failing test**
```dart
// test/domain/repositories/sales_summary_labor_fields_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

void main() {
  group('SalesSummary labor track', () {
    test('empty() seeds labor fields to zero', () {
      final s = SalesSummary.empty();
      expect(s.laborRevenue, 0);
      expect(s.laborProfit, 0);
      expect(s.netAmount, 0);
    });

    test('parts-only fields stay independent of the labor track', () {
      const s = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000,
        totalDiscounts: 100,
        netAmount: 900,
        totalCost: 400,
        totalProfit: 500,
        byPaymentMethod: {PaymentMethod.cash: 1350},
        laborRevenue: 450,
        laborProfit: 450,
      );
      // Parts-only top-line untouched by labor.
      expect(s.netAmount, 900);
      expect(s.totalProfit, 500);
      expect(s.totalCost, 400);
      // Labor is its own track (zero cost ⇒ profit == revenue).
      expect(s.laborRevenue, 450);
      expect(s.laborProfit, 450);
      // Cash bucket is labor-inclusive: net(parts) + labor == Σ byPaymentMethod.
      final tenderTotal =
          s.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
      expect(tenderTotal, s.netAmount + s.laborRevenue);
    });

    test('profitMargin still divides parts profit by parts net', () {
      const s = SalesSummary(
        totalSalesCount: 1,
        voidedSalesCount: 0,
        grossAmount: 1000,
        totalDiscounts: 0,
        netAmount: 1000,
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {},
        laborRevenue: 999,
        laborProfit: 999,
      );
      expect(s.profitMargin, 40); // labor must not skew the parts margin
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/repositories/sales_summary_labor_fields_test.dart`. Fails to compile: `The named parameter 'laborRevenue' isn't defined` / `The getter 'laborProfit' isn't defined`.

- [ ] **Step 3: Implement** — add the two fields, constructor params, and `empty()` seeds in `lib/domain/repositories/sale_repository.dart`. Replace the existing `SalesSummary` field block (after `final double totalProfit;`) and constructor/factory:
```dart
  /// Total profit
  final double totalProfit;

  /// Total labor (service) revenue for the period. Separate track from
  /// merchandise: NOT included in [netAmount]/[grossAmount]/[totalProfit],
  /// which stay PARTS-ONLY. Labor cash IS included in [byPaymentMethod].
  final double laborRevenue;

  /// Total labor profit. Labor has zero cost, so this equals [laborRevenue].
  final double laborProfit;

  /// Breakdown by payment method
  final Map<PaymentMethod, double> byPaymentMethod;

  /// Average sale amount
  double get averageSaleAmount =>
      totalSalesCount > 0 ? netAmount / totalSalesCount : 0;

  /// Profit margin percentage (parts-only — [totalProfit]/[netAmount] are
  /// both merchandise figures, so labor never skews the merchandise margin).
  double get profitMargin =>
      netAmount > 0 ? (totalProfit / netAmount) * 100 : 0;

  /// Total Salmon receivable (balance Salmon covers the next day). Not cash.
  double get salmonReceivable => byPaymentMethod[PaymentMethod.salmon] ?? 0;

  const SalesSummary({
    required this.totalSalesCount,
    required this.voidedSalesCount,
    required this.grossAmount,
    required this.totalDiscounts,
    required this.netAmount,
    required this.totalCost,
    required this.totalProfit,
    required this.byPaymentMethod,
    this.laborRevenue = 0,
    this.laborProfit = 0,
  });

  /// Creates an empty summary.
  factory SalesSummary.empty() {
    return const SalesSummary(
      totalSalesCount: 0,
      voidedSalesCount: 0,
      grossAmount: 0,
      totalDiscounts: 0,
      netAmount: 0,
      totalCost: 0,
      totalProfit: 0,
      byPaymentMethod: {},
      laborRevenue: 0,
      laborProfit: 0,
    );
  }
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/repositories/sales_summary_labor_fields_test.dart`

- [ ] **Step 5: Commit** — `git add lib/domain/repositories/sale_repository.dart test/domain/repositories/sales_summary_labor_fields_test.dart && git commit -m "feat(reports): add parts-only labor track fields to SalesSummary"`

---

### Task 10: getSalesSummary keeps top-line parts-only, adds labor track

**Files:**
- Modify: `lib/data/repositories/sale_repository_impl.dart`
- Test: `test/data/repositories/sales_summary_labor_rollup_test.dart` (Create)
- Test: `test/data/repositories/sale_repository_impl_test.dart` (Modify)

This depends on `SaleEntity` already exposing `partsRevenue`, `partsSubtotal`, `laborRevenue`, `laborLines` (added by the domain-money-math slice). The test builds a sale with one part (₱100 × 2, cost ₱60) and one labor line (₱150) so parts-net = 200, labor = 150, and `effectiveTenders` (labor-inclusive) sums to 350 = `partsRevenue + laborRevenue`.

- [ ] **Step 1: Write the failing test**
```dart
// test/data/repositories/sales_summary_labor_rollup_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SaleRepositoryImpl(firestore: fakeFirestore);
  });

  SaleEntity saleWithLabor(DateTime when) => SaleEntity(
        id: '',
        saleNumber: '',
        items: const [
          SaleItemEntity(
            id: 'i1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Brake bleed', fee: 150.0),
        ],
        mechanicId: 'm1',
        mechanicName: 'Juan',
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 350.0,
        changeGiven: 0.0,
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: when,
      );

  test('top-line stays parts-only; labor lands in its own track', () async {
    final today = DateTime.now();
    await repository.createSale(saleWithLabor(today));

    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    // Parts-only top-line: net = partsRevenue (200), NOT grandTotal (350).
    expect(summary.grossAmount, 200); // partsSubtotal
    expect(summary.netAmount, 200); // partsRevenue
    expect(summary.totalCost, 120); // 60 * 2 — labor adds no cost
    expect(summary.totalProfit, 80); // 200 - 120, parts profit only
    // Labor track.
    expect(summary.laborRevenue, 150);
    expect(summary.laborProfit, 150);
    // Cash bucket is labor-inclusive (drawer holds labor cash).
    expect(summary.byPaymentMethod[PaymentMethod.cash], 350);
    // Reconciliation identity.
    final tenderTotal =
        summary.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
    expect(tenderTotal, summary.netAmount + summary.laborRevenue);
  });

  test('labor-free sale leaves the labor track at zero', () async {
    final today = DateTime.now();
    await repository.createSale(SaleEntity(
      id: '',
      saleNumber: '',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Oil',
          unitPrice: 100.0,
          unitCost: 60.0,
          quantity: 1,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100.0,
      changeGiven: 0.0,
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: today,
    ));

    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    expect(summary.netAmount, 100);
    expect(summary.laborRevenue, 0);
    expect(summary.laborProfit, 0);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/repositories/sales_summary_labor_rollup_test.dart`. Fails: `laborRevenue` is 0 / `netAmount` is 350 (still uses `sale.grandTotal`), so the parts-only expectations and labor expectations both fail.

- [ ] **Step 3: Implement** — in `lib/data/repositories/sale_repository_impl.dart`, change the accumulation loop in `getSalesSummary` (lines ~467–502). Add a `laborRevenue` accumulator and switch the parts figures to parts-only getters:
```dart
    double grossAmount = 0;
    double totalDiscounts = 0;
    double netAmount = 0;
    double totalCost = 0;
    double laborRevenue = 0;
    final byPaymentMethod = <PaymentMethod, double>{};

    // Seed only real tender buckets (never `mixed`, which is a label).
    for (final method in const [
      PaymentMethod.cash,
      PaymentMethod.gcash,
      PaymentMethod.maya,
      PaymentMethod.salmon,
    ]) {
      byPaymentMethod[method] = 0;
    }

    for (final sale in completedSales) {
      // Top-line stays PARTS-ONLY: merchandise reporting must not move when
      // labor is present. Labor is summed into its own track below; the cash
      // buckets (effectiveTenders) remain labor-inclusive because the drawer
      // physically holds labor cash.
      grossAmount += sale.partsSubtotal;
      totalDiscounts += sale.totalDiscount;
      netAmount += sale.partsRevenue;
      totalCost += sale.totalCost; // items-only; labor has zero cost
      laborRevenue += sale.laborRevenue;
      sale.effectiveTenders.forEach((method, amount) {
        byPaymentMethod[method] = (byPaymentMethod[method] ?? 0) + amount;
      });
    }

    return SalesSummary(
      totalSalesCount: completedSales.length,
      voidedSalesCount: voidedSales.length,
      grossAmount: grossAmount,
      totalDiscounts: totalDiscounts,
      netAmount: netAmount,
      totalCost: totalCost,
      totalProfit: netAmount - totalCost, // parts profit
      byPaymentMethod: byPaymentMethod,
      laborRevenue: laborRevenue,
      laborProfit: laborRevenue, // labor has zero cost
    );
```

  Then harden the existing repo test so it explicitly pins the parts-only/labor split. In `test/data/repositories/sale_repository_impl_test.dart`, replace the `getSalesSummary should calculate totals correctly` test body with:
```dart
    test('getSalesSummary should calculate totals correctly', () async {
      final today = DateTime.now();

      // Create multiple sales (parts-only; labor track must be zero).
      await repository.createSale(createTestSale().copyWith(createdAt: today));
      await repository.createSale(createTestSale().copyWith(createdAt: today));

      final summary = await repository.getSalesSummary(
        startDate: today,
        endDate: today,
      );

      expect(summary.totalSalesCount, 2);
      expect(summary.netAmount, 400); // 2 × (100 × 2), no discount
      expect(summary.grossAmount, 400);
      expect(summary.totalCost, 240); // 2 × (60 × 2)
      expect(summary.totalProfit, 160);
      expect(summary.laborRevenue, 0);
      expect(summary.laborProfit, 0);
    });
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/repositories/sales_summary_labor_rollup_test.dart test/data/repositories/sale_repository_impl_test.dart test/data/repositories/sales_summary_tenders_test.dart`

- [ ] **Step 5: Commit** — `git add lib/data/repositories/sale_repository_impl.dart test/data/repositories/sales_summary_labor_rollup_test.dart test/data/repositories/sale_repository_impl_test.dart && git commit -m "feat(reports): keep getSalesSummary parts-only top-line, add labor track"`

---

### Task 11: DailyClosingDraft / DailyClosingEntity carry laborRevenue

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart`
- Test: `test/domain/entities/daily_closing_draft_test.dart` (Modify)

`expectedCashFor` is deliberately left unchanged: `cashSales` already comes from `byPaymentMethod[cash]`, which `getSalesSummary` keeps labor-inclusive, so labor cash already raises expected drawer cash. The new `laborRevenue` field is a reporting line only.

- [ ] **Step 1: Write the failing test** — append to the existing `group('DailyClosingDraft.fromData', ...)` in `test/domain/entities/daily_closing_draft_test.dart`:
```dart
    test('carries labor revenue as its own line; cash stays labor-inclusive',
        () {
      const summary = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000, // parts gross (parts-only)
        totalDiscounts: 0,
        netAmount: 1000, // parts net (parts-only)
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {PaymentMethod.cash: 1450}, // parts 1000 + labor 450
        laborRevenue: 450,
        laborProfit: 450,
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      // Parts-only top-line on the closing snapshot.
      expect(draft.grossSales, 1000);
      expect(draft.netSales, 1000);
      // Labor surfaced as its own line.
      expect(draft.laborRevenue, 450);
      // Expected cash is labor-inclusive: 0 float + 1450 cash - 0 expenses.
      expect(draft.expectedCashFor(0), 1450);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/entities/daily_closing_draft_test.dart`. Fails: `The getter 'laborRevenue' isn't defined for the type 'DailyClosingDraft'`.

- [ ] **Step 3: Implement** — in `lib/domain/entities/daily_closing_entity.dart`, add the field + constructor param + `fromData` wiring + props for `DailyClosingDraft`. Add the field after `final double salmonReceivable;`:
```dart
  final double salmonReceivable;

  /// Labor (service) revenue for the day. A separate track from merchandise:
  /// [grossSales]/[netSales] stay PARTS-ONLY. Labor cash is already folded into
  /// [cashSales]/[expectedCashFor] (the drawer physically holds it), so this
  /// field is a reporting line, not a reconciliation input.
  final double laborRevenue;
```
  Add to the constructor (after `required this.salmonReceivable,`):
```dart
    required this.salmonReceivable,
    this.laborRevenue = 0,
```
  Wire `fromData` — replace the `return DailyClosingDraft(...)` tail so it passes `laborRevenue`:
```dart
    return DailyClosingDraft(
      businessDate: businessDate,
      grossSales: summary.grossAmount,
      netSales: summary.netAmount,
      totalDiscounts: summary.totalDiscounts,
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      gcashSales: gcashSales,
      mayaSales: mayaSales,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: salmonReceivable,
      laborRevenue: summary.laborRevenue,
      salesCount: summary.totalSalesCount,
      voidedCount: summary.voidedSalesCount,
    );
```
  Add `laborRevenue` to the `DailyClosingDraft` props list (after `salmonReceivable,`):
```dart
        salmonReceivable,
        laborRevenue,
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/entities/daily_closing_draft_test.dart`

- [ ] **Step 5: Commit** — `git add lib/domain/entities/daily_closing_entity.dart test/domain/entities/daily_closing_draft_test.dart && git commit -m "feat(closing): add laborRevenue line to DailyClosingDraft (parts-only top-line)"`

---

### Task 12: Persist laborRevenue on DailyClosingEntity + model

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart`
- Modify: `lib/data/models/daily_closing_model.dart`
- Modify: `lib/domain/usecases/daily_closing/close_day_usecase.dart`
- Test: `test/data/models/daily_closing_model_labor_test.dart` (Create)

`DailyClosingModel.fromMap` defaults `laborRevenue → 0` for legacy closing docs (via the existing `d()` helper, which returns `0.0` for absent keys).

- [ ] **Step 1: Write the failing test**
```dart
// test/data/models/daily_closing_model_labor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

void main() {
  group('DailyClosingModel labor revenue', () {
    DailyClosingEntity entity({double laborRevenue = 0}) => DailyClosingEntity(
          id: '2026-05-28',
          businessDate: DateTime(2026, 5, 28),
          grossSales: 1000,
          netSales: 1000,
          totalDiscounts: 0,
          cashSales: 1450,
          nonCashSales: 0,
          gcashSales: 0,
          mayaSales: 0,
          totalExpenses: 0,
          cashExpenses: 0,
          salmonReceivable: 0,
          laborRevenue: laborRevenue,
          openingFloat: 0,
          expectedCash: 1450,
          countedCash: 1450,
          variance: 0,
          salesCount: 2,
          voidedCount: 0,
          closedBy: 'u1',
          closedByName: 'Admin',
          closedAt: DateTime(2026, 5, 28, 18),
        );

    test('round-trips laborRevenue through toMap/fromMap', () {
      final map = DailyClosingModel.fromEntity(entity(laborRevenue: 450)).toMap();
      expect(map['laborRevenue'], 450);

      final back = DailyClosingModel.fromMap(map, '2026-05-28').toEntity();
      expect(back.laborRevenue, 450);
    });

    test('legacy doc without laborRevenue defaults to 0', () {
      final legacy = DailyClosingModel.fromEntity(entity()).toMap()
        ..remove('laborRevenue');
      final back = DailyClosingModel.fromMap(legacy, '2026-05-28').toEntity();
      expect(back.laborRevenue, 0);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/models/daily_closing_model_labor_test.dart`. Fails: `The named parameter 'laborRevenue' isn't defined` on `DailyClosingEntity`.

- [ ] **Step 3: Implement** — three edits.

  (a) `lib/domain/entities/daily_closing_entity.dart` — add the field, constructor param, and props to `DailyClosingEntity` (the persisted record). Add after its `final double salmonReceivable;`:
```dart
  final double salmonReceivable;
  final double laborRevenue;
```
  Add to its constructor after `required this.salmonReceivable,`:
```dart
    required this.salmonReceivable,
    this.laborRevenue = 0,
```
  Add to its props after `salmonReceivable,`:
```dart
        salmonReceivable,
        laborRevenue,
```

  (b) `lib/data/models/daily_closing_model.dart` — add field, constructor, `fromMap`, `fromEntity`, `toMap`, `toEntity`. Field after `final double salmonReceivable;`:
```dart
  final double salmonReceivable;
  final double laborRevenue;
```
  Constructor after `required this.salmonReceivable,`:
```dart
    required this.salmonReceivable,
    this.laborRevenue = 0,
```
  `fromMap` after `salmonReceivable: d('salmonReceivable'),`:
```dart
      salmonReceivable: d('salmonReceivable'),
      laborRevenue: d('laborRevenue'),
```
  `fromEntity` after `salmonReceivable: e.salmonReceivable,`:
```dart
      salmonReceivable: e.salmonReceivable,
      laborRevenue: e.laborRevenue,
```
  `toMap` after `'salmonReceivable': salmonReceivable,`:
```dart
      'salmonReceivable': salmonReceivable,
      'laborRevenue': laborRevenue,
```
  `toEntity` after `salmonReceivable: salmonReceivable,`:
```dart
      salmonReceivable: salmonReceivable,
      laborRevenue: laborRevenue,
```

  (c) `lib/domain/usecases/daily_closing/close_day_usecase.dart` — carry the draft's labor revenue onto the saved entity. In the `DailyClosingEntity(...)` construction, add after `salmonReceivable: draft.salmonReceivable,`:
```dart
        salmonReceivable: draft.salmonReceivable,
        laborRevenue: draft.laborRevenue,
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/models/daily_closing_model_labor_test.dart test/domain/entities/daily_closing_draft_test.dart`

- [ ] **Step 5: Commit** — `git add lib/domain/entities/daily_closing_entity.dart lib/data/models/daily_closing_model.dart lib/domain/usecases/daily_closing/close_day_usecase.dart test/data/models/daily_closing_model_labor_test.dart && git commit -m "feat(closing): persist laborRevenue on DailyClosingEntity + model"`

---

### Task 13: End-of-day screen surfaces the Labor revenue line

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
- Test: manual (widget test impractical — the screen depends on `dailyClosingForDateProvider` / `dailyClosingDraftProvider`, Firebase-backed Riverpod providers with no injectable test seam; verify the row renders via the data path below)

The labor line is shown only when `> 0` so labor-free days are visually unchanged. It is placed under "Sales" so the team sees why the cash total rose; `expectedCash` already includes labor cash and is intentionally not re-derived here.

- [ ] **Step 1: Write the failing test** — not applicable (no injectable seam). Manual verification: open End-of-Day on a day that has a sale with labor; confirm a "Labor revenue (service)" row appears under Sales in both the live review and the closed read-only view, and that "Gross sales" still shows parts-only.

- [ ] **Step 2: Run it, expect FAIL** — not applicable; proceed to implement, then run the analyzer: `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart` (expect no new issues after Step 3).

- [ ] **Step 3: Implement** — two edits.

  (a) In `_buildReview`'s `_section('Sales', [...])`, add a labor row after `_rowText('Sales count', ...)` and before the salmon row:
```dart
                _section('Sales', [
                  _row('Gross sales', draft.grossSales),
                  _row('Cash sales', draft.cashSales),
                  _row('Non-cash sales', draft.nonCashSales),
                  if (draft.gcashSales > 0) _row('  GCash', draft.gcashSales),
                  if (draft.mayaSales > 0) _row('  Maya', draft.mayaSales),
                  _row('Discounts', draft.totalDiscounts),
                  if (draft.laborRevenue > 0)
                    _row('Labor revenue (service)', draft.laborRevenue),
                  _rowText('Sales count', '${draft.salesCount}'),
                  if (draft.salmonReceivable > 0)
                    _row('Salmon receivable (next day)',
                        draft.salmonReceivable),
                ]),
```

  (b) In `_ClosedView.build`'s `_card(context, 'Sales', {...})`, add the labor entry after `'Discounts'`:
```dart
          _card(context, 'Sales', {
            'Gross sales': closing.grossSales,
            'Cash sales': closing.cashSales,
            'Non-cash sales': closing.nonCashSales,
            if (closing.gcashSales > 0) '  GCash': closing.gcashSales,
            if (closing.mayaSales > 0) '  Maya': closing.mayaSales,
            'Discounts': closing.totalDiscounts,
            if (closing.laborRevenue > 0)
              'Labor revenue (service)': closing.laborRevenue,
            if (closing.salmonReceivable > 0)
              'Salmon receivable': closing.salmonReceivable,
          }),
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart` (no new issues); manual check per Step 1.

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart && git commit -m "feat(eod): show Labor revenue line; gross/net stay parts-only"`

---

### Task 14: Dashboard "Service / Labor" card

**Files:**
- Modify: `lib/presentation/shared/widgets/dashboard/sales_summary_section.dart`
- Test: `test/presentation/widgets/sales_summary_section_labor_test.dart` (Create)

The card is admin-only (sits in the existing `if (isAdmin)` block) and only renders when `laborRevenue > 0`, so parts-only shops see the exact same dashboard. Existing Gross Profit / COGS read parts-only `summary.totalProfit` / `summary.totalCost` unchanged. The widget test overrides `todaysSalesSummaryProvider` and `avgDailySalesProvider` with a `SalesSummary` carrying labor and asserts the card text.

- [ ] **Step 1: Write the failing test**
```dart
// test/presentation/widgets/sales_summary_section_labor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/sales_summary_section.dart';

void main() {
  Widget host(SalesSummary summary) => ProviderScope(
        overrides: [
          todaysSalesSummaryProvider.overrideWith((ref) async => summary),
          avgDailySalesProvider.overrideWith((ref) async => 0.0),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalesSummarySection(isAdmin: true),
            ),
          ),
        ),
      );

    const withLabor = SalesSummary(
      totalSalesCount: 1,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 600,
      totalProfit: 400,
      byPaymentMethod: {PaymentMethod.cash: 1450},
      laborRevenue: 450,
      laborProfit: 450,
    );

    const noLabor = SalesSummary(
      totalSalesCount: 1,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 600,
      totalProfit: 400,
      byPaymentMethod: {PaymentMethod.cash: 1000},
    );

  testWidgets('shows Service / Labor card when laborRevenue > 0',
      (tester) async {
    await tester.pumpWidget(host(withLabor));
    await tester.pumpAndSettle();

    expect(find.text('Service / Labor'), findsOneWidget);
    // Parts cards still present and parts-only.
    expect(find.text('Gross Profit'), findsOneWidget);
    expect(find.text('Total COGS'), findsOneWidget);
  });

  testWidgets('hides Service / Labor card when no labor', (tester) async {
    await tester.pumpWidget(host(noLabor));
    await tester.pumpAndSettle();

    expect(find.text('Service / Labor'), findsNothing);
    expect(find.text('Gross Profit'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/sales_summary_section_labor_test.dart`. Fails: `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets>` for `'Service / Labor'`.

- [ ] **Step 3: Implement** — in `lib/presentation/shared/widgets/dashboard/sales_summary_section.dart`, append a third admin row after the existing `Total COGS / Gross Profit` `IntrinsicHeight`, still inside the `if (isAdmin) ...[ ]` block. Replace the closing of that block:
```dart
            if (isAdmin) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Total COGS',
                        value:
                            '${AppConstants.currencySymbol}${_formatNumber(summary.totalCost)}',
                        icon: CupertinoIcons.cube_box,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Gross Profit',
                        value:
                            '${AppConstants.currencySymbol}${_formatNumber(summary.totalProfit)}',
                        icon: CupertinoIcons.arrow_up_right,
                        subtitle:
                            '${summary.profitMargin.toStringAsFixed(1)}% margin',
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.laborRevenue > 0) ...[
                const SizedBox(height: 12),
                SummaryCard(
                  title: 'Service / Labor',
                  value:
                      '${AppConstants.currencySymbol}${_formatNumber(summary.laborRevenue)}',
                  icon: CupertinoIcons.wrench,
                  subtitle:
                      '${AppConstants.currencySymbol}${_formatNumber(summary.laborProfit)} profit',
                ),
              ],
            ],
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/sales_summary_section_labor_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/shared/widgets/dashboard/sales_summary_section.dart test/presentation/widgets/sales_summary_section_labor_test.dart && git commit -m "feat(dashboard): add Service / Labor card; parts cards unchanged"`



<!-- slice: F-cart (Cart state + notifier) -->

### Task 15: Add labor + mechanic fields and money-math getters to `CartState`

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_provider_test.dart`

> Depends on Plan 2 Phase 2 (`LaborLineEntity` exported via `lib/domain/entities/entities.dart`, and `DraftEntity`/`SaleEntity` carrying `laborLines`/`mechanicId`/`mechanicName`). `cart_provider.dart` already imports `package:maki_mobile_pos/domain/entities/entities.dart`, so `LaborLineEntity` is in scope.

- [ ] **Step 1: Write the failing test** — append these tests inside the existing `group('CartNotifier', ...)` block in `test/presentation/providers/cart_provider_test.dart` (just before its closing `});` on line 314):

```dart
    test('CartState defaults: empty laborLines, null mechanic', () {
      final state = container.read(cartProvider);
      expect(state.laborLines, isEmpty);
      expect(state.mechanicId, isNull);
      expect(state.mechanicName, isNull);
      expect(state.laborSubtotal, 0);
    });

    test('grandTotal includes labor; parts/labor split is correct', () {
      // parts: 100 * 2 = 200, discount 20 -> partsRevenue 180
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product, quantity: 2);
      final itemId = container.read(cartProvider).items.first.id;
      cartNotifier.applyItemDiscount(itemId, 20);

      cartNotifier.addLaborLine(description: 'Tune-up', fee: 300);
      cartNotifier.addLaborLine(description: 'Brake bleed', fee: 150);

      final state = container.read(cartProvider);
      expect(state.partsSubtotal, 200);
      expect(state.totalDiscount, 20);
      expect(state.partsRevenue, 180);
      expect(state.laborSubtotal, 450);
      expect(state.laborRevenue, 450);
      // grandTotal = partsRevenue(180) + laborRevenue(450)
      expect(state.grandTotal, 630);
    });

    test('profit split: parts profit excludes labor cost; labor is pure margin',
        () {
      // price 100, cost 60, qty 2 -> partsRevenue 200, totalCost 120
      cartNotifier.addProduct(createTestProduct(price: 100, cost: 60),
          quantity: 2);
      cartNotifier.addLaborLine(description: 'Labor', fee: 500);

      final state = container.read(cartProvider);
      expect(state.totalCost, 120); // items only
      expect(state.partsProfit, 80); // 200 - 120
      expect(state.laborProfit, 500); // zero cost
      expect(state.totalProfit, 580); // 80 + 500
    });

    test('cartGrandTotalProvider reflects labor', () {
      cartNotifier.addProduct(createTestProduct(price: 100));
      cartNotifier.addLaborLine(description: 'Labor', fee: 250);
      expect(container.read(cartGrandTotalProvider), 350);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/cart_provider_test.dart`. Expect compile/analyzer failures: `The named parameter 'description' isn't defined` (no `addLaborLine`), and `The getter 'laborLines'/'laborSubtotal'/'partsRevenue'/'laborRevenue'/'partsProfit'/'laborProfit' isn't defined for the class 'CartState'`.

- [ ] **Step 3: Implement** — in `lib/presentation/providers/cart_provider.dart`, add the three fields to `CartState`'s field block (after `draftName`, before `isProcessing` on line 42):

```dart
  /// Labor/service lines on this ticket. Full price, never discounted.
  final List<LaborLineEntity> laborLines;

  /// Assigned mechanic id (null until a mechanic is picked).
  final String? mechanicId;

  /// Assigned mechanic name snapshot (denormalized, like cashierName).
  final String? mechanicName;
```

Add them to the constructor (after `this.draftName,` on line 59):

```dart
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
```

Replace the existing `grandTotal` and `totalProfit` getters (lines 98-107) with the full money-math block:

```dart
  /// Parts gross subtotal (items only, before discount). Alias of [subtotal].
  double get partsSubtotal => subtotal;

  /// Net merchandise revenue (parts after discount).
  double get partsRevenue => partsSubtotal - totalDiscount;

  /// Labor subtotal (sum of labor fees; never discounted).
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Labor revenue (pure margin — zero cost).
  double get laborRevenue => laborSubtotal;

  /// Grand total after discounts, including labor.
  double get grandTotal => partsRevenue + laborRevenue;

  /// Total cost of all items
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Merchandise profit (parts revenue minus parts cost).
  double get partsProfit => partsRevenue - totalCost;

  /// Labor profit (equals labor revenue; zero cost).
  double get laborProfit => laborRevenue;

  /// True per-transaction profit (parts + labor).
  double get totalProfit => partsProfit + laborProfit;
```

Add the three fields to `copyWith` params (after `String? draftName,` on line 189) plus a `clearMechanic` flag (add alongside the other clear flags, e.g. after `bool clearDraftName = false,` on line 194):

```dart
    List<LaborLineEntity>? laborLines,
    String? mechanicId,
    String? mechanicName,
    bool clearMechanic = false,
```

And wire them into the returned `CartState(...)` (after the `draftName:` line on line 209, before `isProcessing:`):

```dart
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/cart_provider_test.dart` (the `addLaborLine` calls compile because the notifier method is added in the next task — so run with both tasks staged, OR temporarily verify the four getter tests after adding the notifier method below). Cleanest: implement this task and the next together, then run; expect PASS.

- [ ] **Step 5: Commit** — `git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_provider_test.dart && git commit -m "feat(cart): add labor lines + mechanic fields and parts/labor money-math getters to CartState"`

---

### Task 16: Add labor + mechanic mutation methods to `CartNotifier`

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_provider_test.dart`

- [ ] **Step 1: Write the failing test** — append these tests inside the existing `group('CartNotifier', ...)` block in `test/presentation/providers/cart_provider_test.dart`:

```dart
    test('addLaborLine appends a line with a generated id and fee', () {
      cartNotifier.addLaborLine(description: 'Tune-up', fee: 300);

      final state = container.read(cartProvider);
      expect(state.laborLines.length, 1);
      expect(state.laborLines.first.id, isNotEmpty);
      expect(state.laborLines.first.description, 'Tune-up');
      expect(state.laborLines.first.fee, 300);
    });

    test('addLaborLine adds multiple distinct lines', () {
      cartNotifier.addLaborLine(description: 'A', fee: 100);
      cartNotifier.addLaborLine(description: 'B', fee: 200);

      final state = container.read(cartProvider);
      expect(state.laborLines.length, 2);
      expect(state.laborLines[0].id, isNot(state.laborLines[1].id));
      expect(state.laborSubtotal, 300);
    });

    test('updateLaborLine edits description and fee by id', () {
      cartNotifier.addLaborLine(description: 'Old', fee: 100);
      final id = container.read(cartProvider).laborLines.first.id;

      cartNotifier.updateLaborLine(id, description: 'New', fee: 250);

      final line = container.read(cartProvider).laborLines.first;
      expect(line.description, 'New');
      expect(line.fee, 250);
    });

    test('updateLaborLine with only fee keeps description', () {
      cartNotifier.addLaborLine(description: 'Keep', fee: 100);
      final id = container.read(cartProvider).laborLines.first.id;

      cartNotifier.updateLaborLine(id, fee: 400);

      final line = container.read(cartProvider).laborLines.first;
      expect(line.description, 'Keep');
      expect(line.fee, 400);
    });

    test('updateLaborLine with unknown id is a no-op', () {
      cartNotifier.addLaborLine(description: 'A', fee: 100);
      cartNotifier.updateLaborLine('nope', fee: 999);

      expect(container.read(cartProvider).laborLines.first.fee, 100);
    });

    test('removeLaborLine removes by id', () {
      cartNotifier.addLaborLine(description: 'A', fee: 100);
      cartNotifier.addLaborLine(description: 'B', fee: 200);
      final firstId = container.read(cartProvider).laborLines.first.id;

      cartNotifier.removeLaborLine(firstId);

      final state = container.read(cartProvider);
      expect(state.laborLines.length, 1);
      expect(state.laborLines.first.description, 'B');
    });

    test('setMechanic assigns id and name; clearMechanic nulls both', () {
      cartNotifier.setMechanic('mech-1', 'Juan Dela Cruz');

      var state = container.read(cartProvider);
      expect(state.mechanicId, 'mech-1');
      expect(state.mechanicName, 'Juan Dela Cruz');

      cartNotifier.clearMechanic();

      state = container.read(cartProvider);
      expect(state.mechanicId, isNull);
      expect(state.mechanicName, isNull);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/cart_provider_test.dart`. Expect `The method 'addLaborLine'/'updateLaborLine'/'removeLaborLine'/'setMechanic'/'clearMechanic' isn't defined for the type 'CartNotifier'`.

- [ ] **Step 3: Implement** — in `lib/presentation/providers/cart_provider.dart`, add a new section to `CartNotifier` immediately after the discount operations section (after `clearAllDiscounts()` closes on line 381, before the `// ==================== PAYMENT OPERATIONS ====================` comment on line 383):

```dart
  // ==================== LABOR & MECHANIC OPERATIONS ====================

  /// Adds a labor/service line with a generated id.
  void addLaborLine({required String description, required double fee}) {
    final line = LaborLineEntity(
      id: _uuid.v4(),
      description: description,
      fee: fee,
    );
    state = state.copyWith(
      laborLines: [...state.laborLines, line],
      clearErrorMessage: true,
    );
  }

  /// Updates a labor line by id. Only the provided fields change.
  void updateLaborLine(String id, {String? description, double? fee}) {
    final index = state.laborLines.indexWhere((l) => l.id == id);
    if (index < 0) return;

    final updatedLines = List<LaborLineEntity>.from(state.laborLines);
    updatedLines[index] = state.laborLines[index].copyWith(
      description: description,
      fee: fee,
    );
    state = state.copyWith(laborLines: updatedLines, clearErrorMessage: true);
  }

  /// Removes a labor line by id.
  void removeLaborLine(String id) {
    state = state.copyWith(
      laborLines: state.laborLines.where((l) => l.id != id).toList(),
      clearErrorMessage: true,
    );
  }

  /// Assigns the mechanic for this ticket (snapshots the name).
  void setMechanic(String id, String name) {
    state = state.copyWith(
      mechanicId: id,
      mechanicName: name,
      clearErrorMessage: true,
    );
  }

  /// Clears the assigned mechanic.
  void clearMechanic() {
    state = state.copyWith(clearMechanic: true, clearErrorMessage: true);
  }
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/cart_provider_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_provider_test.dart && git commit -m "feat(cart): add addLaborLine/updateLaborLine/removeLaborLine/setMechanic/clearMechanic to CartNotifier"`

---

### Task 17: Carry labor + mechanic through `loadFromDraft`, `toDraft`, and `toSale`

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_provider_test.dart`

> Depends on Plan 2 Phase 2: `DraftEntity` and `SaleEntity` constructors accept `laborLines` / `mechanicId` / `mechanicName`, and `DraftEntity` carries them in `props`.

- [ ] **Step 1: Write the failing test** — append these tests inside the existing `group('CartNotifier', ...)` block in `test/presentation/providers/cart_provider_test.dart`:

```dart
    test('loadFromDraft copies laborLines and mechanic into the cart', () {
      final draft = DraftEntity(
        id: 'draft-1',
        name: 'Service job',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            unitPrice: 100,
            unitCost: 60,
            quantity: 1,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan',
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John',
        createdAt: DateTime.now(),
      );

      cartNotifier.loadFromDraft(draft);

      final state = container.read(cartProvider);
      expect(state.laborLines.length, 1);
      expect(state.laborLines.first.description, 'Tune-up');
      expect(state.laborLines.first.fee, 300);
      expect(state.mechanicId, 'mech-1');
      expect(state.mechanicName, 'Juan');
    });

    test('toDraft carries laborLines and mechanic', () {
      cartNotifier.addProduct(createTestProduct());
      cartNotifier.addLaborLine(description: 'Brake bleed', fee: 150);
      cartNotifier.setMechanic('mech-2', 'Pedro');

      final draft = cartNotifier.toDraft(
        name: 'My Draft',
        createdBy: 'user-1',
        createdByName: 'John Doe',
      );

      expect(draft.laborLines.length, 1);
      expect(draft.laborLines.first.description, 'Brake bleed');
      expect(draft.laborLines.first.fee, 150);
      expect(draft.mechanicId, 'mech-2');
      expect(draft.mechanicName, 'Pedro');
      // grandTotal includes labor: parts 100 + labor 150
      expect(draft.grandTotal, 250);
    });

    test('toSale carries laborLines and mechanic', () {
      cartNotifier.addProduct(createTestProduct(price: 100));
      cartNotifier.addLaborLine(description: 'Tune-up', fee: 200);
      cartNotifier.setMechanic('mech-3', 'Maria');
      cartNotifier.setAmountReceived(300);

      final sale = cartNotifier.toSale(
        saleNumber: 'SALE-001',
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
      );

      expect(sale.laborLines.length, 1);
      expect(sale.laborLines.first.fee, 200);
      expect(sale.mechanicId, 'mech-3');
      expect(sale.mechanicName, 'Maria');
      // grandTotal includes labor: parts 100 + labor 200
      expect(sale.grandTotal, 300);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/cart_provider_test.dart`. Expect failures: `loadFromDraft` does not set `laborLines`/`mechanicId`/`mechanicName` (so `state.laborLines` is empty / mechanic null), and `toDraft`/`toSale` produce entities with empty `laborLines` and null mechanic, so the labor/mechanic and `grandTotal` expectations fail.

- [ ] **Step 3: Implement** — in `lib/presentation/providers/cart_provider.dart`, replace the body of `loadFromDraft` (lines 440-449) so the new `CartState(...)` includes labor + mechanic:

```dart
  void loadFromDraft(DraftEntity draft) {
    state = CartState(
      items: List<SaleItemEntity>.from(draft.items),
      discountType: draft.discountType,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      notes: draft.notes,
      draftName: draft.name,
      laborLines: List<LaborLineEntity>.from(draft.laborLines),
      mechanicId: draft.mechanicId,
      mechanicName: draft.mechanicName,
    );
  }
```

Replace the `toDraft` return (lines 457-466) so the `DraftEntity(...)` passes labor + mechanic:

```dart
    return DraftEntity(
      id: state.sourceDraftId ?? '',
      name: name,
      items: state.items,
      discountType: state.discountType,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      notes: state.notes,
      laborLines: state.laborLines,
      mechanicId: state.mechanicId,
      mechanicName: state.mechanicName,
    );
```

Replace the `toSale` return (lines 475-489) so the `SaleEntity(...)` passes labor + mechanic:

```dart
    return SaleEntity(
      id: '',
      saleNumber: saleNumber,
      items: state.items,
      discountType: state.discountType,
      paymentMethod: state.paymentMethod,
      tenders: state.tenders,
      amountReceived: state.collectedToday,
      changeGiven: state.change,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: state.sourceDraftId,
      notes: state.notes,
      laborLines: state.laborLines,
      mechanicId: state.mechanicId,
      mechanicName: state.mechanicName,
    );
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/cart_provider_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_provider_test.dart && git commit -m "feat(cart): carry labor lines + mechanic through loadFromDraft/toDraft/toSale"`

---

### Task 18: Update existing tender tests for labor-inclusive `grandTotal`

**Files:**
- Test: `test/presentation/providers/cart_tenders_test.dart`

> The five-way `grandTotal` change is labor-inclusive. The existing tender tests build a parts-only cart (`grandTotal = 1000` with no labor), so their numbers are unchanged — but we add an explicit labor case proving tenders/`collectedToday`/`change` are computed over the labor-inclusive total (decision #9: drawer holds labor cash). This guards against a regression where tenders are accidentally computed over `partsRevenue` instead of `grandTotal`.

- [ ] **Step 1: Write the failing test** — append this test inside `main()` in `test/presentation/providers/cart_tenders_test.dart` (after the salmon test closes on line 60, before `main`'s closing `}` on line 61):

```dart
  test('labor raises grandTotal so cash tender + change track the total', () {
    // base cart from setUp: parts grandTotal = 1000
    cart.addLaborLine(description: 'Tune-up', fee: 500); // grandTotal -> 1500
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(2000);

    expect(cart.state.grandTotal, 1500);
    expect(cart.state.tenders, {PaymentMethod.cash: 1500});
    expect(cart.state.change, 500);
    expect(cart.state.isPaymentValid, true);
  });

  test('mixed split is taken over the labor-inclusive grandTotal', () {
    cart.addLaborLine(description: 'Labor', fee: 500); // grandTotal -> 1500
    cart.setPaymentMethod(PaymentMethod.mixed);
    cart.setSecondaryMethod(PaymentMethod.gcash);
    cart.setSplitAmount(600);

    expect(cart.state.tenders,
        {PaymentMethod.cash: 900, PaymentMethod.gcash: 600});
    expect(cart.state.isPaymentValid, true);
  });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/cart_tenders_test.dart`. Before the cart slice is implemented this fails to compile (`addLaborLine` undefined); after the earlier cart tasks land it must pass. Run as part of the full cart-slice sweep.

- [ ] **Step 3: Implement** — no production code in this task; the behavior is delivered by the `CartState`/`CartNotifier` tasks above. The two added tests are the deliverable (verifying tenders/change derive from the labor-inclusive `grandTotal`).

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/cart_tenders_test.dart test/presentation/providers/cart_provider_test.dart`

- [ ] **Step 5: Commit** — `git add test/presentation/providers/cart_tenders_test.dart && git commit -m "test(cart): tenders/change derive from labor-inclusive grandTotal"`



<!-- slice: G-pos-checkout-ui (POS cart + checkout + receipt UI + validation) -->

### Task 19: Mechanic picker dropdown (POS)

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/mechanic_picker.dart`
- Test: `test/presentation/widgets/mechanic_picker_test.dart`

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';

MechanicEntity _mech(String id, String name) => MechanicEntity(
      id: id,
      name: name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('MechanicPicker', () {
    testWidgets('renders active mechanic names in the dropdown menu',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMechanicsProvider.overrideWith(
              (ref) => Stream.value([
                _mech('m1', 'Juan Dela Cruz'),
                _mech('m2', 'Pedro Santos'),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MechanicPicker()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Closed dropdown shows the label.
      expect(find.text('Mechanic'), findsOneWidget);

      // Open the menu and confirm both names render.
      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      expect(find.text('Juan Dela Cruz'), findsWidgets);
      expect(find.text('Pedro Santos'), findsWidgets);
    });

    testWidgets('selecting a mechanic calls cart.setMechanic', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMechanicsProvider.overrideWith(
              (ref) => Stream.value([_mech('m1', 'Juan Dela Cruz')]),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(body: MechanicPicker()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Dela Cruz').last);
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart.mechanicId, 'm1');
      expect(cart.mechanicName, 'Juan Dela Cruz');
    });

    testWidgets('shows a hint when no active mechanics are configured',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMechanicsProvider
                .overrideWith((ref) => Stream.value(<MechanicEntity>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MechanicPicker()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No mechanics configured'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/mechanic_picker_test.dart`. Fails to compile: `Target of URI doesn't exist: '.../mechanic_picker.dart'` (the widget file does not exist yet).

- [ ] **Step 3: Implement** (full real code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Cashier-facing dropdown that assigns a single mechanic to the whole
/// ticket. Watches [activeMechanicsProvider] (active list only — deactivated
/// mechanics drop off but stay valid on history via the snapshot) and writes
/// the selection straight to the cart via [CartNotifier.setMechanic] /
/// [CartNotifier.clearMechanic]. Modeled on the void-reason dropdown.
class MechanicPicker extends ConsumerWidget {
  const MechanicPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mechanicsAsync = ref.watch(activeMechanicsProvider);
    final selectedId = ref.watch(
      cartProvider.select((c) => c.mechanicId),
    );

    return mechanicsAsync.when(
      data: (mechanics) {
        if (mechanics.isEmpty) {
          return Text(
            'No mechanics configured. Ask an admin to add one under '
            'Settings → Mechanics.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        // Reset the visible value if the assigned mechanic was deactivated.
        final ids = mechanics.map((m) => m.id).toSet();
        final currentValue =
            (selectedId != null && ids.contains(selectedId)) ? selectedId : null;
        return AppDropdown<String>(
          initialValue: currentValue,
          decoration: const InputDecoration(
            labelText: 'Mechanic',
            prefixIcon: Icon(CupertinoIcons.person),
          ),
          items: mechanics
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m.id,
                  child: Text(m.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            final notifier = ref.read(cartProvider.notifier);
            if (value == null) {
              notifier.clearMechanic();
              return;
            }
            final picked = mechanics.firstWhere((m) => m.id == value);
            notifier.setMechanic(picked.id, picked.name);
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => Text(
        'Could not load mechanics',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: AppColors.error),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/mechanic_picker_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/widgets/pos/mechanic_picker.dart test/presentation/widgets/mechanic_picker_test.dart && git commit -m "feat(pos): add mechanic picker dropdown bound to cart"`

---

### Task 20: Labor line tile (display + edit a single labor line)

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/labor_line_tile.dart`
- Test: `test/presentation/widgets/labor_line_tile_test.dart`

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_tile.dart';

void main() {
  const line = LaborLineEntity(
    id: 'l1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  Widget host({
    void Function(String, double)? onEdited,
    VoidCallback? onRemove,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: LaborLineTile(
            line: line,
            onEdited: onEdited ?? (_, __) {},
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  group('LaborLineTile', () {
    testWidgets('renders description and fee, no discount affordance',
        (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Engine tune-up'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget);
      // Labor never carries a discount control.
      expect(find.byIcon(CupertinoIcons.tag), findsNothing);
    });

    testWidgets('calls onRemove when dismissed', (tester) async {
      var removed = false;
      await tester.pumpWidget(host(onRemove: () => removed = true));

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(removed, true);
    });

    testWidgets('edit dialog reports new description and fee', (tester) async {
      String? newDesc;
      double? newFee;
      await tester.pumpWidget(host(onEdited: (d, f) {
        newDesc = d;
        newFee = f;
      }));

      await tester.tap(find.byIcon(CupertinoIcons.pencil));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Brake bleed');
      await tester.enterText(
          find.byKey(const Key('labor-fee-field')), '300');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(newDesc, 'Brake bleed');
      expect(newFee, 300.0);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/labor_line_tile_test.dart`. Fails to compile: `Target of URI doesn't exist: '.../labor_line_tile.dart'`.

- [ ] **Step 3: Implement** (full real code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// A single labor/service line in the cart. Mirrors [CartItemTile] but with
/// no quantity stepper and — deliberately — no discount control: labor is
/// full price by construction (decision #4 in the spec).
///
/// Tapping the pencil opens an edit dialog that reports the new
/// `(description, fee)` via [onEdited]; swipe-to-dismiss reports [onRemove].
class LaborLineTile extends StatelessWidget {
  final LaborLineEntity line;
  final void Function(String description, double fee) onEdited;
  final VoidCallback onRemove;

  const LaborLineTile({
    super.key,
    required this.line,
    required this.onEdited,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: Key('labor-${line.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg - 4),
        color: AppColors.error,
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              Icon(CupertinoIcons.wrench, size: 18, color: muted),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Text(
                  line.description.isEmpty ? 'Service' : line.description,
                  style: AppTextStyles.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.pencil, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit labor line',
                onPressed: () => _showEditDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final descController = TextEditingController(text: line.description);
    final feeController = TextEditingController(
      text: line.fee > 0 ? line.fee.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Labor / Service'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('labor-desc-field'),
                controller: descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Engine tune-up',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('labor-fee-field'),
                controller: feeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Fee',
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Fee must be greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      onEdited(
        descController.text.trim(),
        double.parse(feeController.text.trim()),
      );
    }
    descController.dispose();
    feeController.dispose();
  }
}
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/labor_line_tile_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/widgets/pos/labor_line_tile.dart test/presentation/widgets/labor_line_tile_test.dart && git commit -m "feat(pos): add labor line tile with inline edit dialog"`

---

### Task 21: Labor validation getters on CartState

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_labor_validation_test.dart`

This adds the UI-facing checkout/save gates for labor. The labor fields/getters/notifier methods (`laborLines`, `mechanicId`, `mechanicName`, `addLaborLine`, `setMechanic`) come from the earlier cart phase; this task only adds the validation that blocks checkout/save when labor exists without a mechanic or with a non-positive fee, and wires those into `canCheckout` / `canSaveAsDraft`.

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Spark Plug',
      price: 100,
      cost: 60,
      quantity: 10,
      unit: 'pcs',
    );

void main() {
  late ProviderContainer container;
  late CartNotifier cart;

  setUp(() {
    container = ProviderContainer();
    cart = container.read(cartProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('CartState labor validation', () {
    test('laborValid is true when there are no labor lines', () {
      cart.addProduct(_product());
      expect(container.read(cartProvider).laborValid, isTrue);
    });

    test('labor present but no mechanic -> invalid, blocks save and checkout',
        () {
      cart.addProduct(_product());
      cart.setAmountReceived(1000);
      cart.addLaborLine(description: 'Tune-up', fee: 450);

      final state = container.read(cartProvider);
      expect(state.laborValid, isFalse);
      expect(state.laborValidationError, isNotNull);
      expect(state.canSaveAsDraft, isFalse);
      expect(state.canCheckout, isFalse);
    });

    test('labor with mechanic and positive fee -> valid', () {
      cart.addProduct(_product());
      cart.setAmountReceived(1000);
      cart.addLaborLine(description: 'Tune-up', fee: 450);
      cart.setMechanic('m1', 'Juan');

      final state = container.read(cartProvider);
      expect(state.laborValid, isTrue);
      expect(state.canSaveAsDraft, isTrue);
      expect(state.canCheckout, isTrue);
    });

    test('a zero-fee labor line invalidates even with a mechanic', () {
      cart.addProduct(_product());
      cart.setMechanic('m1', 'Juan');
      cart.addLaborLine(description: 'Freebie', fee: 0);

      final state = container.read(cartProvider);
      expect(state.laborValid, isFalse);
      expect(state.canSaveAsDraft, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/cart_labor_validation_test.dart`. Fails: `The getter 'laborValid' isn't defined for the type 'CartState'` (and `laborValidationError`).

- [ ] **Step 3: Implement** — add the getters to `CartState` and fold them into the existing gates. The current code reads:

```dart
  /// Whether cart can be checked out
  bool get canCheckout => isNotEmpty && isPaymentValid && !isProcessing;

  /// Whether cart can be saved as draft
  bool get canSaveAsDraft => isNotEmpty && !isProcessing;
```

Replace that block with:

```dart
  /// Whether the labor section is internally consistent:
  /// - if any labor line exists, a mechanic must be assigned, and
  /// - every labor fee must be greater than zero.
  /// Empty labor (the normal merchandise sale) is always valid.
  bool get laborValid {
    if (laborLines.isEmpty) return true;
    if (mechanicId == null || mechanicId!.isEmpty) return false;
    return laborLines.every((l) => l.fee > 0);
  }

  /// Human-readable reason labor is invalid, or null when [laborValid].
  String? get laborValidationError {
    if (laborLines.isEmpty) return null;
    if (mechanicId == null || mechanicId!.isEmpty) {
      return 'Assign a mechanic before saving labor.';
    }
    if (laborLines.any((l) => l.fee <= 0)) {
      return 'Each labor fee must be greater than ₱0.';
    }
    return null;
  }

  /// Whether cart can be checked out
  bool get canCheckout =>
      isNotEmpty && isPaymentValid && laborValid && !isProcessing;

  /// Whether cart can be saved as draft
  bool get canSaveAsDraft => isNotEmpty && laborValid && !isProcessing;
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/cart_labor_validation_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_labor_validation_test.dart && git commit -m "feat(cart): gate checkout/save on labor-mechanic validity"`

---

### Task 22: Labor & Service section in the POS cart

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart`
- Test: `test/presentation/widgets/pos_labor_section_test.dart`

Adds a collapsible "Labor & Service" `ExpansionTile` below the items list in `_buildCartSection`, containing the `MechanicPicker`, the list of `LaborLineTile`s, an "Add labor line" button, and an inline validation banner driven by `cart.laborValidationError`.

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/pos_screen.dart';

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Spark Plug',
      price: 100,
      cost: 60,
      quantity: 10,
      unit: 'pcs',
    );

void main() {
  Widget host(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RoutePaths.pos,
          routes: [
            GoRoute(
              path: RoutePaths.pos,
              builder: (_, __) => const POSScreen(),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('Labor & Service section appears with a mechanic picker',
      (tester) async {
    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith(
        (ref) => Stream.value(<MechanicEntity>[]),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addProduct(_product());

    await tester.pumpWidget(host(container));
    await tester.pumpAndSettle();

    expect(find.text('Labor & Service'), findsOneWidget);

    // Expand the section; the (empty) mechanic-picker hint should render.
    await tester.tap(find.text('Labor & Service'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No mechanics configured'), findsOneWidget);
    expect(find.text('Add labor line'), findsOneWidget);
  });

  testWidgets('shows the labor validation banner when a mechanic is missing',
      (tester) async {
    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith(
        (ref) => Stream.value([
          MechanicEntity(
            id: 'm1',
            name: 'Juan',
            isActive: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        ]),
      ),
    ]);
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(_product());
    cart.addLaborLine(description: 'Tune-up', fee: 450);

    await tester.pumpWidget(host(container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labor & Service'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Assign a mechanic'), findsOneWidget);
    // Save-as-Draft is gated off while labor is invalid.
    final saveButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Save as Draft'),
    );
    expect(saveButton.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/pos_labor_section_test.dart`. Fails: `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets>` for `'Labor & Service'` (section not built yet).

- [ ] **Step 3: Implement** — add imports and the new section. First add imports near the existing pos imports (after the `cart_summary.dart` import on line 14):

```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
```

Then, in `_buildCartSection`, the current scrollable `Column` ends with the summary:

```dart
                      const Divider(height: 1),

                      // Cart Summary — payment is now collected on the
                      // dedicated Checkout screen, not inline.
                      CartSummary(cart: cart),
                    ],
                  ),
                ),
```

Insert the labor section between the divider and the summary:

```dart
                      const Divider(height: 1),

                      // Labor & Service — collapsible; empty for normal sales.
                      _buildLaborSection(cart),

                      const Divider(height: 1),

                      // Cart Summary — payment is now collected on the
                      // dedicated Checkout screen, not inline.
                      CartSummary(cart: cart),
                    ],
                  ),
                ),
```

Add the builder method and handlers (place after `_buildEmptyCart`):

```dart
  /// Collapsible "Labor & Service" block: mechanic picker + editable
  /// labor lines + an inline validity banner. Starts expanded when labor
  /// already exists so the cashier sees it on a reloaded service draft.
  Widget _buildLaborSection(CartState cart) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Theme(
      // Strip the ExpansionTile's default dividers so it sits flush in the
      // surrounding scroll column.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: cart.laborLines.isNotEmpty,
        leading: const Icon(CupertinoIcons.wrench),
        title: const Text('Labor & Service'),
        subtitle: cart.laborLines.isEmpty
            ? Text(
                'Optional — add mechanic labor',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              )
            : Text(
                '${cart.laborLines.length} service(s) • '
                '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          const MechanicPicker(),
          const SizedBox(height: AppSpacing.sm),
          ...cart.laborLines.map(
            (line) => LaborLineTile(
              line: line,
              onEdited: (description, fee) => ref
                  .read(cartProvider.notifier)
                  .updateLaborLine(line.id, description: description, fee: fee),
              onRemove: () =>
                  ref.read(cartProvider.notifier).removeLaborLine(line.id),
            ),
          ),
          if (cart.laborValidationError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildLaborError(cart.laborValidationError!),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddLaborDialog,
              icon: const Icon(CupertinoIcons.add),
              label: const Text('Add labor line'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaborError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLaborDialog() {
    final descController = TextEditingController();
    final feeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Labor / Service'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Engine tune-up',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: feeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Fee',
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Fee must be greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(cartProvider.notifier).addLaborLine(
                    description: descController.text.trim(),
                    fee: double.parse(feeController.text.trim()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
```

Add the missing `FilteringTextInputFormatter` import — `package:flutter/services.dart` is already imported on line 3, so no change is needed there.

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/pos_labor_section_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/pos/pos_screen.dart test/presentation/widgets/pos_labor_section_test.dart && git commit -m "feat(pos): collapsible Labor & Service section in cart"`

---

### Task 23: Labor subtotal row in CartSummary

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/cart_summary.dart`
- Test: `test/presentation/widgets/cart_summary_labor_test.dart`

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_summary.dart';

const _item = SaleItemEntity(
  id: 'i1',
  productId: 'p1',
  sku: 'SKU-1',
  name: 'Spark Plug',
  unitPrice: 100,
  unitCost: 60,
  quantity: 2,
  unit: 'pcs',
);

const _labor = LaborLineEntity(id: 'l1', description: 'Tune-up', fee: 450);

Widget _host(CartState cart) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: CartSummary(cart: cart))),
    );

void main() {
  group('CartSummary labor row', () {
    testWidgets('hides the labor row when there are no labor lines',
        (tester) async {
      await tester.pumpWidget(_host(const CartState(items: [_item])));
      expect(find.text('Labor'), findsNothing);
      // Grand total == parts only (₱200.00).
      expect(find.text('₱200.00'), findsOneWidget);
    });

    testWidgets('shows a labor subtotal row and a labor-inclusive total',
        (tester) async {
      await tester.pumpWidget(
        _host(const CartState(items: [_item], laborLines: [_labor])),
      );
      expect(find.text('Labor'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget); // labor subtotal
      expect(find.text('₱650.00'), findsOneWidget); // grand total (200 + 450)
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/cart_summary_labor_test.dart`. Fails: the `'Labor'` row is found nowhere and the total still reads `₱200.00` instead of `₱650.00` (grandTotal not yet labor-inclusive / no labor row).

- [ ] **Step 3: Implement** — the current discount block (lines 33-41) ends just before the divider. Insert a labor row after the discount block. Replace:

```dart
          if (cart.hasDiscount) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              context,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successDark,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
```

with:

```dart
          if (cart.hasDiscount) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              context,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successDark,
            ),
          ],
          if (cart.laborLines.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              context,
              'Labor',
              '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/cart_summary_labor_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/widgets/pos/cart_summary.dart test/presentation/widgets/cart_summary_labor_test.dart && git commit -m "feat(pos): show labor subtotal row in cart summary"`

---

### Task 24: Labor lines + labor subtotal + mechanic in checkout summary

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart`
- Test: `test/presentation/widgets/checkout_labor_test.dart`

Renders labor lines after products in `_buildItemsList` (description + fee, no discount affordance) and adds a "Labor (n services)" row plus a "Mechanic: <name>" line to `_buildPaymentSummary`. `grandTotal` is already labor-inclusive after the domain changes.

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/checkout_screen.dart';

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Spark Plug',
      price: 100,
      cost: 60,
      quantity: 10,
      unit: 'pcs',
    );

void main() {
  testWidgets('checkout renders labor line, labor subtotal and mechanic',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(_product());
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(1000);
    cart.addLaborLine(description: 'Engine tune-up', fee: 450);
    cart.setMechanic('m1', 'Juan Dela Cruz');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Labor line appears in the order list.
    expect(find.text('Engine tune-up'), findsOneWidget);
    // Labor subtotal row + mechanic line in the payment summary.
    expect(find.textContaining('Labor (1 service'), findsOneWidget);
    expect(find.textContaining('Mechanic: Juan Dela Cruz'), findsOneWidget);
    // Grand total is labor-inclusive: 100 + 450 = 550.
    expect(find.textContaining('₱550.00'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/checkout_labor_test.dart`. Fails: `'Engine tune-up'` and `'Labor (1 service'` are not found (labor not rendered in checkout yet).

- [ ] **Step 3: Implement** — in `_buildItemsList`, the items column currently ends with `...cart.items.asMap().entries.map(...)`. After that mapped list (right before the closing `]` of the `Column`'s `children`), append the labor rows. The current closing reads:

```dart
            );
          }),
        ],
      ),
    );
  }
```

Replace with:

```dart
            );
          }),
          ...cart.laborLines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final isLast = index == cart.laborLines.length - 1;
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Icon(
                      CupertinoIcons.wrench,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      line.description.isEmpty ? 'Service' : line.description,
                      style: AppTextStyles.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
```

(The `hairline` local already exists at the top of `_buildItemsList`, and `CupertinoIcons` is imported on line 2.)

Next, in `_buildPaymentSummary`, the current discount block ends just before the divider:

```dart
            if (cart.hasDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Discount',
                '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
              child: Divider(height: 1),
            ),
```

Replace with:

```dart
            if (cart.hasDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Discount',
                '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            if (cart.laborLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Labor (${cart.laborLines.length} '
                    'service${cart.laborLines.length == 1 ? '' : 's'})',
                '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
              ),
              if (cart.mechanicName != null &&
                  cart.mechanicName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mechanic: ${cart.mechanicName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
              child: Divider(height: 1),
            ),
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/checkout_labor_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/pos/checkout_screen.dart test/presentation/widgets/checkout_labor_test.dart && git commit -m "feat(checkout): render labor lines, subtotal and mechanic"`

---

### Task 25: Labor section + subtotal + mechanic on the receipt

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/receipt_widget.dart`
- Test: `test/presentation/widgets/receipt_labor_test.dart`

Prints a labor section (mechanic, description, fee) after products in `_buildItemsSection`, a labor subtotal line in `_buildTotalsSection`, and a `Mechanic: <name>` line in `_buildTransactionInfo` when present.

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';

SaleEntity _sale() => SaleEntity(
      id: 's1',
      saleNumber: 'OR-0001',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Spark Plug',
          unitPrice: 100,
          unitCost: 60,
          quantity: 1,
          unit: 'pcs',
        ),
      ],
      laborLines: const [
        LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450),
      ],
      mechanicId: 'm1',
      mechanicName: 'Juan Dela Cruz',
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      tenders: const {PaymentMethod.cash: 550},
      amountReceived: 1000,
      changeGiven: 450,
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 5, 30, 10, 0),
    );

void main() {
  testWidgets('receipt prints labor section, subtotal and mechanic',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ReceiptWidget(sale: _sale())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.textContaining('Mechanic'), findsWidgets);
    expect(find.textContaining('Juan Dela Cruz'), findsOneWidget);
    // Labor subtotal in totals section + labor-inclusive grand total.
    expect(find.text('₱450.00'), findsWidgets); // labor subtotal
    expect(find.text('₱550.00'), findsWidgets); // TOTAL = 100 + 450
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/receipt_labor_test.dart`. Fails: `'Engine tune-up'` and `'Juan Dela Cruz'` are not found (labor not printed on the receipt yet).

- [ ] **Step 3: Implement** — three edits.

(a) `_buildTransactionInfo` (currently ends after the payment row). Replace:

```dart
        if (sale.paymentMethod.displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInfoRow('Payment', sale.paymentMethod.displayName),
        ],
      ],
    );
  }
```

with:

```dart
        if (sale.paymentMethod.displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInfoRow('Payment', sale.paymentMethod.displayName),
        ],
        if (sale.mechanicName != null && sale.mechanicName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInfoRow('Mechanic', sale.mechanicName!),
        ],
      ],
    );
  }
```

(b) `_buildItemsSection` — append a labor block after the items `.map(...)`. The method currently closes:

```dart
          );
        }),
      ],
    );
  }
```

Replace with:

```dart
          );
        }),
        if (sale.laborLines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'LABOR / SERVICE',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: _ReceiptColors.label,
            ),
          ),
          const SizedBox(height: 4),
          ...sale.laborLines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      line.description.isEmpty ? 'Service' : line.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
```

(c) `_buildTotalsSection` — add a labor subtotal line before the grand total. The method currently reads:

```dart
  Widget _buildTotalsSection(ThemeData theme) {
    return Column(
      children: [
        _buildTotalRow('Subtotal', sale.subtotal),
        if (sale.hasDiscount) ...[
          const SizedBox(height: 4),
          _buildTotalRow('Discount', -sale.totalDiscount, isDiscount: true),
        ],
        const SizedBox(height: AppSpacing.sm),
        _buildTotalRow('TOTAL', sale.grandTotal, isGrandTotal: true),
      ],
    );
  }
```

Replace with:

```dart
  Widget _buildTotalsSection(ThemeData theme) {
    return Column(
      children: [
        _buildTotalRow('Subtotal', sale.subtotal),
        if (sale.hasDiscount) ...[
          const SizedBox(height: 4),
          _buildTotalRow('Discount', -sale.totalDiscount, isDiscount: true),
        ],
        if (sale.laborLines.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildTotalRow('Labor', sale.laborSubtotal),
        ],
        const SizedBox(height: AppSpacing.sm),
        _buildTotalRow('TOTAL', sale.grandTotal, isGrandTotal: true),
      ],
    );
  }
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/receipt_labor_test.dart`

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/widgets/pos/receipt_widget.dart test/presentation/widgets/receipt_labor_test.dart && git commit -m "feat(receipt): print labor section, subtotal and mechanic"`

---

Notes for the orchestrator on cross-slice dependencies (file paths absolute):
- These tasks consume APIs delivered by earlier phases (Plan 1 / cart Phase 5): `MechanicEntity` + `activeMechanicsProvider` (`/Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/lib/presentation/providers/mechanic_provider.dart`), `LaborLineEntity` (`/Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/lib/domain/entities/labor_line_entity.dart`), and the `CartNotifier` methods `addLaborLine`/`updateLaborLine`/`removeLaborLine`/`setMechanic`/`clearMechanic` plus `CartState.laborLines`/`mechanicId`/`mechanicName`/`laborSubtotal`/labor-inclusive `grandTotal` in `/Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/lib/presentation/providers/cart_provider.dart`. None of these exist on disk yet (confirmed: `mechanic_picker.dart`, `mechanic_provider.dart`, and `labor_line_entity.dart` are absent), so these tasks must be sequenced after those phases.
- The "Labor validation getters" task is the only one in this slice that edits `cart_provider.dart`; it must run after the cart-fields phase adds `laborLines`/`mechanicId`. It deliberately owns only the `laborValid`/`laborValidationError` getters and the `canCheckout`/`canSaveAsDraft` wiring (the spec assigns checkout/save blocking to this slice).
- The picker is modeled on the void-reason dropdown (`AppDropdown<String>` from `/Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos/lib/presentation/shared/widgets/common/app_dropdown.dart`), exactly as the spec §5.1 requests.



<!-- slice: H-drafts-sales-ui (Drafts + sale-detail UI) -->

### Task 26: Render an editable labor & mechanic section in the draft editor

**Files:**
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart`
- Test: `test/presentation/widgets/draft_edit_screen_labor_test.dart` (create)

This task makes `DraftEditScreen` render a mechanic picker + a labor-line list (add/edit/remove) and a labor subtotal in the summary. Because the screen never mutates the draft directly (it only *consumes* the draft into the cart on "Edit in POS" / "Checkout"), labor edits must persist through the **full `updateDraft` path** — we hold a local working `DraftEntity` copy and call `draftOperationsProvider.notifier.updateDraft(...)` after each labor mutation. We do NOT use `updateDraftItems` (it writes only the `items` field and would drop labor).

- [ ] **Step 1: Write the failing test** (full real test code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';

void main() {
  DraftEntity buildDraft({List<LaborLineEntity> labor = const []}) => DraftEntity(
        id: 'draft-1',
        name: 'Plate ABC-123',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: labor,
        mechanicName: labor.isEmpty ? null : 'Juan Dela Cruz',
        mechanicId: labor.isEmpty ? null : 'mech-1',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith(
            (ref) => Stream.value(const [
              MechanicEntity(
                id: 'mech-1',
                name: 'Juan Dela Cruz',
                isActive: true,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  testWidgets('renders Labor & Service section header and mechanic picker',
      (tester) async {
    await tester.pumpWidget(harness(buildDraft()));
    await tester.pumpAndSettle();

    expect(find.text('Labor & Service'), findsOneWidget);
    expect(find.byType(MechanicPicker), findsOneWidget);
    // Add-labor affordance is present even with no labor lines.
    expect(find.text('Add Labor'), findsOneWidget);
  });

  testWidgets('shows labor subtotal and grand total includes labor',
      (tester) async {
    final draft = buildDraft(labor: const [
      LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
    ]);
    await tester.pumpWidget(harness(draft));
    await tester.pumpAndSettle();

    // Labor line is rendered with its description and fee.
    expect(find.text('Engine tune-up'), findsOneWidget);
    // Labor subtotal row label.
    expect(find.text('Labor (1 service)'), findsOneWidget);
    // Grand total = parts 200 + labor 450 = 650.00 (appears in summary).
    expect(find.textContaining('650.00'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/draft_edit_screen_labor_test.dart`. Fails to compile/find: `MechanicPicker` not imported in the screen and no "Labor & Service" / "Add Labor" / "Labor (1 service)" text rendered.

- [ ] **Step 3: Implement** — In `draft_edit_screen.dart`, (a) add the import, (b) add a working-copy field + helpers, (c) insert the labor section between the items list and the summary, (d) extend `_buildSummarySection` with a labor subtotal row.

Add the picker import near the top (after the `common_widgets` import on line 13):

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
```

Add a working-copy field and seed it from the loaded draft. Replace the class state header (lines 28–31):

```dart
class _DraftEditScreenState extends ConsumerState<DraftEditScreen> {
  bool _isLoading = false;
  bool _isDeleting = false;

  /// Local working copy so labor/mechanic edits render instantly; each edit is
  /// persisted through the FULL updateDraft path (NOT updateDraftItems, which
  /// writes only `items` and would drop labor).
  DraftEntity? _working;

  DraftEntity _sync(DraftEntity fromProvider) {
    // Keep the working copy in step with the provider unless we already hold a
    // newer local edit for this same draft id.
    final current = _working;
    if (current == null || current.id != fromProvider.id) {
      _working = fromProvider;
    }
    return _working!;
  }

  Future<void> _persistLabor(DraftEntity next) async {
    setState(() => _working = next);
    final actor = ref.read(currentUserProvider).valueOrNull;
    if (actor == null) return;
    await ref
        .read(draftOperationsProvider.notifier)
        .updateDraft(actor: actor, draft: next);
  }

  void _onMechanicChanged(String? id, String? name) {
    final base = _working;
    if (base == null) return;
    final next = (id == null)
        ? base.copyWith(clearMechanic: true, updatedAt: DateTime.now())
        : base.copyWith(
            mechanicId: id, mechanicName: name, updatedAt: DateTime.now());
    _persistLabor(next);
  }

  Future<void> _addOrEditLabor(DraftEntity draft, [LaborLineEntity? existing]) async {
    final result = await showDialog<LaborLineEntity>(
      context: context,
      builder: (_) => _LaborLineDialog(line: existing),
    );
    if (result == null) return;
    final next = existing == null
        ? draft.addLaborLine(result)
        : draft.updateLaborLine(result);
    await _persistLabor(next);
  }

  Future<void> _removeLabor(DraftEntity draft, String lineId) async {
    await _persistLabor(draft.removeLaborLine(lineId));
  }
```

Wire the working copy into `build`'s `data:` branch. Replace the `data:` callback body (lines 51–67) so the working copy seeds from the provider value:

```dart
      data: (draft) {
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Draft Not Found')),
            body: EmptyStateView(
              icon: Icons.search_off,
              title: 'Draft not found or has been deleted',
              action: ElevatedButton(
                onPressed: () => context.go(RoutePaths.drafts),
                child: const Text('Back to Drafts'),
              ),
            ),
          );
        }

        return _buildDraftContent(_sync(draft));
      },
```

Insert the labor section in `_buildDraftContent`'s body `Column`, between the items `Expanded` (ends line 163) and `_buildSummarySection(draft)` (line 166). Replace those two with:

```dart
            // Items list
            Expanded(
              child: draft.items.isEmpty
                  ? _buildEmptyItems()
                  : ListView.builder(
                      itemCount: draft.items.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        return _buildDraftItem(draft.items[index]);
                      },
                    ),
            ),

            // Labor & Service (mechanic + labor lines) — editable anytime.
            _buildLaborSection(draft),

            // Summary and actions
            _buildSummarySection(draft),
```

Add the labor section builder and a labor-line tile builder (place after `_buildDraftItem`, before `_buildSummarySection`):

```dart
  Widget _buildLaborSection(DraftEntity draft) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.wrench, size: 16, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Labor & Service',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addOrEditLabor(draft),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('Add Labor'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          MechanicPicker(
            mechanicId: draft.mechanicId,
            onChanged: _onMechanicChanged,
          ),
          ...draft.laborLines.map((line) => _buildLaborLineRow(draft, line)),
        ],
      ),
    );
  }

  Widget _buildLaborLineRow(DraftEntity draft, LaborLineEntity line) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(CupertinoIcons.wrench, size: 14, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: () => _addOrEditLabor(draft, line),
              child: Text(
                line.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark, size: 16),
            visualDensity: VisualDensity.compact,
            color: muted,
            onPressed: () => _removeLabor(draft, line.id),
            tooltip: 'Remove labor line',
          ),
        ],
      ),
    );
  }
```

Extend `_buildSummarySection` to add the labor subtotal row. Replace the block from the discount `if` through the `Divider` (lines 279–287) with:

```dart
            if (draft.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              _buildSummaryRow(
                'Discount',
                '-${AppConstants.currencySymbol}${draft.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            if (draft.laborLines.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildSummaryRow(
                draft.laborLines.length == 1
                    ? 'Labor (1 service)'
                    : 'Labor (${draft.laborLines.length} services)',
                '${AppConstants.currencySymbol}${draft.laborSubtotal.toStringAsFixed(2)}',
              ),
            ],
            const Divider(height: AppSpacing.md),
```

Add the labor-line editor dialog at the bottom of the file (after the `_DraftEditScreenState` class closes):

```dart
/// Add/edit a single free-form labor line (description + fee). Fee must be > 0.
class _LaborLineDialog extends StatefulWidget {
  const _LaborLineDialog({this.line});

  final LaborLineEntity? line;

  @override
  State<_LaborLineDialog> createState() => _LaborLineDialogState();
}

class _LaborLineDialogState extends State<_LaborLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _feeCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.line?.description ?? '');
    _feeCtrl = TextEditingController(
      text: (widget.line?.fee ?? 0) > 0
          ? widget.line!.fee.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final fee = double.parse(_feeCtrl.text.trim());
    final existing = widget.line;
    final line = LaborLineEntity(
      id: existing?.id ?? const Uuid().v4(),
      description: _descCtrl.text.trim(),
      fee: fee,
    );
    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line == null ? 'Add Labor' : 'Edit Labor'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Engine tune-up',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _feeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Fee',
                prefixText: AppConstants.currencySymbol,
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null) return 'Enter a valid amount';
                if (parsed <= 0) return 'Fee must be greater than 0';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.line == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
```

Add the `uuid` import alongside the other top-of-file imports (after line 12, the `intl` import):

```dart
import 'package:uuid/uuid.dart';
```

> Note for the assembler: `MechanicPicker` here is invoked with `mechanicId:` + an `onChanged(String? id, String? name)` callback rather than the cart-bound `mechanic_picker.dart` from the contract (which calls `cart.setMechanic`). If the contract's picker is strictly cart-bound, expose a thin `onChanged` constructor variant, or wrap it. Confirm the picker's public constructor signature with the Plan-1 author and adjust this call site to match (this is the only coupling point).

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/draft_edit_screen_labor_test.dart`

- [ ] **Step 5: Commit**
```
git add lib/presentation/mobile/screens/drafts/draft_edit_screen.dart test/presentation/widgets/draft_edit_screen_labor_test.dart && git commit -m "feat(drafts): editable labor & mechanic section in draft editor, persisted via full updateDraft"
```

---

### Task 27: Show labor subtotal, labor lines, and mechanic in the draft detail sheet

**Files:**
- Modify: `lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart`
- Test: `test/presentation/widgets/draft_detail_sheet_labor_test.dart` (create)

Adds a labor subtotal row + labor-line list to `_buildSummaryCard`, and a "Mechanic" row to `_buildInfoCard` when a mechanic is assigned. Read-only (the sheet has no edit affordances).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_detail_sheet.dart';

void main() {
  DraftEntity buildDraft({List<LaborLineEntity> labor = const [], String? mechanic}) =>
      DraftEntity(
        id: 'draft-1',
        name: 'Plate ABC-123',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: labor,
        mechanicName: mechanic,
        mechanicId: mechanic == null ? null : 'mech-1',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => MaterialApp(
        home: Scaffold(
          body: DraftDetailSheet(
            draft: draft,
            onLoad: () {},
            onDelete: () {},
          ),
        ),
      );

  testWidgets('shows labor lines, labor subtotal, and mechanic row',
      (tester) async {
    await tester.pumpWidget(harness(buildDraft(
      labor: const [
        LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
      ],
      mechanic: 'Juan Dela Cruz',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.text('Labor'), findsWidgets);
    expect(find.text('Mechanic'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    // Grand total = parts 200 + labor 450 = 650.00.
    expect(find.textContaining('650.00'), findsWidgets);
  });

  testWidgets('hides labor and mechanic rows when none present',
      (tester) async {
    await tester.pumpWidget(harness(buildDraft()));
    await tester.pumpAndSettle();

    expect(find.text('Mechanic'), findsNothing);
    expect(find.text('Engine tune-up'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/draft_detail_sheet_labor_test.dart`. Fails: no "Engine tune-up", "Mechanic", or "Juan Dela Cruz" rendered.

- [ ] **Step 3: Implement** — Extend `_buildSummaryCard` (add labor rows before the divider/total) and `_buildInfoCard` (add a mechanic row).

Replace the discount-`if` + divider + total block inside `_buildSummaryCard` (lines 319–337) with:

```dart
            if (draft.hasDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Discount',
                '-${AppConstants.currencySymbol}${draft.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            if (draft.laborLines.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
              ...draft.laborLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _buildSummaryRow(
                    theme,
                    line.description,
                    '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                  ),
                ),
              ),
              _buildSummaryRow(
                theme,
                'Labor',
                '${AppConstants.currencySymbol}${draft.laborSubtotal.toStringAsFixed(2)}',
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            _buildSummaryRow(
              theme,
              'Total',
              '${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
              isTotal: true,
            ),
```

Add a mechanic row in `_buildInfoCard`. Insert it after the "Created by" row (after the `_buildInfoRow(... 'Created by', draft.createdByName)` block at lines 386–391):

```dart
            _buildInfoRow(
              theme,
              CupertinoIcons.person,
              'Created by',
              draft.createdByName,
            ),
            if (draft.mechanicName != null &&
                draft.mechanicName!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              _buildInfoRow(
                theme,
                CupertinoIcons.wrench,
                'Mechanic',
                draft.mechanicName!,
              ),
            ],
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/draft_detail_sheet_labor_test.dart`

- [ ] **Step 5: Commit**
```
git add lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart test/presentation/widgets/draft_detail_sheet_labor_test.dart && git commit -m "feat(drafts): labor subtotal + lines + mechanic row in draft detail sheet"
```

---

### Task 28: Add a "Service job" badge to the draft list tile

**Files:**
- Modify: `lib/presentation/mobile/widgets/drafts/draft_list_tile.dart`
- Test: `test/presentation/widgets/draft_list_tile_test.dart` (modify — extend existing group)

When `draft.laborLines` is non-empty, the tile shows a small "Service job" badge (wrench icon) in `_buildItemsPreview`.

- [ ] **Step 1: Write the failing test** — Append these two cases inside the existing `group('DraftListTile', ...)` in `test/presentation/widgets/draft_list_tile_test.dart`:

```dart
    testWidgets('shows Service job badge when draft has labor lines',
        (tester) async {
      final serviceDraft = DraftEntity(
        id: 'draft-2',
        name: 'Plate XYZ-789',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 1,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2025, 2, 5, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: serviceDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsOneWidget);
    });

    testWidgets('hides Service job badge when draft has no labor lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsNothing);
    });
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/draft_list_tile_test.dart`. The new "shows Service job badge" case fails: no "Service job" text rendered.

- [ ] **Step 3: Implement** — In `_buildItemsPreview`, prepend a badge row when labor exists. Replace the `Column`'s `children` opening (lines 160–163, from `child: Column(` through the start of `...previewItems.map`) with a leading badge block:

```dart
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.laborLines.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: theme.colorScheme.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.wrench,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Service job',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ...previewItems.map((item) => Padding(
```

(The rest of the `...previewItems.map(...)` body and the `remainingCount` block stay unchanged.)

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/draft_list_tile_test.dart`

- [ ] **Step 5: Commit**
```
git add lib/presentation/mobile/widgets/drafts/draft_list_tile.dart test/presentation/widgets/draft_list_tile_test.dart && git commit -m "feat(drafts): show Service job badge on draft tiles with labor lines"
```

---

### Task 29: Add labor lines, labor subtotal, and mechanic to the sale detail screen

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
- Test: `test/presentation/widgets/sale_detail_screen_labor_test.dart` (create)

Adds labor rows beneath the product items in `_buildItemsList`, a labor subtotal line in `_buildPaymentCard` (before Total), and a "Mechanic" row in `_buildDetailsCard`. Since this slice cannot fully stand up the screen's many providers (cost mapping, void requests) without overrides, the widget test renders the screen with the minimum overrides and asserts the labor + mechanic surfaces. The `grandTotal` already includes labor (Plan-1 getter change) so the header total is verify-only.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';

void main() {
  SaleEntity buildSale() => SaleEntity(
        id: 'sale-1',
        saleNumber: 'S-0001',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        status: SaleStatus.completed,
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(SaleEntity sale) => ProviderScope(
        overrides: [
          saleByIdProvider('sale-1').overrideWith((ref) async => sale),
          costCodeMappingProvider.overrideWith(
            (ref) async => CostCodeEntity.defaultMapping(),
          ),
          pendingVoidRequestForSaleProvider('sale-1')
              .overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: SaleDetailScreen(saleId: 'sale-1')),
      );

  testWidgets('renders labor line, labor subtotal, and mechanic name',
      (tester) async {
    await tester.pumpWidget(harness(buildSale()));
    await tester.pumpAndSettle();

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.text('Labor'), findsWidgets);
    expect(find.text('Mechanic'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    // grandTotal = parts 200 + labor 450 = 650.00.
    expect(find.textContaining('650.00'), findsWidgets);
  });
}
```

> Note for the assembler: the override list assumes `currentUserProvider` / `pendingVoidRequestForSaleProvider` / `costCodeMappingProvider` accept `overrideWith` with the signatures shown (Stream/Future providers). If any is a different provider kind, adjust the override form — the assertions on labor/mechanic text are the load-bearing part.

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/sale_detail_screen_labor_test.dart`. Fails: "Engine tune-up", "Mechanic", "Juan Dela Cruz" not rendered.

- [ ] **Step 3: Implement** — Three edits.

(a) In `_buildItemsList`, render labor rows after the product rows. Replace the `child: Column(` … `).toList(),` body (lines 270–352) so the column concatenates product rows with labor rows:

```dart
      child: Column(
        children: [
          ...sale.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == sale.items.length - 1 &&
                sale.laborLines.isEmpty;
            final netAmount = item.calculateNetAmount(
              isPercentage: sale.isPercentageDiscount,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.sku} • ${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Code: ${costMapping.encode(item.unitCost)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (item.hasDiscount)
                          Text(
                            sale.isPercentageDiscount
                                ? '${item.discountValue.toStringAsFixed(0)}% discount'
                                : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)} discount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...sale.laborLines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final isLast = index == sale.laborLines.length - 1;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      CupertinoIcons.wrench,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.description,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Labor',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
```

(b) In `_buildPaymentCard`, add the labor subtotal before Total. Replace the discount-`if` + divider + Total block (lines 367–377) with:

```dart
          if (sale.hasDiscount) ...[
            const SizedBox(height: 8),
            _buildPaymentRow(
              theme,
              'Discount',
              sale.totalDiscount,
              isDiscount: true,
            ),
          ],
          if (sale.laborLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPaymentRow(
              theme,
              sale.laborLines.length == 1
                  ? 'Labor (1 service)'
                  : 'Labor (${sale.laborLines.length} services)',
              sale.laborSubtotal,
            ),
          ],
          const Divider(height: 24),
          _buildPaymentRow(theme, 'Total', sale.grandTotal, isTotal: true),
```

(c) In `_buildDetailsCard`, add a mechanic row. Insert it after the "Cashier" row (after the `_buildDetailRow(... 'Cashier', sale.cashierName)` block at lines 468–473):

```dart
          _buildDetailRow(
            theme,
            CupertinoIcons.person,
            'Cashier',
            sale.cashierName,
          ),
          if (sale.mechanicName != null && sale.mechanicName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              CupertinoIcons.wrench,
              'Mechanic',
              sale.mechanicName!,
            ),
          ],
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/sale_detail_screen_labor_test.dart`

- [ ] **Step 5: Commit**
```
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart test/presentation/widgets/sale_detail_screen_labor_test.dart && git commit -m "feat(sales): labor line items + labor subtotal + mechanic on sale detail screen"
```



<!-- slice: I-test-sweep (Final fixture sweep + integration test) -->

### Task 30: Verify the labor-zero fixtures in `SalesSummary`-driven report/closing tests still pass unchanged

**Files:**
- Test (verify-only, expect unchanged): `test/domain/usecases/reports/get_profit_report_usecase_test.dart`, `test/domain/usecases/reports/get_sales_report_usecase_test.dart`, `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`, `test/domain/usecases/daily_closing/close_day_usecase_test.dart`, `test/domain/entities/daily_closing_draft_test.dart`, `test/domain/entities/post_close_activity_test.dart`

These tests build `SalesSummary` / `DailyClosingEntity` / `DailyClosingDraft` **directly** (never a sale carrying labor), so the parts-only fixtures are correct by design: `laborRevenue`/`laborProfit` default to `0` and every numeric expectation (`expectedCash 2600/2850`, `totalProfit 600/1000`, `netAmount 1234.56`, `updatedCashOnHand 2740/2500/2450/2300`, `expectedCashFor 2500/2750/1900`) is **unchanged**. The only risk is a compile break if the upstream reporting slice added `laborRevenue`/`laborProfit` to the `SalesSummary` constructor **without** defaults; the const literals in these files omit them.

- [ ] **Step 1: No new test — this is a regression guard for the upstream `SalesSummary` change.** The fixtures already encode the parts-only invariant; we only confirm they compile and pass after labor fields exist.
- [ ] **Step 2: Run them, expect PASS (or a compile error pinpointing a missing default)**
  ```
  flutter test \
    test/domain/usecases/reports/get_profit_report_usecase_test.dart \
    test/domain/usecases/reports/get_sales_report_usecase_test.dart \
    test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart \
    test/domain/usecases/daily_closing/close_day_usecase_test.dart \
    test/domain/entities/daily_closing_draft_test.dart \
    test/domain/entities/post_close_activity_test.dart
  ```
  Expect all green. If instead you see `The named parameter 'laborRevenue' is required` on a `const SalesSummary(...)` literal, the upstream constructor lacks defaults.
- [ ] **Step 3: Fix only if it failed to compile** — make the labor fields default to zero in the upstream constructor (`lib/domain/repositories/sale_repository.dart`) so legacy literals keep compiling:
  ```dart
  const SalesSummary({
    required this.totalSalesCount,
    required this.voidedSalesCount,
    required this.grossAmount,
    required this.totalDiscounts,
    required this.netAmount,
    required this.totalCost,
    required this.totalProfit,
    required this.byPaymentMethod,
    this.laborRevenue = 0,
    this.laborProfit = 0,
  });
  ```
  Do NOT touch the numeric expectations in any of these six files — they are parts-only and correct. (If the constructor already defaulted these, this task is a no-op beyond the run.)
- [ ] **Step 4: Re-run the same command, expect PASS**
  ```
  flutter test \
    test/domain/usecases/reports/get_profit_report_usecase_test.dart \
    test/domain/usecases/reports/get_sales_report_usecase_test.dart \
    test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart \
    test/domain/usecases/daily_closing/close_day_usecase_test.dart \
    test/domain/entities/daily_closing_draft_test.dart \
    test/domain/entities/post_close_activity_test.dart
  ```
- [ ] **Step 5: Commit (only if a default was added)**
  ```
  git add lib/domain/repositories/sale_repository.dart && git commit -m "fix(reports): default SalesSummary labor fields to zero so parts-only fixtures compile"
  ```

---

### Task 31: Verify the cart/sale tender fixtures still hold with labor absent

**Files:**
- Test (verify-only): `test/presentation/providers/cart_tenders_test.dart`, `test/data/repositories/sales_summary_tenders_test.dart`, `test/domain/usecases/process_sale_tender_validation_test.dart`

None of these add labor lines, and every item uses `unitCost: 0` with no discount, so `grandTotal == partsSubtotal == subtotal` exactly as before (`1000`, `500`, salmon `400+600`). The new `grandTotal = partsRevenue + laborRevenue` formula reduces to the old value when `laborLines` is empty. `cart_tenders_test` builds the cart only through `cart.addProduct(_product(1000))` (no labor), `sales_summary_tenders_test._sale(...)` constructs `SaleEntity` with no labor args, and `process_sale_tender_validation_test._salmonSale()` likewise. These must pass with zero edits to expectations.

- [ ] **Step 1: No new test — regression guard.** The existing assertions (`tenders == {cash:1000}`, `change 200`, `isPaymentValid`, salmon `collectedToday 400`, bucket totals `1000+1000+500`) already encode the labor-zero invariant.
- [ ] **Step 2: Run them, expect PASS**
  ```
  flutter test \
    test/presentation/providers/cart_tenders_test.dart \
    test/data/repositories/sales_summary_tenders_test.dart \
    test/domain/usecases/process_sale_tender_validation_test.dart
  ```
  Expect all green. A failure here means the upstream `grandTotal`/`tenders` math regressed for the empty-labor case (the most likely such bug: `setAmountReceived`/`tenders` now keying off `laborSubtotal` even when empty).
- [ ] **Step 3: No production code to write in this slice.** If a failure appears, it is an upstream cart/summary defect — file it against the Cart/Reporting slices, not here. Do not relax these expectations to make them pass.
- [ ] **Step 4: Re-run, expect PASS**
  ```
  flutter test \
    test/presentation/providers/cart_tenders_test.dart \
    test/data/repositories/sales_summary_tenders_test.dart \
    test/domain/usecases/process_sale_tender_validation_test.dart
  ```
- [ ] **Step 5: No commit (no files changed).** If you had to escalate an upstream failure, stop and surface it rather than committing.

---

### Task 32: Prove checkout-with-labor does NOT deduct inventory for labor lines

**Files:**
- Modify (Test): `test/domain/usecases/process_sale_usecase_test.dart`

`ProcessSaleUseCase._updateInventory` iterates `sale.items` only; labor lines carry no `productId`, so a sale that adds labor must still call `updateStock` exactly once (for the single part), never an extra time for labor. This is the verify-only behavior shift the spec flags in §8.2.

- [ ] **Step 1: Write the failing test** — add inside `group('ProcessSaleUseCase', ...)`, after the existing success test:
  ```dart
  test('labor lines do not deduct inventory (only items are stocked)', () async {
    final sale = createTestSale().copyWith(
      laborLines: const [
        LaborLineEntity(id: 'lab-1', description: 'Engine tune-up', fee: 450),
      ],
      mechanicId: 'mech-1',
      mechanicName: 'Juan Dela Cruz',
      // grandTotal is now 200 (parts) + 450 (labor) = 650; pay it in full cash.
      tenders: const {PaymentMethod.cash: 650},
      amountReceived: 650,
    );

    when(() => mockSaleRepo.generateSaleNumber(any()))
        .thenAnswer((_) async => 'SALE-002');
    when(() => mockSaleRepo.createSale(any()))
        .thenAnswer((inv) async => (inv.positionalArguments.first as SaleEntity)
            .copyWith(id: 'sale-200', saleNumber: 'SALE-002'));
    when(() => mockProductRepo.getProductById(any()))
        .thenAnswer((_) async => ProductEntity(
              id: 'prod-1',
              sku: 'SKU-001',
              name: 'Test Product',
              costCode: 'NBF',
              cost: 60,
              price: 100,
              quantity: 100,
              reorderLevel: 10,
              unit: 'pcs',
              isActive: true,
              createdAt: DateTime.now(),
            ));
    when(() => mockProductRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => ProductEntity(
          id: 'prod-1',
          sku: 'SKU-001',
          name: 'Test Product',
          costCode: 'NBF',
          cost: 60,
          price: 100,
          quantity: 98,
          reorderLevel: 10,
          unit: 'pcs',
          isActive: true,
          createdAt: DateTime.now(),
        ));

    final result = await useCase.execute(sale: sale);

    expect(result.success, true, reason: result.errorMessage);
    expect(result.sale!.laborSubtotal, 450);
    expect(result.sale!.grandTotal, 650);

    // Exactly ONE stock update — for the single part. Labor must not add calls.
    verify(() => mockProductRepo.updateStock(
          productId: 'prod-1',
          quantityChange: -2,
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).called(1);
    verifyNoMoreInteractions(mockProductRepo);
  });
  ```
  Add `import 'package:maki_mobile_pos/domain/entities/labor_line_entity.dart';` if `entities.dart` (already imported) does not yet re-export it; the contract exports it via the barrel, so the existing `entities.dart` import suffices.
- [ ] **Step 2: Run it, expect FAIL**
  ```
  flutter test test/domain/usecases/process_sale_usecase_test.dart
  ```
  Before the Cart/Entity slices land, this fails to compile (`copyWith` has no `laborLines`/`mechanicId`/`mechanicName`, `LaborLineEntity` undefined). After they land, it should pass with no production change.
- [ ] **Step 3: No production change** — `process_sale_usecase.dart` already iterates `sale.items` only (lines 157–176). This task asserts that invariant; the only "implementation" is the dependency on the entity fields delivered by the Domain/Cart slices.
- [ ] **Step 4: Run tests, expect PASS**
  ```
  flutter test test/domain/usecases/process_sale_usecase_test.dart
  ```
- [ ] **Step 5: Commit**
  ```
  git add test/domain/usecases/process_sale_usecase_test.dart && git commit -m "test(pos): prove checkout-with-labor deducts inventory for parts only, never labor"
  ```

---

### Task 33: Prove void-with-labor does NOT restock labor lines

**Files:**
- Modify (Test): `test/domain/usecases/void_sale_usecase_test.dart`

`VoidSaleUseCase._restoreInventory` iterates `sale.items` only. Voiding a sale that carries labor must still call `updateStock` exactly once (positive, for the one part) and never an extra restock for labor.

- [ ] **Step 1: Write the failing test** — add inside `group('VoidSaleUseCase', ...)`, after the first success test:
  ```dart
  test('labor lines are not restocked on void (only items restore stock)',
      () async {
    final sale = createTestSale().copyWith(
      laborLines: const [
        LaborLineEntity(id: 'lab-1', description: 'Brake bleed', fee: 300),
      ],
      mechanicId: 'mech-1',
      mechanicName: 'Juan Dela Cruz',
    );
    final voidedSale = sale.void_(
      voidedById: 'admin-1',
      voidedByUserName: 'Admin User',
      reason: 'Customer refund request',
    );

    when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => sale);
    when(() => mockAuthRepo.verifyPassword(any()))
        .thenAnswer((_) async => true);
    when(() => mockSaleRepo.voidSale(
          saleId: any(named: 'saleId'),
          voidedBy: any(named: 'voidedBy'),
          voidedByName: any(named: 'voidedByName'),
          reason: any(named: 'reason'),
        )).thenAnswer((_) async => voidedSale);
    when(() => mockProductRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => ProductEntity(
          id: 'prod-1',
          sku: 'SKU-001',
          name: 'Test Product',
          costCode: 'NBF',
          cost: 60,
          price: 100,
          quantity: 102,
          reorderLevel: 10,
          unit: 'pcs',
          isActive: true,
          createdAt: DateTime.now(),
        ));

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      saleId: 'sale-1',
      password: 'admin123',
      reason: 'Customer refund request',
      voidedBy: 'admin-1',
      voidedByName: 'Admin User',
    );

    expect(result.success, true);

    // Exactly ONE restock — the single part. Labor must add no restock call.
    verify(() => mockProductRepo.updateStock(
          productId: 'prod-1',
          quantityChange: 2,
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).called(1);
    verifyNoMoreInteractions(mockProductRepo);
  });
  ```
  `LaborLineEntity` is reachable through the existing `package:maki_mobile_pos/domain/entities/entities.dart` import (the contract exports it via the barrel).
- [ ] **Step 2: Run it, expect FAIL**
  ```
  flutter test test/domain/usecases/void_sale_usecase_test.dart
  ```
  Compile failure until the Domain/Cart slices add `laborLines`/`mechanicId`/`mechanicName` to `SaleEntity.copyWith`; then green with no production change.
- [ ] **Step 3: No production change** — `void_sale_usecase.dart` restocks `sale.items` only (lines 165–186); the test pins that.
- [ ] **Step 4: Run tests, expect PASS**
  ```
  flutter test test/domain/usecases/void_sale_usecase_test.dart
  ```
- [ ] **Step 5: Commit**
  ```
  git add test/domain/usecases/void_sale_usecase_test.dart && git commit -m "test(pos): prove void-with-labor restocks parts only, never labor"
  ```

---

### Task 34: Full suite sweep: run everything and confirm no other hard-coded total/profit/expectedCash fixture broke

**Files:**
- Modify only if a regression surfaces (Test): any of `test/domain/entities/sale_entity_test.dart`, `test/domain/entities/sale_entity_tenders_test.dart`, `test/presentation/providers/cart_provider_test.dart`, `test/data/models/daily_closing_model_test.dart`, `test/presentation/providers/daily_closing_draft_live_test.dart`, `test/presentation/widgets/sales_summary_section_test.dart`, `test/domain/repositories/repository_contracts_test.dart`

This is the catch-all sweep after every other slice lands. The grep of the repo shows these are the remaining files referencing `grandTotal`/`totalProfit`/`expectedCash`/`laborRevenue`. Each is owned and updated by an earlier slice (entity, cart, reporting, daily-closing); this task confirms the assembled whole is green and that no fixture was missed.

- [ ] **Step 1: No new test — final integration guard across the suite.**
- [ ] **Step 2: Run the whole unit suite, expect PASS**
  ```
  flutter test
  ```
- [ ] **Step 3: Triage any failure to its owning slice, do not patch blindly.** For each red test, decide whether the *expected* number genuinely changed:
  - If the fixture builds a sale/cart/draft that **adds labor**, recompute with the formulas: `grandTotal = (subtotal − totalDiscount) + Σ fee`; `totalProfit = (partsRevenue − totalCost) + Σ fee`; for closing, `expectedCash` rises by labor **paid in cash** (the cash-bucket portion of `effectiveTenders`), never by salmon/gcash/maya labor. Update the literal to the recomputed value and note the arithmetic in a comment.
  - If the fixture has **no labor** (the common case), the number is unchanged and any failure is an upstream math bug — escalate to that slice rather than editing the expectation.
- [ ] **Step 4: Re-run, expect PASS**
  ```
  flutter test
  ```
- [ ] **Step 5: Commit (only if you corrected a genuinely-shifted labor fixture)**
  ```
  git add <the specific test files you changed> && git commit -m "test: update labor-inclusive total/profit/expectedCash fixtures after grandTotal change"
  ```

> **Note on exact numbers:** I cannot pre-compute new literals for this sweep without running the suite, because no fixture in the current tree adds labor — every existing `grandTotal`/`totalProfit`/`expectedCash` value is already correct for the labor-zero case and stays unchanged. Any value that *does* change will only appear in fixtures introduced by the entity/cart/reporting slices; recompute those with the formulas above (`grandTotal = subtotal − discount + Σfee`; `totalProfit = partsRevenue − totalCost + Σfee`; `expectedCash += labor cash tendered`). Do not invent numbers.

---

### Task 35: Integration test: service-draft flow (part + labor + mechanic → save draft → reload → checkout → receipt + parts-only report unchanged)

**Files:**
- Create (Test): `integration_test/service_draft_labor_flow_test.dart`

Mirrors the in-memory-fake style of `sku_edit_flow_test.dart` (no Firebase, no network; backend providers overridden with mocks) but drives the POS → draft → checkout → receipt path. It asserts: (1) labor + mechanic round-trip through save-draft and reload (the spec's "Cart → Draft/Sale drop" breaking risk), (2) the checkout receipt shows the labor line and mechanic name, (3) the persisted sale carries labor inline, and (4) the parts-only `SalesSummary` is unchanged while `laborRevenue` reflects the labor (the decision #9 invariant) — exercised at the repository/summary layer with the same fakes so the assertion is deterministic on-device.

- [ ] **Step 1: Write the test** (this is the integration test itself — the harness equivalent of steps 1–2). Drive the cart notifier + draft/sale round-trip and the summary math through fakes, asserting the labor invariants end-to-end:
  ```dart
  // Service-draft end-to-end flow: add a part, add labor, assign a mechanic,
  // save as draft, reload the draft into a fresh cart, check out, and assert the
  // sale carries labor inline + the mechanic name, while the parts-only sales
  // summary is unchanged and laborRevenue reflects the labor.
  //
  // Backend is in-memory fakes (no Firebase, no network), matching the style of
  // sku_edit_flow_test.dart. See README.md for growing this to emulator-backed.
  //
  // Run headless:    flutter test integration_test/service_draft_labor_flow_test.dart
  // Run on device:   flutter test integration_test/ -d <device-id>

  import 'package:flutter_test/flutter_test.dart';
  import 'package:integration_test/integration_test.dart';

  import 'package:maki_mobile_pos/core/enums/enums.dart';
  import 'package:maki_mobile_pos/domain/entities/entities.dart';
  import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
  import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

  ProductEntity _part() => ProductEntity(
        id: 'prod-1',
        sku: 'SKU-001',
        name: 'Spark Plug',
        costCode: 'NBF',
        cost: 60,
        price: 100,
        quantity: 100,
        reorderLevel: 10,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  // Mirrors SaleRepositoryImpl.getSalesSummary's parts-only top-line + labor
  // track (spec §6.2), so the invariant is checked deterministically on-device.
  SalesSummary _summarize(List<SaleEntity> sales) {
    double gross = 0, net = 0, cost = 0, labor = 0;
    final buckets = <PaymentMethod, double>{};
    for (final s in sales) {
      gross += s.partsSubtotal;
      net += s.partsRevenue;
      cost += s.totalCost;
      labor += s.laborRevenue;
      s.effectiveTenders.forEach((m, a) {
        buckets[m] = (buckets[m] ?? 0) + a;
      });
    }
    return SalesSummary(
      totalSalesCount: sales.length,
      voidedSalesCount: 0,
      grossAmount: gross,
      totalDiscounts: 0,
      netAmount: net,
      totalCost: cost,
      totalProfit: net - cost,
      byPaymentMethod: buckets,
      laborRevenue: labor,
      laborProfit: labor,
    );
  }

  void main() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    testWidgets('service draft round-trips labor + mechanic, then checks out',
        (tester) async {
      // 1. Build a service draft in the cart: one part + two labor lines + mechanic.
      final cart = CartNotifier();
      cart.addProduct(_part()); // partsSubtotal = 100
      cart.addLaborLine(description: 'Engine tune-up', fee: 450);
      cart.addLaborLine(description: 'Brake bleed', fee: 300);
      cart.setMechanic('mech-1', 'Juan Dela Cruz');

      // Money math: parts 100, labor 750, grand 850 (labor never discounted).
      expect(cart.state.partsSubtotal, 100);
      expect(cart.state.laborSubtotal, 750);
      expect(cart.state.grandTotal, 850);
      expect(cart.state.mechanicName, 'Juan Dela Cruz');

      // 2. Save as draft (the entity that would be persisted inline).
      final draft = cart.toDraft();
      expect(draft.laborLines.length, 2);
      expect(draft.mechanicId, 'mech-1');
      expect(draft.mechanicName, 'Juan Dela Cruz');
      expect(draft.laborSubtotal, 750);
      expect(draft.grandTotal, 850);

      // 3. Reload the draft into a FRESH cart — labor + mechanic must survive.
      final reloaded = CartNotifier();
      reloaded.loadFromDraft(draft);
      expect(reloaded.state.laborLines.length, 2);
      expect(reloaded.state.mechanicId, 'mech-1');
      expect(reloaded.state.mechanicName, 'Juan Dela Cruz');
      expect(reloaded.state.grandTotal, 850);

      // 4. Check out: pay the full grand total in cash.
      reloaded.setPaymentMethod(PaymentMethod.cash);
      reloaded.setAmountReceived(850);
      expect(reloaded.state.isPaymentValid, true);

      final sale = reloaded.toSale(
        cashierId: 'cashier-1',
        cashierName: 'Cashier',
      );

      // 5. Receipt-facing data: labor lines + mechanic carried on the sale.
      expect(sale.laborLines.map((l) => l.description),
          containsAll(<String>['Engine tune-up', 'Brake bleed']));
      expect(sale.laborSubtotal, 750);
      expect(sale.mechanicName, 'Juan Dela Cruz');
      expect(sale.grandTotal, 850); // labor-inclusive true total on the receipt

      // 6. Parts-only summary unchanged; labor on its own track (decision #9).
      final summary = _summarize([sale]);
      expect(summary.grossAmount, 100);   // parts only
      expect(summary.netAmount, 100);     // parts only — NOT 850
      expect(summary.totalProfit, 40);    // parts profit (100 - 60 cost)
      expect(summary.laborRevenue, 750);  // labor track
      expect(summary.laborProfit, 750);   // zero-cost labor

      // Reconciliation identity: Σ byPaymentMethod == net(parts) + laborRevenue.
      final tenderTotal =
          summary.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
      expect(tenderTotal, summary.netAmount + summary.laborRevenue); // 850
    });
  }
  ```
  Adjust the `toSale(...)` call to match the real signature delivered by the Cart slice (the contract lists `toSale` passing `laborLines + mechanicId + mechanicName`; keep the cashier args this repo's existing `toSale` already requires). If `toSale` in this repo takes no cashier args, drop them — read `lib/presentation/providers/cart_provider.dart` at integration time to match exactly.
- [ ] **Step 2: Run it, expect FAIL (then PASS once upstream slices land)**
  ```
  flutter test integration_test/service_draft_labor_flow_test.dart -d <device-id>
  ```
  Before the Cart/Entity/Reporting slices: compile failure (`addLaborLine`, `setMechanic`, `laborSubtotal`, `partsRevenue`, `SalesSummary.laborRevenue` undefined). After they land: all assertions pass.
- [ ] **Step 3: No production code in this slice** — the test consumes the cart/entity/summary APIs the earlier slices implement. If `toSale`/`loadFromDraft`/`toDraft` do not yet carry labor, that is the "Cart → Draft/Sale drop" breaking risk (spec §7.1) and this test is exactly the guard that catches it; the fix belongs to the Cart slice.
- [ ] **Step 4: Run tests, expect PASS**
  ```
  flutter test integration_test/service_draft_labor_flow_test.dart -d <device-id>
  ```
- [ ] **Step 5: Commit**
  ```
  git add integration_test/service_draft_labor_flow_test.dart && git commit -m "test(e2e): service-draft labor+mechanic round-trip, checkout, and parts-only-vs-labor summary invariant"
  ```

---

### Task 36: Document the labor integration flow in the integration-test README

**Files:**
- Modify: `integration_test/README.md`

Keep the harness self-documenting: add the new flow to the "What's here" list so the next contributor knows it exists and why it uses in-memory fakes.

- [ ] **Step 1: Manual verification only (doc change).** No automated test; the change is a prose list entry.
- [ ] **Step 2: N/A — markdown.** Verify by reading the rendered list after the edit.
- [ ] **Step 3: Implement** — add this bullet to the "What's here" section, immediately after the `sku_edit_flow_test.dart` bullet:
  ```markdown
  - **`service_draft_labor_flow_test.dart`** — drives the POS service-draft path
    with in-memory state: add a part, add labor lines, assign a mechanic, save as
    a draft, reload it into a fresh cart, and check out. Asserts labor + mechanic
    round-trip through the draft, the sale carries labor inline (the receipt's
    grand total is labor-inclusive), and the **parts-only sales summary is
    unchanged** while `laborRevenue`/`laborProfit` track labor separately
    (reconciliation identity `Σ byPaymentMethod == net(parts) + laborRevenue`).
  ```
- [ ] **Step 4: Verify the file reads correctly**
  ```
  flutter test integration_test/service_draft_labor_flow_test.dart -d <device-id>
  ```
  (Re-runs the flow to confirm the doc matches behavior; no separate doc test.)
- [ ] **Step 5: Commit**
  ```
  git add integration_test/README.md && git commit -m "docs(e2e): describe the service-draft labor flow in the integration-test README"
  ```

---

**Exact test files touched by this slice:**
- `test/domain/usecases/reports/get_profit_report_usecase_test.dart` (verify-only; numbers unchanged)
- `test/domain/usecases/reports/get_sales_report_usecase_test.dart` (verify-only; numbers unchanged)
- `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart` (verify-only; numbers unchanged)
- `test/domain/usecases/daily_closing/close_day_usecase_test.dart` (verify-only; `expectedCash 2600/2850` unchanged)
- `test/domain/entities/daily_closing_draft_test.dart` (verify-only; numbers unchanged)
- `test/domain/entities/post_close_activity_test.dart` (verify-only; numbers unchanged)
- `test/presentation/providers/cart_tenders_test.dart` (verify-only; numbers unchanged)
- `test/data/repositories/sales_summary_tenders_test.dart` (verify-only; numbers unchanged)
- `test/domain/usecases/process_sale_tender_validation_test.dart` (verify-only; numbers unchanged)
- `test/domain/usecases/process_sale_usecase_test.dart` (new labor-no-inventory test added)
- `test/domain/usecases/void_sale_usecase_test.dart` (new labor-no-restock test added)
- `integration_test/service_draft_labor_flow_test.dart` (new)
- `integration_test/README.md` (doc)
- Full-suite sweep may additionally touch (only if a genuinely-shifted labor fixture appears): `test/domain/entities/sale_entity_test.dart`, `test/domain/entities/sale_entity_tenders_test.dart`, `test/presentation/providers/cart_provider_test.dart`, `test/data/models/daily_closing_model_test.dart`, `test/presentation/providers/daily_closing_draft_live_test.dart`, `test/presentation/widgets/sales_summary_section_test.dart`, `test/domain/repositories/repository_contracts_test.dart`

**Numeric determination:** Every existing hard-coded fixture in the listed files is built from sales/carts/summaries with **no labor**, so under the new `grandTotal = (subtotal − discount) + Σfee` formula they evaluate identically to today — the numbers do **not** change and must not be edited. The only new numbers are introduced by my own new tests (computed inline: parts 100, labor 750, grand 850; parts profit 40). I cannot pre-compute any other "new" literal because no current fixture carries labor; if the entity/cart/reporting slices add labor-bearing fixtures, recompute with: `grandTotal = subtotal − totalDiscount + Σ fee`, `totalProfit = (partsRevenue − totalCost) + Σ fee`, and `expectedCash += (labor tendered in cash only)`.

<!-- self-review additions: spec-coverage gaps found by the critic -->

## Additional tasks — spec-coverage gaps (added during self-review)

These close §6.3 / §6.4 / §8.2 surfaces the parallel slices missed. They are additive/verify-only and depend on the reporting task (SalesSummary gains `laborRevenue`/`laborProfit`).

### Task 37: Web dashboard — Service revenue card

**Files:**
- Modify: `lib/presentation/web/screens/dashboard/web_dashboard_screen.dart`
- Test: `test/presentation/widgets/web_dashboard_labor_test.dart`

- [ ] **Step 1: Write the failing test** — `test/presentation/widgets/web_dashboard_labor_test.dart`. Build a `SalesSummary` via its real constructor (see `lib/domain/repositories/sale_repository.dart`, updated by the reporting task) with `laborRevenue: 450` and other money fields 0/sensible; override the provider and assert the card renders:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/web/screens/dashboard/web_dashboard_screen.dart';
// import SalesSummary's home (sale_repository.dart) for the fixture.

void main() {
  testWidgets('web dashboard shows a Service revenue card', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Use the REAL SalesSummary constructor; set laborRevenue: 450, laborProfit: 450,
        // grossAmount/netAmount/totalCost/totalProfit: 0, counts: 0.
        todaysSalesSummaryProvider.overrideWith((ref) async => /* _summary(laborRevenue: 450, laborProfit: 450) */ throw UnimplementedError()),
      ],
      child: const MaterialApp(home: WebDashboardScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Service revenue'), findsOneWidget);
    expect(find.textContaining('450'), findsWidgets);
  });
}
```

Replace the `overrideWith` body with a `_summary(...)` helper that calls the real `SalesSummary` constructor (do not invent fields — read the constructor first).

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/web_dashboard_labor_test.dart`. Fails: no 'Service revenue' card.

- [ ] **Step 3: Implement** — in `web_dashboard_screen.dart`, after the `Gross profit` `Expanded` card (the one reading `summary.totalProfit`), insert:

```dart
const SizedBox(width: AppSpacing.md),
Expanded(
  child: SummaryCard(
    title: 'Service revenue',
    value: money.format(summary.laborRevenue),
    icon: Icons.build,
    iconColor: AppColors.info,
  ),
),
```

(`summary.totalProfit` / `summary.netAmount` stay parts-only — do not change them.)

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/web_dashboard_labor_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/presentation/web/screens/dashboard/web_dashboard_screen.dart test/presentation/widgets/web_dashboard_labor_test.dart && git commit -m "feat(dashboard): show service-revenue card on web dashboard"`

### Task 38: Reports summary card — admin Service revenue + Service profit rows

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/sales_summary_card.dart`
- Test: extend `test/presentation/widgets/sales_summary_section_test.dart` (or a new `sales_summary_card_labor_test.dart`)

- [ ] **Step 1: Write the failing test** — pump `SalesSummaryCard` (admin variant) with a summary having `laborRevenue: 450`, `laborProfit: 450`; assert `find.text('Service Revenue')` and the formatted value render. Use the real `SalesSummary` constructor.

- [ ] **Step 2: Run it, expect FAIL** — `flutter test <that file>`. Fails: no Service rows.

- [ ] **Step 3: Implement** — in the admin-only block of `sales_summary_card.dart` (where `Gross Profit` is rendered from `summary.totalProfit` at ~line 189), add two rows mirroring the existing row widget used there:

```dart
// Service track (parts-only top-line keeps Gross Profit unchanged above).
_SummaryRow(
  label: 'Service Revenue',
  value: '${AppConstants.currencySymbol}${summary.laborRevenue.toStringAsFixed(2)}',
  subtitle: 'Labor (no COGS)',
),
_SummaryRow(
  label: 'Service Profit',
  value: '${AppConstants.currencySymbol}${summary.laborProfit.toStringAsFixed(2)}',
),
```

Use whatever row widget/helper the file already uses for `Gross Profit` (match its exact name and named params — read the file first; the label/value pattern above is illustrative).

- [ ] **Step 4: Run tests, expect PASS** — `flutter test <that file>`.

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/widgets/reports/sales_summary_card.dart test/... && git commit -m "feat(reports): show service revenue/profit rows in summary card"`

### Task 39: Verify the void-request snapshot captures the labor-inclusive total

**Files:**
- Test: extend `test/domain/usecases/void_sale_usecase_test.dart` (or `request_void_sale_usecase_test.dart` if present)

- [ ] **Step 1: Write the failing test** — build a sale with parts (net 1,000) + one labor line (fee 450) via the `_part()`/labor fixtures, run `RequestVoidSaleUseCase.execute(...)`, and assert the persisted void request's `saleGrandTotal == 1450` (labor-inclusive). This is a verify task — the behavior is automatic once `SaleEntity.grandTotal` includes labor; the test pins it.

- [ ] **Step 2: Run it, expect FAIL or PASS** — `flutter test <that file>`. If the fixture predates labor it passes trivially; the point is an explicit guard so a future regression that excludes labor from `grandTotal` fails here.

- [ ] **Step 3: Implement** — no production change expected; if the assertion fails, the bug is in `SaleEntity.grandTotal` (must be `partsRevenue + laborRevenue`). Fix there.

- [ ] **Step 4: Run tests, expect PASS** — `flutter test <that file>`.

- [ ] **Step 5: Commit** — `git add test/... && git commit -m "test(void): pin labor-inclusive grandTotal in void-request snapshot"`

### Task 40: Verify-only — labor-inclusive total renders in sale/draft list surfaces

**Files:**
- Test: `test/presentation/widgets/labor_inclusive_totals_test.dart`

- [ ] **Step 1: Write the failing test** — pump each of `DraftListTile` (with a draft carrying parts net 1,000 + labor 450), and a sale row used by `sales_list_screen` / `recent_sale_widget`, and assert the displayed total contains `1,450` (formatted). These widgets bind to `entity.grandTotal`; the test confirms they pick up labor with no per-widget code change.

- [ ] **Step 2: Run it, expect FAIL or PASS** — `flutter test test/presentation/widgets/labor_inclusive_totals_test.dart`. Verify-only; pins the behavior.

- [ ] **Step 3: Implement** — no production change expected (these read `grandTotal`). If a widget reads `subtotal`/`partsRevenue` instead of `grandTotal`, switch it to `grandTotal`.

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/labor_inclusive_totals_test.dart`.

- [ ] **Step 5: Commit** — `git add test/presentation/widgets/labor_inclusive_totals_test.dart && git commit -m "test(ui): pin labor-inclusive totals on list surfaces"`

### Task 41: Checkout — relabel the parts subtotal row (spec §7.2)

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart`

- [ ] **Step 1: Write the failing test** — extend the checkout-labor widget test from the POS/checkout task: when labor is present, assert `find.text('Parts subtotal')` is shown (so parts vs labor read unambiguously per §7.2).

- [ ] **Step 2: Run it, expect FAIL** — `flutter test <checkout labor test>`. Fails: the first summary row is still labelled 'Subtotal'.

- [ ] **Step 3: Implement** — in `checkout_screen.dart`'s payment summary, when `cart.laborLines.isNotEmpty`, render the first row label as `'Parts subtotal'` (value `cart.partsSubtotal`); keep `'Subtotal'` when there is no labor (so non-service sales are unchanged).

- [ ] **Step 4: Run tests, expect PASS** — `flutter test <checkout labor test>`.

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/pos/checkout_screen.dart test/... && git commit -m "feat(checkout): label parts subtotal when labor present"`

### Task 42: Daily closing — cover the labor-revenue write path

**Files:**
- Test: extend `test/domain/usecases/daily_closing/close_day_usecase_test.dart`

- [ ] **Step 1: Write the failing test** — seed a day with one completed sale carrying parts (net 1,000) + labor (450). Run `CloseDayUseCase.execute(...)` and assert the produced `DailyClosingEntity.laborRevenue == 450` AND `netSales == 1000` (parts-only) AND `expectedCash` includes the labor cash (if the sale was cash). This exercises the new `laborRevenue: draft.laborRevenue` write path added by the reporting task.

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/usecases/daily_closing/close_day_usecase_test.dart`. Fails until `DailyClosingEntity`/`DailyClosingDraft.fromData`/`close_day_usecase` carry `laborRevenue` (done in the reporting task).

- [ ] **Step 3: Implement** — no new production change beyond the reporting task; if it fails, ensure `close_day_usecase.dart` passes `laborRevenue: draft.laborRevenue` into `DailyClosingEntity(...)`.

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/usecases/daily_closing/close_day_usecase_test.dart`.

- [ ] **Step 5: Commit** — `git add test/domain/usecases/daily_closing/close_day_usecase_test.dart && git commit -m "test(closing): cover labor-revenue in daily close"`
