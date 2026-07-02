# Job Orders (repurpose Drafts) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the mobile Drafts feature into **Job Orders** — persistent motorcycle-service tickets that hold parts + labor + mechanic + bike model in place (without tying up the register), bill out safely, and feed two owner reports (Motorcycle Models, Top Mechanics).

**Architecture:** Additive change on the existing `drafts` collection + `Draft*`/`Sale*` code (no collection or symbol rename). New optional `motorcycleModel` string threads Draft→cart→Sale. A new admin-managed `motorcycle_models` collection (mirrors `mechanics`) backs a pick-or-add picker. The draft editor gains in-place part editing; bill-out becomes non-destructive (convert-on-success via the existing dead `_reconcileDraft` path). Two reports are derived providers over `salesByDateRangeProvider` + pure aggregation helpers, admin-gated.

**Tech Stack:** Flutter, Riverpod (StateNotifier/StreamProvider/FutureProvider.family), cloud_firestore, go_router, Lucide icons, `fake_cloud_firestore`/`mocktail` for tests, `csv` (`ListToCsvConverter`).

**Spec:** `docs/superpowers/specs/2026-07-01-job-orders-from-drafts-design.md`

## Global Constraints

Every task's requirements implicitly include these:

- **Mobile only.** Do not touch `web_admin/`. Flutter root only (`lib/`, `test/`).
- **No collection/symbol rename.** Keep the `drafts` Firestore collection and the `DraftEntity`/`DraftModel`/provider/usecase names. Rename only user-facing strings.
- **`motorcycleModel` is an optional `String?`** everywhere, storing the **canonical display name** (from the `motorcycle_models` list), never an id. Missing/absent → `null`. No `copyWith` clear-flag (YAGNI — a bike model is changed, not un-set).
- **`motorcycle_models` rules are DEPLOY-GATED.** The `firestore.rules` change (Task B8) is production-affecting — **confirm with the owner before `firebase deploy --only firestore:rules`** (CLAUDE.md). Enforcement is only live after deploy + APK install.
- **Reports are owner/admin-only** via a new `Permission.viewJobOrderReports` listed only in `_adminPermissions`.
- **No new Firestore index** — all report grouping is client-side.
- **Color discipline:** neutral by default; reuse `AppColors`/theme tokens, `AppCard`, `AppDialog`, Lucide icons. No raw hex except where the mirrored source already uses documented tokens.
- **TDD, always.** Write the failing test first, watch it fail, implement minimally, watch it pass. Run `flutter test` (targeted, then full) and `flutter analyze` before considering a task done. Commit after each task.
- **Release:** shipping is a debug-signed `flutter build apk --release` + manual `adb install -r` (the agent can build, not install/smoke). Model gate + pick-or-add go live only after install.

**Run commands:**
- Single test: `flutter test test/path/to/file_test.dart`
- Full suite: `flutter test`
- Analyze: `flutter analyze`

---

# Phase A — Data foundation

Adds the optional `motorcycleModel` field to Draft + Sale and threads it through the cart. No user-visible behavior change; unblocks every later phase. All three tasks are pure Dart (fast unit tests).

### Task A1: `motorcycleModel` on Draft (entity + model)

**Files:**
- Modify: `lib/domain/entities/draft_entity.dart` (field ~L36, ctor ~L75, copyWith ~L286/L308, props ~L342)
- Modify: `lib/data/models/draft_model.dart` (field ~L19, ctor ~L37, fromMap ~L79, toMap ~L109, toEntity ~L176, fromEntity ~L201, copyWith ~L235/L247)
- Test: `test/domain/entities/draft_entity_test.dart`, `test/data/models/draft_model_test.dart`

**Interfaces:**
- Produces: `DraftEntity({..., String? motorcycleModel})` + `draft.motorcycleModel`; `DraftModel` persists key `'motorcycleModel'`.

- [ ] **Step 1: Write the failing tests**

Append to `test/data/models/draft_model_test.dart`:

```dart
group('motorcycleModel', () {
  test('round-trips through fromMap/toMap', () {
    final map = {
      'name': 'ABC-123',
      'items': <dynamic>[],
      'motorcycleModel': 'Nmax',
      'createdBy': 'u1',
      'createdByName': 'Cashier',
    };
    final model = DraftModel.fromMap(map, 'd1');
    expect(model.motorcycleModel, 'Nmax');
    expect(model.toMap()['motorcycleModel'], 'Nmax');
    expect(model.toEntity().motorcycleModel, 'Nmax');
  });

  test('is null when the key is absent (legacy/web draft)', () {
    final model = DraftModel.fromMap(
      {'name': 'X', 'items': <dynamic>[], 'createdBy': 'u1', 'createdByName': 'C'},
      'd2',
    );
    expect(model.motorcycleModel, isNull);
    expect(model.toMap()['motorcycleModel'], isNull);
  });
});
```

Append to `test/domain/entities/draft_entity_test.dart`:

```dart
test('copyWith + props carry motorcycleModel', () {
  final d = DraftEntity(
    id: 'd1', name: 'ABC-123', items: const [],
    createdBy: 'u1', createdByName: 'C', createdAt: DateTime(2026, 7, 1),
  );
  expect(d.motorcycleModel, isNull);
  final withModel = d.copyWith(motorcycleModel: 'Click 125i');
  expect(withModel.motorcycleModel, 'Click 125i');
  expect(withModel, isNot(equals(d))); // props includes it
});
```

- [ ] **Step 2: Run the tests, verify they fail**

Run: `flutter test test/data/models/draft_model_test.dart test/domain/entities/draft_entity_test.dart`
Expected: FAIL — `motorcycleModel` isn't defined / named param doesn't exist.

- [ ] **Step 3: Implement — `DraftEntity`**

In `lib/domain/entities/draft_entity.dart`, mirror the `mechanicName` lines:
- Add field after `mechanicName` (~L36): `  /// Motorcycle model serviced (canonical name snapshot); null until set.\n  final String? motorcycleModel;`
- Add ctor param after `this.mechanicName,` (~L75): `    this.motorcycleModel,`
- In `copyWith` add param after `String? mechanicName,` (~L287): `    String? motorcycleModel,` and in the returned object after the `mechanicName:` line (~L308): `      motorcycleModel: motorcycleModel ?? this.motorcycleModel,`
- Add to `props` after `mechanicName,` (~L342): `        motorcycleModel,`

- [ ] **Step 4: Implement — `DraftModel`**

In `lib/data/models/draft_model.dart`, mirror the `mechanicName` lines:
- Field after `mechanicName` (~L19): `  final String? motorcycleModel;`
- Ctor param after `this.mechanicName,` (~L37): `    this.motorcycleModel,`
- `fromMap` after `mechanicName: map['mechanicName'] as String?,` (~L79): `      motorcycleModel: map['motorcycleModel'] as String?,`
- `toMap` base map after `'mechanicName': mechanicName,` (~L109): `      'motorcycleModel': motorcycleModel,`
- `toEntity` after `mechanicName: mechanicName,` (~L176): `      motorcycleModel: motorcycleModel,`
- `fromEntity` after `mechanicName: entity.mechanicName,` (~L201): `      motorcycleModel: entity.motorcycleModel,`
- `copyWith`: add param after `String? mechanicName,` (~L296): `    String? motorcycleModel,` and body after the `mechanicName:` line (~L315): `      motorcycleModel: motorcycleModel ?? this.motorcycleModel,`

- [ ] **Step 5: Run tests, verify pass; analyze**

Run: `flutter test test/data/models/draft_model_test.dart test/domain/entities/draft_entity_test.dart && flutter analyze lib/domain/entities/draft_entity.dart lib/data/models/draft_model.dart`
Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/draft_entity.dart lib/data/models/draft_model.dart test/domain/entities/draft_entity_test.dart test/data/models/draft_model_test.dart
git commit -m "feat(job-orders): add optional motorcycleModel to Draft entity+model"
```

---

### Task A2: `motorcycleModel` on Sale (entity + model)

**Files:**
- Modify: `lib/domain/entities/sale_entity.dart` (field ~L36, ctor ~L96, copyWith ~L226/L254, props ~L297)
- Modify: `lib/data/models/sale_model.dart` (field ~L19, ctor ~L38, fromMap ~L88, toMap ~L126, toEntity ~L202, fromEntity ~L233, create() ~L276/L293, copyWith ~L360)
- Test: `test/data/models/sale_model_test.dart`

**Interfaces:**
- Produces: `SaleEntity.motorcycleModel` (String?); `SaleModel` persists `'motorcycleModel'`. This is the durable field the Phase D reports read.

- [ ] **Step 1: Write the failing test**

Append to `test/data/models/sale_model_test.dart`:

```dart
group('motorcycleModel', () {
  test('round-trips through fromMap/toMap/toEntity', () {
    final map = {
      'saleNumber': 'S-1', 'paymentMethod': 'cash',
      'amountReceived': 100.0, 'changeGiven': 0.0, 'status': 'completed',
      'cashierId': 'u1', 'cashierName': 'C', 'motorcycleModel': 'Sniper 150',
    };
    final model = SaleModel.fromMap(map, 's1');
    expect(model.motorcycleModel, 'Sniper 150');
    expect(model.toMap()['motorcycleModel'], 'Sniper 150');
    expect(model.toEntity().motorcycleModel, 'Sniper 150');
  });

  test('is null when absent (legacy sale)', () {
    final model = SaleModel.fromMap(
      {'saleNumber': 'S-2', 'paymentMethod': 'cash', 'amountReceived': 0.0,
       'changeGiven': 0.0, 'status': 'completed', 'cashierId': 'u', 'cashierName': 'C'},
      's2',
    );
    expect(model.motorcycleModel, isNull);
    expect(model.toMap()['motorcycleModel'], isNull);
  });
});
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `flutter test test/data/models/sale_model_test.dart`
Expected: FAIL — `motorcycleModel` undefined.

- [ ] **Step 3: Implement — `SaleEntity`**

In `lib/domain/entities/sale_entity.dart`, mirror `mechanicName`:
- Field after `mechanicName` (~L36): `  /// Motorcycle model serviced (canonical name snapshot); null for walk-in sales.\n  final String? motorcycleModel;`
- Ctor param after `this.mechanicName,` (~L96): `    this.motorcycleModel,`
- `copyWith` param after `String? mechanicName,` (~L226): `    String? motorcycleModel,` and body after `mechanicName:` (~L254): `      motorcycleModel: motorcycleModel ?? this.motorcycleModel,`
- `props` after `mechanicName,` (~L297): `        motorcycleModel,`

- [ ] **Step 4: Implement — `SaleModel`**

In `lib/data/models/sale_model.dart`, mirror `mechanicName`:
- Field after `mechanicName` (~L19): `  final String? motorcycleModel;`
- Ctor param after `this.mechanicName,` (~L38): `    this.motorcycleModel,`
- `fromMap` after `mechanicName: map['mechanicName'] as String?,` (~L88): `      motorcycleModel: map['motorcycleModel'] as String?,`
- `toMap` base map after `'mechanicName': mechanicName,` (~L127): `      'motorcycleModel': motorcycleModel,`
- `toEntity` after `mechanicName: mechanicName,` (~L202): `      motorcycleModel: motorcycleModel,`
- `fromEntity` after `mechanicName: entity.mechanicName,` (~L233): `      motorcycleModel: entity.motorcycleModel,`
- `create()` factory: add param after `String? mechanicName,` (~L276): `    String? motorcycleModel,` and pass it in the returned `SaleModel(...)` after `mechanicName: mechanicName,` (~L293): `      motorcycleModel: motorcycleModel,`
- `copyWith` (~L360): add param `    String? motorcycleModel,` and body `      motorcycleModel: motorcycleModel ?? this.motorcycleModel,` (place alongside the `mechanicId`/`mechanicName` lines; do NOT gate it behind `clearMechanic`).

- [ ] **Step 5: Run test, verify pass; analyze**

Run: `flutter test test/data/models/sale_model_test.dart && flutter analyze lib/domain/entities/sale_entity.dart lib/data/models/sale_model.dart`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/sale_entity.dart lib/data/models/sale_model.dart test/data/models/sale_model_test.dart
git commit -m "feat(job-orders): add optional motorcycleModel to Sale entity+model"
```

---

### Task A3: thread `motorcycleModel` + `sourceDraftId` through the cart

Adds the field to `CartState`, a `setMotorcycleModel` mutator, and carries it (plus the now-set `sourceDraftId`) across `loadFromDraft` → `toSale`/`toDraft`. Setting `sourceDraftId` in `loadFromDraft` is the deliberate change that makes bill-out non-destructive (the sale gains a `draftId`, enabling convert-on-success in Task C4).

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart` — `CartState` field (~L52), ctor (~L64-80), props (~L82-99), `copyWith` (~L257-301), new `setMotorcycleModel` (near `setMechanic` ~L506), `loadFromDraft` (~L588-600), `toDraft` (~L603-621), `toSale` (~L623-647)
- Test: `test/presentation/providers/cart_provider_test.dart`

**Interfaces:**
- Consumes: `DraftEntity.motorcycleModel` (A1), `SaleEntity.motorcycleModel` (A2).
- Produces: `CartState.motorcycleModel`; `CartNotifier.setMotorcycleModel(String?)`; `loadFromDraft` now sets `sourceDraftId: draft.id` + `motorcycleModel`; `toSale`/`toDraft` carry `motorcycleModel`.

- [ ] **Step 1: Write the failing tests**

Append to `test/presentation/providers/cart_provider_test.dart` (mirror the existing setup that reads `cartProvider.notifier` via a `ProviderContainer`):

```dart
group('motorcycleModel + sourceDraftId threading', () {
  test('loadFromDraft carries model and sets sourceDraftId', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cartProvider.notifier);

    notifier.loadFromDraft(DraftEntity(
      id: 'draft-9', name: 'ABC-123', items: const [],
      motorcycleModel: 'Nmax', mechanicId: 'm1', mechanicName: 'Jun',
      createdBy: 'u', createdByName: 'C', createdAt: DateTime(2026, 7, 1),
    ));

    final s = container.read(cartProvider);
    expect(s.motorcycleModel, 'Nmax');
    expect(s.sourceDraftId, 'draft-9');
    expect(s.draftName, 'ABC-123');
  });

  test('setMotorcycleModel updates state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cartProvider.notifier);
    notifier.setMotorcycleModel('Aerox');
    expect(container.read(cartProvider).motorcycleModel, 'Aerox');
  });

  test('toSale carries motorcycleModel and draftId from a resumed ticket', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cartProvider.notifier);
    notifier.loadFromDraft(DraftEntity(
      id: 'draft-9', name: 'ABC-123',
      items: [/* one item so canCheckout is realistic */],
      motorcycleModel: 'Nmax',
      createdBy: 'u', createdByName: 'C', createdAt: DateTime(2026, 7, 1),
    ));
    final sale = notifier.toSale(saleNumber: '', cashierId: 'u', cashierName: 'C');
    expect(sale.motorcycleModel, 'Nmax');
    expect(sale.draftId, 'draft-9');
  });
});
```

- [ ] **Step 2: Run the tests, verify they fail**

Run: `flutter test test/presentation/providers/cart_provider_test.dart`
Expected: FAIL — `motorcycleModel`/`setMotorcycleModel` undefined; `sourceDraftId` null after load.

- [ ] **Step 3: Implement — `CartState`**

In `lib/presentation/providers/cart_provider.dart`:
- Add field near `mechanicName` (~L52): `  /// Motorcycle model on this ticket (canonical name); null for walk-ins.\n  final String? motorcycleModel;`
- Add to the ctor param list (~L64-80): `    this.motorcycleModel,`
- Add to `props` (~L82-99): `        motorcycleModel,`
- In `copyWith` (~L257-301): add param `    String? motorcycleModel,` and body line `      motorcycleModel: motorcycleModel ?? this.motorcycleModel,`

- [ ] **Step 4: Implement — mutator + threading**

- Add near `setMechanic` (~L506), mirroring it:

```dart
  /// Sets the motorcycle model on this ticket (canonical name).
  void setMotorcycleModel(String? model) {
    state = state.copyWith(
      motorcycleModel: model,
      clearErrorMessage: true,
    );
  }
```

- In `loadFromDraft` (~L588-600), add two entries to the `CartState(...)` constructor: `      sourceDraftId: draft.id,` and `      motorcycleModel: draft.motorcycleModel,`. Update the docstring: `sourceDraftId` is now set so bill-out can mark the source ticket converted (Task C4).
- In `toDraft` (~L603-621), add to the `DraftEntity(...)`: `      motorcycleModel: state.motorcycleModel,`
- In `toSale` (~L623-647), add to the `SaleEntity(...)`: `      motorcycleModel: state.motorcycleModel,` (the existing `draftId: state.sourceDraftId` now resolves to the real id).

- [ ] **Step 5: Run tests + broader cart suite, verify pass; analyze**

Run: `flutter test test/presentation/providers/cart_provider_test.dart test/presentation/providers/cart_labor_validation_test.dart test/presentation/providers/cart_tenders_test.dart && flutter analyze lib/presentation/providers/cart_provider.dart`
Expected: PASS (watch for any test that asserted `sourceDraftId`/`draftId` was null after load — update it to the new non-destructive behavior and note the change in the commit).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_provider_test.dart
git commit -m "feat(job-orders): thread motorcycleModel + sourceDraftId through cart (non-destructive bill-out groundwork)"
```

> **Interim-state note:** between this task and C4, the old destructive resume paths still call `deleteDraft` on load while the sale now carries a `draftId`. A resumed-then-billed sale in this window will log a benign "Draft conversion failed" warning (the draft was already deleted; the sale still completes). This resolves in C4 when the eager delete is removed. It is not shipped mid-way, so it's harmless — don't chase that warning during Phase A/B testing.

---

# Phase B — `motorcycle_models` collection + pick-or-add

A new admin-managed collection mirroring `mechanics`, **except** cashiers may create rows inline (pick-or-add) and rows carry a `normalizedName` for case-insensitive dedup. Ships the list, the picker, and the Settings editor — independently testable before it's wired into tickets (Phase C).

### Task B1: collection constant + name-normalization helpers

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart` (add constant near `mechanics`, ~L53)
- Create: `lib/core/utils/motorcycle_model_name.dart`
- Test: `test/core/utils/motorcycle_model_name_test.dart`

**Interfaces:**
- Produces: `FirestoreCollections.motorcycleModels` (`'motorcycle_models'`); `canonicalModelName(String)`, `normalizedModelKey(String)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/motorcycle_model_name_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';

void main() {
  test('canonicalModelName trims + collapses whitespace, keeps case', () {
    expect(canonicalModelName('  Nmax   155 '), 'Nmax 155');
    expect(canonicalModelName('Click'), 'Click');
  });

  test('normalizedModelKey lower-cases the canonical form', () {
    expect(normalizedModelKey('  nMaX '), 'nmax');
    expect(normalizedModelKey('Nmax'), normalizedModelKey(' n m a x'.replaceAll(' ', '')));
    expect(normalizedModelKey('Click 125i'), 'click 125i');
  });
}
```

- [ ] **Step 2: Run, verify fail** — `flutter test test/core/utils/motorcycle_model_name_test.dart` → FAIL (file missing).

- [ ] **Step 3: Implement**

Create `lib/core/utils/motorcycle_model_name.dart`:

```dart
/// Canonical display form for a motorcycle model name: trimmed, internal
/// whitespace collapsed to single spaces, original case preserved.
String canonicalModelName(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Case-insensitive dedup key. "  nmax " and "Nmax" produce the same key, so
/// pick-or-add reuses one canonical row instead of forking frequency counts.
String normalizedModelKey(String raw) => canonicalModelName(raw).toLowerCase();
```

Add to `lib/core/constants/firestore_collections.dart` after the `mechanics` constant (~L53), matching the camelCase-name / snake_case-value style:

```dart
  /// Motorcycle models collection - admin-managed + cashier-addable model list
  /// picked on Job Orders.
  static const String motorcycleModels = 'motorcycle_models';
```

- [ ] **Step 4: Run, verify pass** — `flutter test test/core/utils/motorcycle_model_name_test.dart && flutter analyze lib/core/utils/motorcycle_model_name.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/motorcycle_model_name.dart lib/core/constants/firestore_collections.dart test/core/utils/motorcycle_model_name_test.dart
git commit -m "feat(job-orders): motorcycle_models collection const + name normalization helpers"
```

---

### Task B2: `MotorcycleModelEntity`

**Files:**
- Create: `lib/domain/entities/motorcycle_model_entity.dart`
- Modify: `lib/domain/entities/entities.dart` (add export, ~L22)
- Test: `test/domain/entities/motorcycle_model_entity_test.dart` (mirror `mechanic_entity_test.dart`)

**Interfaces:**
- Produces: `MotorcycleModelEntity({id, name, isActive, createdAt, updatedAt?, createdBy?, updatedBy?})`, `.copyWith(...)`, `.empty()`.

- [ ] **Step 1: Write the failing test** — mirror `test/domain/entities/mechanic_entity_test.dart` (drop address/contact):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('copyWith + props + empty', () {
    final m = MotorcycleModelEntity(
      id: '1', name: 'Nmax', isActive: true, createdAt: DateTime(2026, 7, 1));
    expect(m.copyWith(name: 'Aerox').name, 'Aerox');
    expect(m.copyWith(isActive: false).isActive, isFalse);
    expect(m == m.copyWith(), isTrue);
    expect(MotorcycleModelEntity.empty().name, '');
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — create `lib/domain/entities/motorcycle_model_entity.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Admin-managed + cashier-addable motorcycle model, picked on a Job Order.
///
/// Inactive models drop off the picker but stay valid on history — the model
/// is snapshotted by *name* onto the draft/sale, never referenced by id.
class MotorcycleModelEntity extends Equatable {
  final String id;
  final String name; // canonical display, e.g. "Nmax"
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MotorcycleModelEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  MotorcycleModelEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MotorcycleModelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory MotorcycleModelEntity.empty() => MotorcycleModelEntity(
        id: '',
        name: '',
        isActive: true,
        createdAt: DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, name, isActive, createdAt, updatedAt, createdBy, updatedBy];
}
```

Add to `lib/domain/entities/entities.dart` (next to `export 'mechanic_entity.dart';`): `export 'motorcycle_model_entity.dart';`

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/motorcycle_model_entity.dart lib/domain/entities/entities.dart test/domain/entities/motorcycle_model_entity_test.dart
git commit -m "feat(job-orders): MotorcycleModelEntity"
```

---

### Task B3: `MotorcycleModelModel` (Firestore serialization)

Mirror `mechanic_model.dart`, dropping address/contact and **adding a `normalizedName` write** (the dedup query field). `normalizedName` is write-only (never read back — it's derived from `name`).

**Files:**
- Create: `lib/data/models/motorcycle_model_model.dart`
- Modify: `lib/data/models/models.dart` (add export, ~L23)
- Test: `test/data/models/motorcycle_model_model_test.dart` (mirror `mechanic_model_test.dart`)

**Interfaces:**
- Produces: `MotorcycleModelModel.fromFirestore/fromMap/toMap/toCreateMap/toUpdateMap/toEntity/fromEntity/copyWith`. `toMap` writes `name`, `normalizedName` (= `normalizedModelKey(name)`), `isActive`, timestamps, `createdBy`/`updatedBy`.

- [ ] **Step 1: Write the failing test:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('fromMap/toEntity round-trip', () {
    final m = MotorcycleModelModel.fromMap(
      {'name': 'Nmax', 'isActive': true}, 'id1');
    expect(m.name, 'Nmax');
    expect(m.isActive, isTrue);
    expect(m.toEntity().name, 'Nmax');
  });

  test('toMap writes a normalizedName dedup key', () {
    final m = MotorcycleModelModel.fromEntity(MotorcycleModelEntity(
      id: 'x', name: 'Click 125i', isActive: true, createdAt: DateTime(2026, 7, 1)));
    expect(m.toMap()['normalizedName'], normalizedModelKey('Click 125i'));
    expect(m.toMap()['name'], 'Click 125i');
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — create `lib/data/models/motorcycle_model_model.dart` (mirror `mechanic_model.dart`; note the `normalizedName` line in `toMap`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore serialization for [MotorcycleModelEntity].
class MotorcycleModelModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MotorcycleModelModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory MotorcycleModelModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      MotorcycleModelModel.fromMap(doc.data()!, doc.id);

  factory MotorcycleModelModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return MotorcycleModelModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false, bool forUpdate = false}) {
    final map = <String, dynamic>{
      'name': name,
      // Dedup key — derived, write-only. Enables case-insensitive lookup.
      'normalizedName': normalizedModelKey(name),
      'isActive': isActive,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
      map['updatedBy'] = createdBy;
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['updatedBy'] = updatedBy;
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }
    return map;
  }

  Map<String, dynamic> toCreateMap(String createdByUserId) =>
      copyWith(createdBy: createdByUserId).toMap(forCreate: true);

  Map<String, dynamic> toUpdateMap(String updatedByUserId) =>
      copyWith(updatedBy: updatedByUserId).toMap(forUpdate: true);

  MotorcycleModelEntity toEntity() => MotorcycleModelEntity(
        id: id,
        name: name,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
      );

  factory MotorcycleModelModel.fromEntity(MotorcycleModelEntity e) =>
      MotorcycleModelModel(
        id: e.id,
        name: e.name,
        isActive: e.isActive,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
      );

  MotorcycleModelModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MotorcycleModelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```

Add to `lib/data/models/models.dart` (next to `export 'mechanic_model.dart';`): `export 'motorcycle_model_model.dart';`

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/motorcycle_model_model.dart lib/data/models/models.dart test/data/models/motorcycle_model_model_test.dart
git commit -m "feat(job-orders): MotorcycleModelModel with normalizedName dedup key"
```

---

### Task B4: `MotorcycleModelRepository` + impl

Mirror `mechanic_repository.dart` / `mechanic_repository_impl.dart`. Differences: no `nameExists`; instead `findByNormalizedKey(key)` for pick-or-add resolution. `create` is a plain add (dedup is decided by the provider in Task B5, so the repo stays primitive).

**Files:**
- Create: `lib/domain/repositories/motorcycle_model_repository.dart`
- Create: `lib/data/repositories/motorcycle_model_repository_impl.dart`
- Modify: `lib/domain/repositories/repositories.dart` + `lib/data/repositories/repositories.dart` (barrel exports, if present — mirror how `mechanic_repository` is exported)
- Test: `test/data/repositories/motorcycle_model_repository_impl_test.dart` (mirror `mechanic_repository_impl_test.dart`, using `FakeFirebaseFirestore`)

**Interfaces:**
- Produces:
  - `Stream<List<MotorcycleModelEntity>> watchActive()` / `watchAll()`
  - `Future<MotorcycleModelEntity?> getById(String id)`
  - `Future<MotorcycleModelEntity> create({required MotorcycleModelEntity model, required String createdBy})`
  - `Future<MotorcycleModelEntity> update({required MotorcycleModelEntity model, required String updatedBy})`
  - `Future<void> setActive({required String id, required bool active, required String updatedBy})`
  - `Future<MotorcycleModelEntity?> findByNormalizedKey(String normalizedKey)`

- [ ] **Step 1: Write the failing test** (mirror `mechanic_repository_impl_test.dart`):

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/motorcycle_model_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MotorcycleModelRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = MotorcycleModelRepositoryImpl(firestore: db);
  });

  MotorcycleModelEntity model(String name) => MotorcycleModelEntity(
      id: '', name: name, isActive: true, createdAt: DateTime(2026, 7, 1));

  test('create persists + findByNormalizedKey matches case-insensitively',
      () async {
    await repo.create(model: model('Nmax'), createdBy: 'u1');
    final found = await repo.findByNormalizedKey('nmax');
    expect(found, isNotNull);
    expect(found!.name, 'Nmax');
  });

  test('findByNormalizedKey returns null when absent', () async {
    expect(await repo.findByNormalizedKey('aerox'), isNull);
  });

  test('watchActive excludes inactive + sorts A→Z', () async {
    await repo.create(model: model('Sniper'), createdBy: 'u');
    await repo.create(model: model('Aerox'), createdBy: 'u');
    final hidden = await repo.create(model: model('XRM'), createdBy: 'u');
    await repo.setActive(id: hidden.id, active: false, updatedBy: 'u');
    final list = await repo.watchActive().first;
    expect(list.map((m) => m.name), ['Aerox', 'Sniper']);
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the interface** — `lib/domain/repositories/motorcycle_model_repository.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Contract for the admin-managed + cashier-addable `motorcycle_models`
/// collection backing the Job Order model picker.
abstract class MotorcycleModelRepository {
  Stream<List<MotorcycleModelEntity>> watchActive();
  Stream<List<MotorcycleModelEntity>> watchAll();
  Future<MotorcycleModelEntity?> getById(String id);
  Future<MotorcycleModelEntity> create({
    required MotorcycleModelEntity model,
    required String createdBy,
  });
  Future<MotorcycleModelEntity> update({
    required MotorcycleModelEntity model,
    required String updatedBy,
  });
  Future<void> setActive({
    required String id,
    required bool active,
    required String updatedBy,
  });

  /// Finds a model by its case-insensitive dedup key (see [normalizedModelKey]).
  /// Returns null when none matches. Used by pick-or-add to reuse a row.
  Future<MotorcycleModelEntity?> findByNormalizedKey(String normalizedKey);
}
```

- [ ] **Step 4: Implement the impl** — `lib/data/repositories/motorcycle_model_repository_impl.dart` (mirror `MechanicRepositoryImpl`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/motorcycle_model_repository.dart';

class MotorcycleModelRepositoryImpl implements MotorcycleModelRepository {
  final FirebaseFirestore _firestore;
  MotorcycleModelRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.motorcycleModels);

  @override
  Stream<List<MotorcycleModelEntity>> watchActive() => _ref
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map(_sorted);

  @override
  Stream<List<MotorcycleModelEntity>> watchAll() =>
      _ref.snapshots().map(_sorted);

  @override
  Future<MotorcycleModelEntity?> getById(String id) async {
    try {
      final doc = await _ref.doc(id).get();
      if (!doc.exists) return null;
      return MotorcycleModelModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to get motorcycle model: ${e.message}',
          code: e.code, originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity> create({
    required MotorcycleModelEntity model,
    required String createdBy,
  }) async {
    try {
      final m = MotorcycleModelModel.fromEntity(model);
      final ref = await _ref.add(m.toCreateMap(createdBy));
      return model.copyWith(id: ref.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to create motorcycle model: ${e.message}',
          code: e.code, originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity> update({
    required MotorcycleModelEntity model,
    required String updatedBy,
  }) async {
    try {
      final m = MotorcycleModelModel.fromEntity(model);
      await _ref.doc(model.id).update(m.toUpdateMap(updatedBy));
      final updated = await getById(model.id);
      if (updated == null) {
        throw const DatabaseException(message: 'Model not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to update motorcycle model: ${e.message}',
          code: e.code, originalError: e);
    }
  }

  @override
  Future<void> setActive({
    required String id,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(id).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to set model active: ${e.message}',
          code: e.code, originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity?> findByNormalizedKey(
      String normalizedKey) async {
    try {
      final snap = await _ref
          .where('normalizedName', isEqualTo: normalizedKey)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return MotorcycleModelModel.fromFirestore(snap.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to look up motorcycle model: ${e.message}',
          code: e.code, originalError: e);
    }
  }

  List<MotorcycleModelEntity> _sorted(
          QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs
          .map((d) => MotorcycleModelModel.fromFirestore(d).toEntity())
          .toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
```

Add barrel exports next to the `mechanic_repository` lines in `lib/domain/repositories/repositories.dart` and `lib/data/repositories/repositories.dart` (if those barrels export the mechanic repo; match that pattern).

- [ ] **Step 5: Run, verify pass; analyze.**

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/motorcycle_model_repository.dart lib/data/repositories/motorcycle_model_repository_impl.dart lib/domain/repositories/repositories.dart lib/data/repositories/repositories.dart test/data/repositories/motorcycle_model_repository_impl_test.dart
git commit -m "feat(job-orders): MotorcycleModelRepository + Firestore impl (findByNormalizedKey)"
```

---

### Task B5: providers + `resolveOrCreate` (pick-or-add brain)

Mirror `mechanic_provider.dart`. The `resolveOrCreate` method is the pick-or-add core: normalize → reuse existing (reactivating if archived) → else create; returns the canonical name.

**Files:**
- Create: `lib/presentation/providers/motorcycle_model_provider.dart`
- Modify: `lib/presentation/providers/providers.dart` (add export, ~L25)
- Test: `test/presentation/providers/motorcycle_model_provider_test.dart` (mirror `mechanic_provider_test.dart`; override `motorcycleModelRepositoryProvider` with an impl over `FakeFirebaseFirestore`, and `currentUserProvider` with a signed-in user)

**Interfaces:**
- Produces: `motorcycleModelRepositoryProvider` (`Provider<MotorcycleModelRepository>`), `activeMotorcycleModelsProvider` (`StreamProvider<List<MotorcycleModelEntity>>`), `allMotorcycleModelsProvider`, `MotorcycleModelOperationsNotifier` + `motorcycleModelOperationsProvider` with `create/update/deactivate/reactivate/resolveOrCreate`.
- `Future<String?> resolveOrCreate(String rawName)` → canonical name, or `null` on empty/failure.

- [ ] **Step 1: Write the failing test:**

```dart
// Key cases (mirror mechanic_provider_test setup for overrides):
test('resolveOrCreate creates a new canonical model and returns its name', () async {
  final name = await ops.resolveOrCreate('  nmax ');
  expect(name, 'nmax'); // canonical (trim/collapse), case as typed
  expect((await repo.findByNormalizedKey('nmax'))!.name, 'nmax');
});

test('resolveOrCreate reuses an existing row (case-insensitive)', () async {
  await repo.create(model: MotorcycleModelEntity(
    id: '', name: 'Nmax', isActive: true, createdAt: DateTime(2026,7,1)), createdBy: 'u');
  final name = await ops.resolveOrCreate('NMAX');
  expect(name, 'Nmax'); // reused canonical, not a new fork
  final all = await repo.watchAll().first;
  expect(all.where((m) => normalizedModelKey(m.name) == 'nmax').length, 1);
});

test('resolveOrCreate reactivates an archived match', () async {
  final m = await repo.create(model: MotorcycleModelEntity(
    id: '', name: 'Beat', isActive: true, createdAt: DateTime(2026,7,1)), createdBy: 'u');
  await repo.setActive(id: m.id, active: false, updatedBy: 'u');
  await ops.resolveOrCreate('beat');
  expect((await repo.getById(m.id))!.isActive, isTrue);
});

test('resolveOrCreate returns null for blank input', () async {
  expect(await ops.resolveOrCreate('   '), isNull);
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — `lib/presentation/providers/motorcycle_model_provider.dart` (mirror `mechanic_provider.dart`; full operations notifier):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/data/repositories/motorcycle_model_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/motorcycle_model_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

final motorcycleModelRepositoryProvider =
    Provider<MotorcycleModelRepository>((ref) {
  return MotorcycleModelRepositoryImpl(
      firestore: ref.watch(firestoreProvider));
});

final activeMotorcycleModelsProvider =
    StreamProvider<List<MotorcycleModelEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(motorcycleModelRepositoryProvider).watchActive();
  });
});

final allMotorcycleModelsProvider =
    StreamProvider<List<MotorcycleModelEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(motorcycleModelRepositoryProvider).watchAll();
  });
});

class MotorcycleModelOperationsNotifier
    extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  MotorcycleModelOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  MotorcycleModelRepository get _repo =>
      _ref.read(motorcycleModelRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user.id;
  }

  /// Pick-or-add core: reuse an existing (reactivating if archived), else
  /// create. Returns the canonical name to store on the ticket, or null.
  Future<String?> resolveOrCreate(String rawName) async {
    final canonical = canonicalModelName(rawName);
    if (canonical.isEmpty) return null;
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final existing = await _repo.findByNormalizedKey(normalizedModelKey(rawName));
      if (existing != null) {
        if (!existing.isActive) {
          await _repo.setActive(
              id: existing.id, active: true, updatedBy: actorId);
        }
        state = const AsyncValue.data(null);
        return existing.name;
      }
      final created = await _repo.create(
        model: MotorcycleModelEntity(
            id: '', name: canonical, isActive: true, createdAt: DateTime.now()),
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created.name;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MotorcycleModelEntity?> create(
      {required MotorcycleModelEntity model}) async {
    state = const AsyncValue.loading();
    try {
      final created =
          await _repo.create(model: model, createdBy: _requireUserId());
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MotorcycleModelEntity?> update(
      {required MotorcycleModelEntity model}) async {
    state = const AsyncValue.loading();
    try {
      final updated =
          await _repo.update(model: model, updatedBy: _requireUserId());
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String id) => _setActive(id, false);
  Future<bool> reactivate(String id) => _setActive(id, true);

  Future<bool> _setActive(String id, bool active) async {
    state = const AsyncValue.loading();
    try {
      await _repo.setActive(
          id: id, active: active, updatedBy: _requireUserId());
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final motorcycleModelOperationsProvider = StateNotifierProvider<
    MotorcycleModelOperationsNotifier, AsyncValue<void>>((ref) {
  return MotorcycleModelOperationsNotifier(ref);
});
```

Add to `lib/presentation/providers/providers.dart` (next to `export 'mechanic_provider.dart';`): `export 'motorcycle_model_provider.dart';`

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/motorcycle_model_provider.dart lib/presentation/providers/providers.dart test/presentation/providers/motorcycle_model_provider_test.dart
git commit -m "feat(job-orders): motorcycle model providers + resolveOrCreate pick-or-add"
```

---

### Task B6: `MotorcycleModelPicker` (pick-or-add dropdown)

Mirror `mechanic_picker.dart` structurally (`ConsumerWidget`, parent owns selection via `onChanged`), but selection values are **model names** (String) and an extra "➕ Add model…" item opens a text dialog wired to `resolveOrCreate`.

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/motorcycle_model_picker.dart`
- Test: `test/presentation/widgets/motorcycle_model_picker_test.dart` (mirror `mechanic_picker_test.dart`)

**Interfaces:**
- Consumes: `activeMotorcycleModelsProvider`, `motorcycleModelOperationsProvider` (B5).
- Produces: `MotorcycleModelPicker({String? selectedModel, required void Function(String?) onChanged})`. `onChanged(name)` on pick; `onChanged(null)` for "— None —"; after "Add model…", `onChanged(canonicalName)`.

- [ ] **Step 1: Write the failing test** (mirror `mechanic_picker_test.dart`, overriding `activeMotorcycleModelsProvider` with a fixed list):

```dart
testWidgets('shows active models + reports selection by name', (tester) async {
  String? picked;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      activeMotorcycleModelsProvider.overrideWith((ref) => Stream.value([
        MotorcycleModelEntity(id: '1', name: 'Nmax', isActive: true, createdAt: DateTime(2026,7,1)),
        MotorcycleModelEntity(id: '2', name: 'Aerox', isActive: true, createdAt: DateTime(2026,7,1)),
      ])),
    ],
    child: MaterialApp(home: Scaffold(body: MotorcycleModelPicker(
      selectedModel: null, onChanged: (v) => picked = v))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(MotorcycleModelPicker));
  await tester.pumpAndSettle();
  expect(find.text('Nmax'), findsWidgets);
  await tester.tap(find.text('Aerox').last);
  await tester.pumpAndSettle();
  expect(picked, 'Aerox');
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — `lib/presentation/mobile/widgets/pos/motorcycle_model_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Pick-or-add dropdown for the motorcycle model on a Job Order. Values are
/// canonical model names (String). Selecting "Add model…" creates/reuses a row
/// via [MotorcycleModelOperationsNotifier.resolveOrCreate] and reports the name.
class MotorcycleModelPicker extends ConsumerWidget {
  const MotorcycleModelPicker({
    super.key,
    required this.selectedModel,
    required this.onChanged,
  });

  final String? selectedModel;
  final void Function(String? model) onChanged;

  static const _addNew = '__add_model__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeMotorcycleModelsProvider);
    return async.when(
      data: (models) {
        final names = models.map((m) => m.name).toList();
        // Keep a still-selected but deactivated model visible.
        final extra = (selectedModel != null && !names.contains(selectedModel))
            ? [selectedModel!]
            : const <String>[];
        return AppDropdown<String>(
          initialValue: selectedModel,
          decoration: const InputDecoration(
            labelText: 'Motorcycle model',
            prefixIcon: Icon(LucideIcons.bike),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('— None —')),
            for (final n in [...extra, ...names])
              DropdownMenuItem<String>(value: n, child: Text(n)),
            const DropdownMenuItem<String>(
              value: _addNew,
              child: Text('➕ Add model…'),
            ),
          ],
          onChanged: (value) async {
            if (value == _addNew) {
              final name = await _showAddDialog(context, ref);
              if (name != null) onChanged(name);
            } else {
              onChanged(value);
            }
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load models: $e'),
    );
  }

  Future<String?> _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (ctx) => AppDialog(
        title: 'Add motorcycle model',
        leadingIcon: LucideIcons.bike,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Model',
            hintText: 'e.g. Nmax, Click 125i',
          ),
        ),
        actions: [
          appDialogCancel(ctx, 'Cancel', onTap: () => Navigator.pop(ctx)),
          appDialogPrimary(ctx, 'Add', onTap: () async {
            final canonical = await ref
                .read(motorcycleModelOperationsProvider.notifier)
                .resolveOrCreate(controller.text);
            if (ctx.mounted) Navigator.pop(ctx, canonical);
          }),
        ],
      ),
    );
  }
}
```

> Note: confirm `AppDropdown` supports an `onChanged` that returns a `Future` (the mechanic picker's is sync). If it types `onChanged` as `void Function(T?)`, wrap the async work in an un-awaited closure: `onChanged: (v) { _handle(context, ref, v); }` with a private `Future<void> _handle(...)`. Adjust to match `app_dropdown.dart`'s actual signature.

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/motorcycle_model_picker.dart test/presentation/widgets/motorcycle_model_picker_test.dart
git commit -m "feat(job-orders): MotorcycleModelPicker pick-or-add dropdown"
```

---

### Task B7: Settings editor screen + route + Settings tile

Admin CRUD for the model list (rename / archive / reactivate). Mirror `mechanic_editor_screen.dart` (name-only form, no address/contact). Gate the route with `Permission.manageCategories` (same as the Mechanics editor). Add a Settings → Administration tile.

**Files:**
- Create: `lib/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart`
- Modify: `lib/config/router/route_names.dart` (`RouteNames.motorcycleModels` ~L157; `RoutePaths.motorcycleModels = '/settings/motorcycle-models'` ~L244)
- Modify: `lib/config/router/app_routes.dart` (import + child `GoRoute` under `/settings`, near the `mechanics` route ~L427)
- Modify: `lib/config/router/route_guards.dart` (`protectedRoutes` map: `'/settings/motorcycle-models': Permission.manageCategories` ~L62)
- Modify: `lib/presentation/mobile/screens/settings/settings_screen.dart` (add `SettingsTile` after the Mechanics tile ~L95)
- Test: `test/presentation/widgets/motorcycle_model_editor_screen_test.dart` (mirror `mechanic_editor_screen_test.dart`), `test/config/router/route_guards_motorcycle_models_test.dart` (mirror `route_guards_mechanics_test.dart`), `test/presentation/widgets/settings_motorcycle_models_tile_test.dart` (mirror `settings_mechanics_tile_test.dart`)

**Interfaces:**
- Consumes: `allMotorcycleModelsProvider`, `motorcycleModelOperationsProvider`, `motorcycleModelRepositoryProvider` (for the dedup check), `SettingsCrudRow`/`SettingsAddFab`.
- Produces: route `RouteNames.motorcycleModels` at `/settings/motorcycle-models`.

- [ ] **Step 1: Write failing tests** — mirror the three mechanic tests. Key assertions: editor renders the model list from `allMotorcycleModelsProvider`; the guard map requires `manageCategories` for `/settings/motorcycle-models`; the Administration tile "Motorcycle Models" is present for an admin.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the editor screen** — `lib/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart`, mirroring `mechanic_editor_screen.dart` with these changes: title `'Motorcycle Models'`; `allMotorcycleModelsProvider` / `motorcycleModelOperationsProvider`; `SettingsCrudRow(leadingIcon: LucideIcons.bike, ...)`; empty state icon `LucideIcons.bike`, title `'No motorcycle models yet'`; the form dialog has **only** a Name `TextFormField` (validator: non-empty, ≥2 chars). In `_save`, before create/update, run a dedup check (the repo has no server-side dedup on create):

```dart
final name = _nameController.text.trim();
final repo = ref.read(motorcycleModelRepositoryProvider);
final match = await repo.findByNormalizedKey(normalizedModelKey(name));
final existing = widget.existing;
final isDuplicate = match != null && (existing == null || match.id != existing.id);
if (isDuplicate) {
  if (mounted) context.showErrorSnackBar('A model with this name already exists');
  setState(() => _isSaving = false);
  return;
}
// else: ops.create(model: MotorcycleModelEntity(id:'', name: name, isActive: true, createdAt: DateTime.now()))
//   or   ops.update(model: existing.copyWith(name: name, isActive: _isActive))
```

Wrap the create/update through `context.runWithWaiting(...)` exactly as the mechanic editor does; success snackbars `'Model created'` / `'Model updated'`; toggle-active snackbars `'Model deactivated'` / `'Model reactivated'`. Import `motorcycle_model_name.dart` for `normalizedModelKey`.

- [ ] **Step 4: Wire the route** (three edits):
- `route_names.dart`: add `static const String motorcycleModels = 'motorcycleModels';` in `RouteNames` (near `mechanics`) and `static const String motorcycleModels = '/settings/motorcycle-models';` in `RoutePaths` (near `mechanics`).
- `app_routes.dart`: add `import '.../settings/motorcycle_model_editor_screen.dart';` and, inside the `/settings` route's `routes:` list next to the `mechanics` child:

```dart
GoRoute(
  path: 'motorcycle-models',
  name: RouteNames.motorcycleModels,
  builder: (context, state) => const MotorcycleModelEditorScreen(),
),
```

- `route_guards.dart`: add to the `protectedRoutes` map: `'/settings/motorcycle-models': Permission.manageCategories,`

- [ ] **Step 5: Add the Settings tile** — in `settings_screen.dart`, after the Mechanics `SettingsTile` (~L95):

```dart
SettingsTile(
  icon: LucideIcons.bike,
  title: 'Motorcycle Models',
  subtitle: 'Models picked on job orders',
  onTap: () => context.push(RoutePaths.motorcycleModels),
),
```

- [ ] **Step 6: Run all Phase-B tests + analyze:**

Run: `flutter test test/presentation/widgets/motorcycle_model_editor_screen_test.dart test/config/router/route_guards_motorcycle_models_test.dart test/presentation/widgets/settings_motorcycle_models_tile_test.dart && flutter analyze lib/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart lib/config/router lib/presentation/mobile/screens/settings/settings_screen.dart`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/settings/motorcycle_model_editor_screen.dart lib/config/router/route_names.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart lib/presentation/mobile/screens/settings/settings_screen.dart test/presentation/widgets/motorcycle_model_editor_screen_test.dart test/config/router/route_guards_motorcycle_models_test.dart test/presentation/widgets/settings_motorcycle_models_tile_test.dart
git commit -m "feat(job-orders): Motorcycle Models settings editor + gated route + tile"
```

---

### Task B8: `firestore.rules` — `motorcycle_models` block (DEPLOY-GATED)

**Files:**
- Modify: `firestore.rules` (add a block after the `mechanics` block, ~L290)

**Interfaces:** none (server rules).

- [ ] **Step 1: Add the rules block** — after the `mechanics` `match` block:

```
match /motorcycle_models/{modelId} {
  // Cashier-facing picker streams active models — read is not admin-only.
  allow read: if isValidUser() && isActiveUser();

  // Pick-or-add: any active user may create a model inline (like /drafts).
  allow create: if isValidUser() && isActiveUser() &&
    request.resource.data.createdBy == request.auth.uid;

  // Only admin manages the list (Settings → Motorcycle Models: rename / archive).
  allow update, delete: if isAdmin() && isActiveUser();
}
```

- [ ] **Step 2: (Optional) verify against the emulator** if the project runs `firebase emulators:exec` — otherwise validate syntax with `firebase deploy --only firestore:rules --dry-run` (does not publish).

- [ ] **Step 3: Commit (do NOT deploy yet)**

```bash
git add firestore.rules
git commit -m "feat(job-orders): firestore rules for motorcycle_models (cashier-create, admin-manage) [deploy-gated]"
```

> **STOP — deploy gate.** Publishing (`firebase deploy --only firestore:rules`) is production-affecting. **Confirm with the owner before deploying.** Until deployed + APK installed, pick-or-add creation of new models will be denied in prod. Reads of existing models still work.

---

# Phase C — Job Orders flow

The user-facing feature: rename, cart-independent creation, in-ticket parts, and safe bill-out. Depends on Phase A (field on cart/sale) and B (picker). Sub-phased C1→C4.

### Task C1: rename Drafts → Job Orders (user-facing strings + nav)

Pure user-facing copy. **Do not** rename routes, symbols, providers, or the collection. **Do not** touch receiving-drafts (`/receiving/drafts`, `receiving_summary_cards_row.dart`) — a different feature. The POS save-dialog strings (pos_screen.dart L664/L669/L681/L716) are handled in **C2** (that dialog is reworked there).

**Files & exact string edits:**

| File | Line | Change |
|------|------|--------|
| `drafts_list_screen.dart` | 28 | `'Saved Drafts'` → `'Job Orders'` |
| " | 34 | `'Failed to load drafts\n$error'` → `'Failed to load job orders\n$error'` |
| " | 49 | `'No Saved Drafts'` → `'No job orders yet'` |
| " | 50 | `'Drafts you save from the POS screen will appear here.'` → `'Open a job order for a bike being serviced and it\'ll appear here.'` |
| " | 184 | `'Couldn\'t remove the saved draft. Please try again.'` → `'Couldn\'t remove the job order. Please try again.'` |
| " | 220 | `'Draft deleted'` → `'Job order deleted'` |
| " | 222 | `'Failed to delete draft'` → `'Failed to delete job order'` |
| `draft_edit_screen.dart` | 93 | `'Loading Draft...'` → `'Loading…'` |
| " | 99 | `'Error loading draft: $error'` → `'Error loading job order: $error'` |
| " | 102 | `'Back to Drafts'` → `'Back to Job Orders'` |
| " | 109 | `'Draft Not Found'` → `'Job Order Not Found'` |
| " | 112 | `'Draft not found or has been deleted'` → `'Job order not found or has been deleted'` |
| " | 116 | `'Back to Drafts'` → `'Back to Job Orders'` |
| " | 132 | `'Deleting draft...'` → `'Deleting…'` |
| " | 157 | tooltip `'Delete Draft'` → `'Delete Job Order'` |
| " | 247 | `'No items in this draft'` → `'No parts on this job order yet'` |
| " | 561, 591 | `'Error loading draft: $e'` → `'Error loading job order: $e'` |
| " | 615 | `'Draft deleted'` → `'Job order deleted'` |
| " | 621 | `'Error deleting draft: $e'` → `'Error deleting job order: $e'` |
| `draft_list_tile.dart` | 125 | tooltip `'Delete draft'` → `'Delete job order'` |
| `draft_dialogs.dart` | 32 | title `'Delete draft?'` → `'Delete job order?'` |
| `pos_screen.dart` | 513 | button `'Save Draft'` → `'Save Job Order'` |
| " | 557 | tooltip `'Drafts'` → `'Job Orders'` |
| `route_guards.dart` | 227 | nav menu label `'Drafts'` → `'Job Orders'` |

- [ ] **Step 1: Write/adjust the failing test** — in `test/presentation/widgets/drafts_list_load_test.dart` (or a new `drafts_list_title_test.dart`), assert the list AppBar renders `'Job Orders'`. Also grep existing tests for stale copy that will now fail: `grep -rn "Saved Drafts\|Save Draft\|Draft deleted\|No Saved Drafts" test/` and update those expectations to the new strings in this same task.

- [ ] **Step 2: Run, verify fail** — `flutter test test/presentation/widgets/drafts_list_load_test.dart` → FAIL (expects 'Job Orders').

- [ ] **Step 3: Apply all string edits** from the table above.

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/presentation/widgets/drafts_list_load_test.dart test/presentation/widgets/draft_list_tile_test.dart && flutter analyze lib/presentation/mobile/screens/drafts lib/presentation/mobile/widgets/drafts lib/config/router/route_guards.dart`
Expected: PASS, clean. (If `route_guards.dart` nav uses `Icons.drafts`, optionally switch to `LucideIcons.clipboardList` for consistency — cosmetic, not required.)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/drafts lib/presentation/mobile/widgets/drafts lib/presentation/mobile/screens/pos/pos_screen.dart lib/config/router/route_guards.dart test/
git commit -m "feat(job-orders): rename Drafts -> Job Orders (user-facing copy + nav)"
```

---

### Task C2: cart-independent "New Job Order" + model on the save-from-cart dialog

Two creation paths: (a) a **"New Job Order"** FAB on the list that captures label + model + mechanic and opens the editor on a fresh empty ticket; (b) the reworked POS **"Save as Job Order"** dialog gains the model picker and the relabelled field.

**Files:**
- Create: `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart`
- Modify: `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` (add the FAB + handler)
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart` (`_showSaveDraftDialog` ~L647-690: Column body, model picker, relabel; `_saveDraft` ~L692-719 strings)
- Test: `test/presentation/widgets/new_job_order_dialog_test.dart`

**Interfaces:**
- Consumes: `MotorcycleModelPicker` (B6), `MechanicPicker`, `draftOperationsProvider.createDraft`, `cartProvider.notifier.setMotorcycleModel` (A3), `RouteNames.draftEdit`.
- Produces: `showNewJobOrderDialog(context) → Future<NewJobOrderInput?>` and `class NewJobOrderInput { String label; String? model; String? mechanicId; String? mechanicName; }`.

- [ ] **Step 1: Write the failing test:**

```dart
testWidgets('New Job Order dialog requires a label and returns input', (tester) async {
  NewJobOrderInput? result;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      activeMotorcycleModelsProvider.overrideWith((r) => Stream.value(const [])),
      activeMechanicsProvider.overrideWith((r) => Stream.value(const [])),
    ],
    child: MaterialApp(home: Builder(builder: (ctx) => Scaffold(
      body: Center(child: ElevatedButton(
        onPressed: () async => result = await showNewJobOrderDialog(ctx),
        child: const Text('open'))),
    ))),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  // Create with empty label → blocked (dialog stays, warning shown)
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  expect(find.byType(TextField), findsWidgets); // still open

  await tester.enterText(find.byType(TextField).first, 'ABC-123');
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  expect(result?.label, 'ABC-123');
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the dialog** — `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/context_extensions.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

class NewJobOrderInput {
  const NewJobOrderInput({
    required this.label,
    this.model,
    this.mechanicId,
    this.mechanicName,
  });
  final String label;
  final String? model;
  final String? mechanicId;
  final String? mechanicName;
}

Future<NewJobOrderInput?> showNewJobOrderDialog(BuildContext context) {
  return showDialog<NewJobOrderInput>(
    context: context,
    barrierColor: AppDialog.scrimColor(
        Theme.of(context).brightness == Brightness.dark),
    builder: (_) => const _NewJobOrderDialog(),
  );
}

class _NewJobOrderDialog extends ConsumerStatefulWidget {
  const _NewJobOrderDialog();
  @override
  ConsumerState<_NewJobOrderDialog> createState() => _NewJobOrderDialogState();
}

class _NewJobOrderDialogState extends ConsumerState<_NewJobOrderDialog> {
  final _labelController = TextEditingController();
  String? _model;
  String? _mechanicId;
  String? _mechanicName;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New Job Order',
      leadingIcon: LucideIcons.clipboardList,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer / plate',
              hintText: 'e.g. Juan / ABC-123',
            ),
          ),
          const SizedBox(height: 12),
          MotorcycleModelPicker(
            selectedModel: _model,
            onChanged: (m) => setState(() => _model = m),
          ),
          const SizedBox(height: 12),
          MechanicPicker(
            selectedMechanicId: _mechanicId,
            onChanged: (m) => setState(() {
              _mechanicId = m?.id;
              _mechanicName = m?.name;
            }),
          ),
        ],
      ),
      actions: [
        appDialogCancel(context, 'Cancel', onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, 'Create', onTap: () {
          final label = _labelController.text.trim();
          if (label.isEmpty) {
            context.showWarningSnackBar('Enter a customer or plate label');
            return;
          }
          Navigator.pop(
            context,
            NewJobOrderInput(
              label: label,
              model: _model,
              mechanicId: _mechanicId,
              mechanicName: _mechanicName,
            ),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 4: Wire the FAB** in `drafts_list_screen.dart` — add `floatingActionButton: SettingsAddFab(label: 'New Job Order', onPressed: () => _createJobOrder(context))` (import `SettingsAddFab` from `settings_crud_row.dart`), and the handler:

```dart
Future<void> _createJobOrder(BuildContext context) async {
  final input = await showNewJobOrderDialog(context);
  if (input == null) return;
  final user = ref.read(currentUserProvider).valueOrNull;
  if (user == null) return;
  final draft = DraftEntity(
    id: '',
    name: input.label,
    items: const [],
    motorcycleModel: input.model,
    mechanicId: input.mechanicId,
    mechanicName: input.mechanicName,
    createdBy: user.id,
    createdByName: user.displayName,
    createdAt: DateTime.now(),
  );
  final created = await context.runWithWaiting(
    () => ref.read(draftOperationsProvider.notifier)
        .createDraft(actor: user, draft: draft),
    message: 'Creating…',
  );
  if (created != null && context.mounted) {
    context.pushNamed(RouteNames.draftEdit, pathParameters: {'id': created.id});
  }
}
```

- [ ] **Step 5: Rework the POS save-from-cart dialog** — in `pos_screen.dart` `_showSaveDraftDialog` (~L647): wrap the `content:` in a `StatefulBuilder` + `Column(mainAxisSize: min, children: [...])`; relabel the name field `labelText: 'Customer / plate'`; add a `MotorcycleModelPicker(selectedModel: pickedModel, onChanged: (m) => setLocal(() => pickedModel = m))` below it. On Save: `if (name.isEmpty) { context.showWarningSnackBar('Enter a customer or plate label'); return; }` then `ref.read(cartProvider.notifier).setMotorcycleModel(pickedModel);` then `Navigator.pop(context); _saveDraft(name);`. In `_saveDraft`, change snackbars to `'Job order updated'` / `'Job order saved'`. (Title `'Save as Job Order'`.)

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/presentation/widgets/new_job_order_dialog_test.dart && flutter analyze lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart lib/presentation/mobile/screens/drafts/drafts_list_screen.dart lib/presentation/mobile/screens/pos/pos_screen.dart`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart lib/presentation/mobile/screens/drafts/drafts_list_screen.dart lib/presentation/mobile/screens/pos/pos_screen.dart test/presentation/widgets/new_job_order_dialog_test.dart
git commit -m "feat(job-orders): cart-independent New Job Order + model on save-from-cart dialog"
```

---

### Task C3a: editable parts in the ticket editor (qty / remove)

The editor's item rows are read-only. Make them adjustable (+/- quantity, remove), each change persisted in place via the existing full `updateDraft` path. Rename the misnamed `_persistLabor` → `_persist` (it already persists the whole draft).

**Files:**
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`_persistLabor`→`_persist` ~L49; `_buildDraftItem` ~L255)
- Test: `test/presentation/widgets/draft_edit_screen_items_test.dart` (mirror `draft_edit_screen_labor_test.dart`)

**Interfaces:**
- Consumes: `DraftEntity.updateItemQuantity(itemId, qty)`, `.removeItem(itemId)`, `.addItem(item)` (already on the entity), `draftOperationsProvider.updateDraft`.
- Produces: editable item rows persisting via `_persist`.

- [ ] **Step 1: Write the failing test** (mirror `draft_edit_screen_labor_test.dart` — override `draftByIdProvider` with a one-item draft and spy on `draftOperationsProvider`):

```dart
testWidgets('tapping + on a part persists an increased quantity', (tester) async {
  // Pump DraftEditScreen with a draft holding one item (qty 1) via overrides.
  // Tap the increment button.
  await tester.tap(find.byTooltip('Increase quantity'));
  await tester.pumpAndSettle();
  // Verify updateDraft was called with that item at qty 2 (spy notifier).
  expect(lastSavedDraft!.items.first.quantity, 2);
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Rename + add handlers** — in `draft_edit_screen.dart`, rename `_persistLabor` to `_persist` (update its 3 call sites in `_onMechanicChanged`, `_addOrEditLabor`, `_removeLabor`). Add:

```dart
Future<void> _changeQty(DraftEntity draft, SaleItemEntity item, int delta) =>
    _persist(draft.updateItemQuantity(item.id, item.quantity + delta));

Future<void> _removeItem(DraftEntity draft, String itemId) =>
    _persist(draft.removeItem(itemId));
```

- [ ] **Step 4: Make the item row interactive** — change `_buildDraftItem(SaleItemEntity item)` to `_buildDraftItem(DraftEntity draft, SaleItemEntity item)` (update the caller at ~L221) and add, in the row, a compact stepper + remove using the existing icon-button style (mirror the labor row's `LucideIcons.x`), e.g. after the price `Text`:

```dart
IconButton(
  icon: const Icon(LucideIcons.minus, size: 16),
  visualDensity: VisualDensity.compact,
  tooltip: 'Decrease quantity',
  onPressed: () => _changeQty(draft, item, -1), // qty 0 removes via entity
),
Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
IconButton(
  icon: const Icon(LucideIcons.plus, size: 16),
  visualDensity: VisualDensity.compact,
  tooltip: 'Increase quantity',
  onPressed: () => _changeQty(draft, item, 1),
),
IconButton(
  icon: const Icon(LucideIcons.x, size: 16),
  visualDensity: VisualDensity.compact,
  tooltip: 'Remove part',
  onPressed: () => _removeItem(draft, item.id),
),
```

(Keep the existing `AppCard` layout; wrap the trailing controls in a `Row(mainAxisSize: min)` so they fit.)

- [ ] **Step 5: Run test + analyze** — `flutter test test/presentation/widgets/draft_edit_screen_items_test.dart test/presentation/widgets/draft_edit_screen_labor_test.dart && flutter analyze lib/presentation/mobile/screens/drafts/draft_edit_screen.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/drafts/draft_edit_screen.dart test/presentation/widgets/draft_edit_screen_items_test.dart
git commit -m "feat(job-orders): editable parts (qty/remove) in the ticket editor"
```

---

### Task C3b: "Add parts" in the editor + drop "Edit in POS"

Add a product search/scan entry to the editor that appends a part to the ticket (no cart), then remove the now-redundant destructive "Edit in POS".

**Files:**
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (add "Add parts" button in the items-section header; remove the `Edit in POS` `OutlinedButton` ~L513-520 and the `_editInPos` method ~L540-568)
- Possibly create: `lib/presentation/mobile/widgets/pos/product_search_sheet.dart` **only if** the POS product search isn't already a reusable widget (see Step 1)
- Test: `test/presentation/widgets/draft_edit_screen_addparts_test.dart`

**Interfaces:**
- Consumes: the POS product-search surface + the `ProductEntity → SaleItemEntity` conversion (identified in Step 1); `DraftEntity.addItem`; `_persist` (C3a).

- [ ] **Step 1: Identify the reuse points** — read `lib/presentation/mobile/screens/pos/pos_screen.dart` and `lib/presentation/providers/cart_provider.dart` to find: (i) the product-search widget/sheet the POS opens to add a product, and (ii) exactly how a chosen `ProductEntity` becomes a `SaleItemEntity` (e.g. `cartNotifier.addProduct(product)` or a `SaleItemEntity.fromProduct(...)` factory). If the search UI is inlined in `pos_screen`, extract the minimal reusable piece into `product_search_sheet.dart` returning the chosen `ProductEntity` (or `SaleItemEntity`). Record the conversion signature here before coding the rest.

- [ ] **Step 2: Write the failing test** — pump the editor, invoke the add-parts handler with a fixed `ProductEntity` (bypass the search UI by calling the handler directly or via an injected callback), assert `updateDraft` was called with the item appended:

```dart
testWidgets('adding a product appends it to the ticket and persists', (tester) async {
  // Pump DraftEditScreen (empty draft). Trigger _addProduct with a test product.
  // Assert the spy's last saved draft has 1 item matching the product.
  expect(lastSavedDraft!.items.single.productId, 'p1');
});
```

- [ ] **Step 3: Implement the add handler** using the conversion from Step 1:

```dart
Future<void> _addProduct(DraftEntity draft, ProductEntity product) {
  // Build the SaleItemEntity exactly as the POS cart does (Step 1 conversion).
  final item = saleItemFromProduct(product, quantity: 1); // <- confirmed in Step 1
  return _persist(draft.addItem(item)); // addItem merges same-product qty
}

Future<void> _onAddPartsPressed(DraftEntity draft) async {
  final product = await showProductSearchSheet(context); // reuse/extract (Step 1)
  if (product != null) await _addProduct(draft, product);
}
```

Add an "Add parts" `TextButton.icon(icon: LucideIcons.plus, label: Text('Add parts'))` in the items-section header (mirror the "Add Labor" button in `_buildLaborSection`, ~L358), calling `_onAddPartsPressed(draft)`.

- [ ] **Step 4: Remove "Edit in POS"** — delete the `OutlinedButton.icon(... 'Edit in POS' ...)` from `_buildSummarySection` (~L513-520) and delete the `_editInPos` method (~L540-568). Leave the primary action button (it becomes "Bill out" in C4). Adjust the button `Row` so the remaining action spans the width.

- [ ] **Step 5: Run tests + analyze.**

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/drafts/draft_edit_screen.dart lib/presentation/mobile/widgets/pos/product_search_sheet.dart test/presentation/widgets/draft_edit_screen_addparts_test.dart
git commit -m "feat(job-orders): in-ticket Add parts (search/scan); drop destructive Edit in POS"
```

---

### Task C4: non-destructive bill-out (gate + guard + convert-on-success)

Turn the editor's "Checkout" into "Bill out": require the model, warn if the register is busy, load into the cart **without deleting**, and let the existing `_reconcileDraft` mark the ticket converted after a successful sale (the sale now carries `draftId` from `sourceDraftId`, set in A3).

**Files:**
- Create: `lib/core/utils/job_order_bill_out.dart` (pure gate helper)
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`_proceedToCheckout`→`_billOut` ~L570-598; button label ~L529)
- Modify: `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` (ensure tile→editor; remove destructive `_performLoadDraft` load-to-cart+delete if present ~L169-178)
- Verify/Modify: the Job Orders list provider excludes converted tickets (see Step 5)
- Test: `test/core/utils/job_order_bill_out_test.dart`, `test/domain/usecases/pos/process_sale_convert_test.dart`

**Interfaces:**
- Consumes: `cartProvider` (`isNotEmpty`, `loadFromDraft` now sets `sourceDraftId`), `ProcessSaleUseCase._reconcileDraft` (already gated on `sale.draftId`), `markDraftAsConverted`.
- Produces: `bool jobOrderReadyToBillOut(DraftEntity)`; `_billOut` handler.

- [ ] **Step 1: Write the failing tests**

`test/core/utils/job_order_bill_out_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/job_order_bill_out.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

DraftEntity draft({String? model, List<SaleItemEntity> items = const []}) =>
    DraftEntity(id: 'd', name: 'X', items: items, motorcycleModel: model,
        createdBy: 'u', createdByName: 'C', createdAt: DateTime(2026, 7, 1));

void main() {
  test('needs a motorcycle model', () {
    expect(jobOrderReadyToBillOut(draft(model: null)), isFalse);
    expect(jobOrderReadyToBillOut(draft(model: '  ')), isFalse);
    expect(jobOrderReadyToBillOut(draft(model: 'Nmax')), isTrue);
  });
}
```

`test/domain/usecases/pos/process_sale_convert_test.dart` (mirror existing process-sale tests with mocktail mocks of `SaleRepository` + `DraftRepository`):

```dart
test('marks the source draft converted when the sale carries a draftId', () async {
  when(() => saleRepo.createSale(any(), id: any(named: 'id'), decrementStock: any(named: 'decrementStock')))
      .thenAnswer((_) async => sampleSale.copyWith(id: 'sale1'));
  when(() => draftRepo.markDraftAsConverted(draftId: any(named: 'draftId'), saleId: any(named: 'saleId')))
      .thenAnswer((_) async => anyDraft);

  await useCase.execute(sale: sampleSale.copyWith(draftId: 'draft9'), checkoutId: 'c1');

  verify(() => draftRepo.markDraftAsConverted(draftId: 'draft9', saleId: 'sale1')).called(1);
});

test('does not convert when there is no draftId (walk-in)', () async {
  when(() => saleRepo.createSale(any(), id: any(named: 'id'), decrementStock: any(named: 'decrementStock')))
      .thenAnswer((_) async => sampleSale.copyWith(id: 'sale2'));
  await useCase.execute(sale: sampleSale, checkoutId: 'c2'); // draftId null
  verifyNever(() => draftRepo.markDraftAsConverted(draftId: any(named: 'draftId'), saleId: any(named: 'saleId')));
});
```

- [ ] **Step 2: Run, verify fail.** (The convert test may already pass if `_reconcileDraft` works — that's fine; it's a regression guard for the now-live path. The gate-helper test fails until Step 3.)

- [ ] **Step 3: Implement the gate helper** — `lib/core/utils/job_order_bill_out.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';

/// A Job Order can be billed out only once its motorcycle model is set
/// (decision #5). The item-count requirement is enforced separately by the
/// checkout flow's existing "items required" rule.
bool jobOrderReadyToBillOut(DraftEntity draft) =>
    (draft.motorcycleModel?.trim().isNotEmpty ?? false);
```

- [ ] **Step 4: Rework the bill-out handler** — in `draft_edit_screen.dart`, rename `_proceedToCheckout` to `_billOut` and rewrite (drop the `deleteDraft` call; add the gate + cart-busy guard):

```dart
Future<void> _billOut(DraftEntity draft) async {
  if (!jobOrderReadyToBillOut(draft)) {
    context.showWarningSnackBar('Set the motorcycle model to bill out');
    return;
  }
  final cart = ref.read(cartProvider);
  if (cart.isNotEmpty) {
    final proceed = await showConfirmDialog(
      context,
      title: 'Register in use',
      message: 'There is an unfinished sale in the register. '
          'Bill out this job order anyway? The current sale will be cleared.',
    );
    if (proceed != true) return;
  }
  ref.read(cartProvider.notifier).loadFromDraft(draft); // sets sourceDraftId; NO delete
  ref.read(selectedDraftProvider.notifier).state = null;
  if (mounted) context.go(RoutePaths.checkout);
}
```

(Use the project's existing confirm-dialog helper; if none matches, mirror `showDeleteDraftDialog`'s shape with a neutral intent.) Change the primary action button label from `'Checkout'` to `'Bill out'` and point `onPressed` at `_billOut` (~L524-529). Keep `draft.items.isEmpty ? null : ...` so an empty ticket stays non-billable.

- [ ] **Step 5: Ensure converted tickets leave the list** — read the Job Orders list provider (`activeDraftsProvider` in `draft_provider.dart`). Confirm it filters `where((d) => !d.isConverted)` (or the query filters `isConverted == false`). If it does **not**, add that filter so a billed-out ticket disappears from the list. Also confirm the list **tile tap** opens the editor (`RouteNames.draftEdit`); if `drafts_list_screen` still has a destructive `_performLoadDraft` (loadFromDraft + deleteDraft) as the tap action, replace it with navigation to the editor and delete that method.

- [ ] **Step 6: Run the focused + full suite + analyze**

Run: `flutter test test/core/utils/job_order_bill_out_test.dart test/domain/usecases/pos/process_sale_convert_test.dart test/presentation/widgets/draft_edit_screen_labor_test.dart && flutter analyze lib/presentation/mobile/screens/drafts lib/core/utils/job_order_bill_out.dart`
Then the whole suite: `flutter test`
Expected: PASS. (Fix any older draft test that assumed destructive resume / deletion-on-load.)

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/job_order_bill_out.dart lib/presentation/mobile/screens/drafts test/core/utils/job_order_bill_out_test.dart test/domain/usecases/pos/process_sale_convert_test.dart
git commit -m "feat(job-orders): non-destructive bill-out (model gate, cart-busy guard, convert-on-success)"
```

> **Known v1 limitation:** a pure-labor ticket (no parts) is not billable — the sale write still requires ≥1 item. Add a nominal part, or lift the items-required rule in a fast-follow.

---

# Phase D — Reports (Motorcycle Models + Top Mechanics)

Two admin-only reports over completed sales for the selected period, mirroring the Labor report's derived-provider + pure-helper pattern. Depends only on Phase A (the `motorcycleModel` on the sale).

> **Design refinement vs spec:** the Models report **excludes** sales with no model (i.e. walk-ins) rather than bucketing them as "Unspecified" — post-feature, sales-with-a-model are exactly the billed-out Job Orders, which is what "frequent models" means. (Supersedes the spec's transitional "Unspecified" note.)

> **Pre-existing caveat:** `salesByDateRangeProvider` fetches with `getSalesByDateRange`'s default `limit: 100`. Both new reports inherit this cap (as the Labor/Sales reports already do). Raising it affects all reports and is out of scope here — note it and move on.

### Task D1: `motorcycleModelReportFromSales` helper

**Files:**
- Create: `lib/core/utils/motorcycle_model_report.dart`
- Test: `test/core/utils/motorcycle_model_report_test.dart` (mirror `labor_report_test.dart`)

**Interfaces:**
- Produces: `MotorcycleModelReportData { int totalJobs; double totalRevenue; List<MotorcycleModelStat> byModel; }`, `MotorcycleModelStat { String model; int jobCount; double totalRevenue; double laborTotal; }`, `motorcycleModelReportFromSales(List<SaleEntity>)`.

- [ ] **Step 1: Write the failing test:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
// build SaleEntity helpers mirroring labor_report_test.dart

void main() {
  test('groups by model, excludes voided + model-less, sorts by jobCount desc', () {
    final sales = [
      sale(model: 'Nmax', total: 100, labor: 40),
      sale(model: 'Nmax', total: 60, labor: 0),
      sale(model: 'Click', total: 200, labor: 100),
      sale(model: null, total: 999, labor: 0),         // walk-in → excluded
      sale(model: 'Click', total: 10, labor: 0, voided: true), // excluded
    ];
    final r = motorcycleModelReportFromSales(sales);
    expect(r.byModel.map((m) => m.model), ['Nmax', 'Click']); // 2 jobs vs 1
    expect(r.byModel.first.jobCount, 2);
    expect(r.byModel.first.totalRevenue, 160);
    expect(r.totalJobs, 3);
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — `lib/core/utils/motorcycle_model_report.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

class MotorcycleModelStat {
  final String model;
  final int jobCount;
  final double totalRevenue;
  final double laborTotal;
  const MotorcycleModelStat({
    required this.model,
    required this.jobCount,
    required this.totalRevenue,
    required this.laborTotal,
  });
}

class MotorcycleModelReportData {
  final int totalJobs;
  final double totalRevenue;
  final List<MotorcycleModelStat> byModel; // jobCount desc, ties by name asc
  const MotorcycleModelReportData({
    required this.totalJobs,
    required this.totalRevenue,
    required this.byModel,
  });
  factory MotorcycleModelReportData.empty() =>
      const MotorcycleModelReportData(totalJobs: 0, totalRevenue: 0, byModel: []);
}

/// Groups billed-out Job Orders by motorcycle model. Voided sales and sales
/// with no model (walk-ins) are excluded.
MotorcycleModelReportData motorcycleModelReportFromSales(
    List<SaleEntity> sales) {
  final buckets = <String, _Bucket>{};
  int totalJobs = 0;
  double totalRevenue = 0;

  for (final s in sales) {
    if (s.isVoided) continue;
    final model = s.motorcycleModel?.trim() ?? '';
    if (model.isEmpty) continue;

    final b = buckets.putIfAbsent(model, () => _Bucket(model));
    b.jobCount++;
    b.totalRevenue += s.grandTotal;
    b.laborTotal += s.laborRevenue;
    totalJobs++;
    totalRevenue += s.grandTotal;
  }

  final byModel = buckets.values
      .map((b) => MotorcycleModelStat(
            model: b.model,
            jobCount: b.jobCount,
            totalRevenue: b.totalRevenue,
            laborTotal: b.laborTotal,
          ))
      .toList()
    ..sort((a, b) {
      final c = b.jobCount.compareTo(a.jobCount);
      return c != 0 ? c : a.model.toLowerCase().compareTo(b.model.toLowerCase());
    });

  return MotorcycleModelReportData(
      totalJobs: totalJobs, totalRevenue: totalRevenue, byModel: byModel);
}

class _Bucket {
  final String model;
  int jobCount = 0;
  double totalRevenue = 0;
  double laborTotal = 0;
  _Bucket(this.model);
}
```

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/motorcycle_model_report.dart test/core/utils/motorcycle_model_report_test.dart
git commit -m "feat(job-orders): motorcycleModelReportFromSales aggregation"
```

---

### Task D2: `mechanicPerformanceReportFromSales` helper

Ranks mechanics by **total revenue (parts + labor)** (decision #6). Includes only sales with a `mechanicId`; excludes voided. Distinct from `labor_report.dart` (labor-only, ranked by labor).

**Files:**
- Create: `lib/core/utils/mechanic_performance_report.dart`
- Test: `test/core/utils/mechanic_performance_report_test.dart`

**Interfaces:**
- Produces: `MechanicPerformanceReportData { double totalRevenue; int jobCount; List<MechanicPerformanceStat> byMechanic; }`, `MechanicPerformanceStat { String? mechanicId; String mechanicName; int jobCount; double totalRevenue; double laborTotal; }`, `mechanicPerformanceReportFromSales(List<SaleEntity>)`.

- [ ] **Step 1: Write the failing test:**

```dart
test('groups by mechanic, ranks by total revenue desc, excludes no-mechanic + voided', () {
  final sales = [
    sale(mechId: 'm1', mechName: 'Jun', total: 100, labor: 40),
    sale(mechId: 'm1', mechName: 'Jun', total: 50, labor: 10),
    sale(mechId: 'm2', mechName: 'Ray', total: 300, labor: 0),
    sale(mechId: null, total: 999, labor: 0),               // excluded
    sale(mechId: 'm2', mechName: 'Ray', total: 10, voided: true), // excluded
  ];
  final r = mechanicPerformanceReportFromSales(sales);
  expect(r.byMechanic.map((m) => m.mechanicName), ['Ray', 'Jun']); // 300 vs 150
  expect(r.byMechanic.last.jobCount, 2);
  expect(r.byMechanic.last.totalRevenue, 150);
  expect(r.byMechanic.last.laborTotal, 50);
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — `lib/core/utils/mechanic_performance_report.dart` (mirror D1's shape; key differences: filter on `mechanicId`, sort by `totalRevenue`):

```dart
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

class MechanicPerformanceStat {
  final String? mechanicId;
  final String mechanicName;
  final int jobCount;
  final double totalRevenue;
  final double laborTotal;
  const MechanicPerformanceStat({
    required this.mechanicId,
    required this.mechanicName,
    required this.jobCount,
    required this.totalRevenue,
    required this.laborTotal,
  });
}

class MechanicPerformanceReportData {
  final double totalRevenue;
  final int jobCount;
  final List<MechanicPerformanceStat> byMechanic; // totalRevenue desc
  const MechanicPerformanceReportData({
    required this.totalRevenue,
    required this.jobCount,
    required this.byMechanic,
  });
  factory MechanicPerformanceReportData.empty() =>
      const MechanicPerformanceReportData(
          totalRevenue: 0, jobCount: 0, byMechanic: []);
}

/// Per-mechanic totals over billed-out sales that carry a mechanic. Ranked by
/// total revenue (parts + labor). Voided and no-mechanic sales are excluded.
MechanicPerformanceReportData mechanicPerformanceReportFromSales(
    List<SaleEntity> sales) {
  final buckets = <String, _Bucket>{};
  double totalRevenue = 0;
  int jobCount = 0;

  for (final s in sales) {
    if (s.isVoided) continue;
    final id = s.mechanicId;
    if (id == null || id.isEmpty) continue;

    final b = buckets.putIfAbsent(
        id, () => _Bucket(id, s.mechanicName ?? '(unnamed)'));
    b.jobCount++;
    b.totalRevenue += s.grandTotal;
    b.laborTotal += s.laborRevenue;
    totalRevenue += s.grandTotal;
    jobCount++;
  }

  final byMechanic = buckets.values
      .map((b) => MechanicPerformanceStat(
            mechanicId: b.id,
            mechanicName: b.name,
            jobCount: b.jobCount,
            totalRevenue: b.totalRevenue,
            laborTotal: b.laborTotal,
          ))
      .toList()
    ..sort((a, b) {
      final c = b.totalRevenue.compareTo(a.totalRevenue);
      return c != 0
          ? c
          : a.mechanicName.toLowerCase().compareTo(b.mechanicName.toLowerCase());
    });

  return MechanicPerformanceReportData(
      totalRevenue: totalRevenue, jobCount: jobCount, byMechanic: byMechanic);
}

class _Bucket {
  final String id;
  final String name;
  int jobCount = 0;
  double totalRevenue = 0;
  double laborTotal = 0;
  _Bucket(this.id, this.name);
}
```

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/mechanic_performance_report.dart test/core/utils/mechanic_performance_report_test.dart
git commit -m "feat(job-orders): mechanicPerformanceReportFromSales aggregation (by total revenue)"
```

---

### Task D3: CSV builders

Add two builders to `report_csv.dart` (string builders live here; `saveReportCsv` stays in `report_export.dart`).

**Files:**
- Modify: `lib/core/utils/report_csv.dart`
- Test: `test/core/utils/csv.test` companion → add to the existing report-csv test file (find it: `grep -rl buildLaborReportCsv test/`)

**Interfaces:**
- Produces: `String buildMotorcycleModelReportCsv(MotorcycleModelReportData)`, `String buildMechanicPerformanceReportCsv(MechanicPerformanceReportData)`.

- [ ] **Step 1: Write the failing test** — assert header row + one data row, mirroring the existing `buildLaborReportCsv` test:

```dart
test('buildMotorcycleModelReportCsv has header + rows', () {
  final csv = buildMotorcycleModelReportCsv(MotorcycleModelReportData(
    totalJobs: 1, totalRevenue: 100,
    byModel: const [MotorcycleModelStat(model: 'Nmax', jobCount: 1, totalRevenue: 100, laborTotal: 40)]));
  expect(csv, contains('Model,Jobs,Revenue,Labor'));
  expect(csv, contains('Nmax,1,100'));
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — add to `report_csv.dart` (reuse the module-level `_converter`):

```dart
String buildMotorcycleModelReportCsv(MotorcycleModelReportData report) {
  final rows = <List<dynamic>>[
    ['Model', 'Jobs', 'Revenue', 'Labor'],
    for (final m in report.byModel)
      [m.model, m.jobCount, m.totalRevenue, m.laborTotal],
    ['TOTAL', report.totalJobs, report.totalRevenue, ''],
  ];
  return _converter.convert(rows);
}

String buildMechanicPerformanceReportCsv(MechanicPerformanceReportData report) {
  final rows = <List<dynamic>>[
    ['Mechanic', 'Jobs', 'Total revenue', 'Labor'],
    for (final m in report.byMechanic)
      [m.mechanicName, m.jobCount, m.totalRevenue, m.laborTotal],
    ['TOTAL', report.jobCount, report.totalRevenue, ''],
  ];
  return _converter.convert(rows);
}
```

Add the imports for the two report data types at the top of `report_csv.dart`.

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/report_csv.dart test/
git commit -m "feat(job-orders): CSV builders for model + mechanic reports"
```

---

### Task D4: derived report providers

Mirror `laborReportProvider` in `sale_provider.dart`.

**Files:**
- Modify: `lib/presentation/providers/sale_provider.dart` (add next to `laborReportProvider` ~L65)
- Test: covered indirectly by the helper tests; no separate provider test required (the provider is a one-line `await + pure function`, exactly like `laborReportProvider` which also has none).

**Interfaces:**
- Produces: `motorcycleModelReportProvider` / `mechanicPerformanceReportProvider` — both `FutureProvider.autoDispose.family<..., DateRangeParams>`.

- [ ] **Step 1: Implement** (no new test — parity with `laborReportProvider`):

```dart
final motorcycleModelReportProvider = FutureProvider.autoDispose
    .family<MotorcycleModelReportData, DateRangeParams>((ref, params) async {
  final sales = await ref.watch(salesByDateRangeProvider(params).future);
  return motorcycleModelReportFromSales(sales);
});

final mechanicPerformanceReportProvider = FutureProvider.autoDispose
    .family<MechanicPerformanceReportData, DateRangeParams>((ref, params) async {
  final sales = await ref.watch(salesByDateRangeProvider(params).future);
  return mechanicPerformanceReportFromSales(sales);
});
```

Add the two `import` lines for the report helpers at the top of `sale_provider.dart`.

- [ ] **Step 2: Analyze + run the sale-provider-touching suite** — `flutter analyze lib/presentation/providers/sale_provider.dart && flutter test test/presentation/mobile/screens/reports/labor_report_screen_test.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/sale_provider.dart
git commit -m "feat(job-orders): derived providers for model + mechanic reports"
```

---

### Task D5: permission + gated route

**Files:**
- Modify: `lib/core/constants/role_permissions.dart` (enum value in Reports section ~L53; add to `_adminPermissions` ~L191, NOT to cashier/staff)
- Modify: `lib/config/router/route_names.dart` (`RouteNames.jobOrderReports = 'jobOrderReports'` ~L114; `RoutePaths.jobOrderReports = '/reports/job-orders'` ~L226)
- Modify: `lib/config/router/app_routes.dart` (import + child `GoRoute` under `/reports`, near the labor route ~L336)
- Modify: `lib/config/router/route_guards.dart` (`protectedRoutes`: `'/reports/job-orders': Permission.viewJobOrderReports` ~L52)
- Test: `test/config/router/route_guards_job_orders_test.dart` (mirror `route_guards_mechanics_test.dart`) + a permissions assertion (admin has it; cashier/staff don't)

**Interfaces:**
- Produces: `Permission.viewJobOrderReports` (admin-only); route `RouteNames.jobOrderReports` at `/reports/job-orders`.

- [ ] **Step 1: Write the failing test:**

```dart
test('job-order reports route is admin-only', () {
  expect(RouteGuards.canAccess('/reports/job-orders', adminUser), isTrue);
  expect(RouteGuards.canAccess('/reports/job-orders', cashierUser), isFalse);
});
test('viewJobOrderReports is granted to admin only', () {
  expect(RolePermissions.hasPermission(UserRole.admin, Permission.viewJobOrderReports), isTrue);
  expect(RolePermissions.hasPermission(UserRole.cashier, Permission.viewJobOrderReports), isFalse);
  expect(RolePermissions.hasPermission(UserRole.staff, Permission.viewJobOrderReports), isFalse);
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement:**
- `role_permissions.dart`: add `viewJobOrderReports,` to the `// Reports Permissions` group of the `Permission` enum; add `Permission.viewJobOrderReports,` to the `_adminPermissions` set only.
- `route_names.dart`: add the `RouteNames`/`RoutePaths` constants (see Files).
- `app_routes.dart`: `import '.../screens/reports/job_order_reports_screen.dart';` and a child `GoRoute(path: 'job-orders', name: RouteNames.jobOrderReports, builder: (c, s) => const JobOrderReportsScreen())` inside the `/reports` `routes:` list.
- `route_guards.dart`: add `'/reports/job-orders': Permission.viewJobOrderReports,` to `protectedRoutes`.

- [ ] **Step 4: Run, verify pass; analyze.**

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/role_permissions.dart lib/config/router test/config/router/route_guards_job_orders_test.dart
git commit -m "feat(job-orders): viewJobOrderReports permission + gated /reports/job-orders route"
```

---

### Task D6: Job Orders reports screen + hub card

One screen with a Models / Mechanics segmented toggle, mirroring `labor_report_screen.dart` (date picker + `.when()` + CSV export). Plus a gated hub card.

**Files:**
- Create: `lib/presentation/mobile/screens/reports/job_order_reports_screen.dart`
- Modify: `lib/presentation/mobile/screens/reports/reports_hub_screen.dart` (add gated card)
- Test: `test/presentation/mobile/screens/reports/job_order_reports_screen_test.dart`, `test/presentation/widgets/reports_hub_job_orders_card_test.dart`

**Interfaces:**
- Consumes: `motorcycleModelReportProvider`, `mechanicPerformanceReportProvider` (D4), `DateRangePicker`/`dateRangeForPreset`, `buildMotorcycleModelReportCsv`/`buildMechanicPerformanceReportCsv` (D3), `saveReportCsv`, `Permission.viewJobOrderReports`.

- [ ] **Step 1: Write the failing tests** — (a) hub shows the "Job Orders" card for admin, hides it for cashier (mirror how Profit gating is asserted); (b) the screen renders the segmented control and a model row given an overridden `motorcycleModelReportProvider`.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the screen** — `lib/presentation/mobile/screens/reports/job_order_reports_screen.dart` (mirror `labor_report_screen.dart`; drop the daily-only branch since it's admin-only):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

enum _JobOrderView { models, mechanics }

class JobOrderReportsScreen extends ConsumerStatefulWidget {
  const JobOrderReportsScreen({super.key});
  @override
  ConsumerState<JobOrderReportsScreen> createState() => _State();
}

class _State extends ConsumerState<JobOrderReportsScreen> {
  late DateTime _start;
  late DateTime _end;
  DateRangePreset _preset = DateRangePreset.today;
  _JobOrderView _view = _JobOrderView.models;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.today, DateTime.now());
    _start = r.start;
    _end = r.end;
  }

  DateRangeParams get _params => DateRangeParams(
      startDate: _start, endDate: _end, status: SaleStatus.completed);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Orders'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: ListView(
        children: [
          DateRangePicker(
            startDate: _start,
            endDate: _end,
            selectedPreset: _preset,
            onPresetChanged: (p) {
              if (p == DateRangePreset.custom) return;
              final r = dateRangeForPreset(p, DateTime.now());
              setState(() { _start = r.start; _end = r.end; _preset = p; });
            },
            onCustomRangeSelected: (s, e) => setState(() {
              _start = s;
              _end = DateTime(e.year, e.month, e.day, 23, 59, 59);
              _preset = DateRangePreset.custom;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_JobOrderView>(
              segments: const [
                ButtonSegment(value: _JobOrderView.models, label: Text('Models')),
                ButtonSegment(value: _JobOrderView.mechanics, label: Text('Mechanics')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
          if (_view == _JobOrderView.models) _modelsBody() else _mechanicsBody(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _modelsBody() {
    final async = ref.watch(motorcycleModelReportProvider(_params));
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16), child: SizedBox(height: 240, child: ListSkeleton())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorStateView(
              message: 'Failed to load: $e',
              onRetry: () => ref.invalidate(motorcycleModelReportProvider(_params)))),
      data: (r) => r.byModel.isEmpty
          ? const EmptyStateView(
              icon: LucideIcons.bike, title: 'No job orders in this range')
          : Column(children: [
              for (final m in r.byModel)
                _row(m.model, '${m.jobCount} jobs', m.totalRevenue.toCurrency()),
            ]),
    );
  }

  Widget _mechanicsBody() {
    final async = ref.watch(mechanicPerformanceReportProvider(_params));
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16), child: SizedBox(height: 240, child: ListSkeleton())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorStateView(
              message: 'Failed to load: $e',
              onRetry: () => ref.invalidate(mechanicPerformanceReportProvider(_params)))),
      data: (r) => r.byMechanic.isEmpty
          ? const EmptyStateView(
              icon: LucideIcons.wrench, title: 'No mechanic jobs in this range')
          : Column(children: [
              for (final m in r.byMechanic)
                _row(m.mechanicName, '${m.jobCount} jobs',
                    m.totalRevenue.toCurrency()),
            ]),
    );
  }

  // Simple row; for polished metric cards mirror labor_report_screen's
  // _MechanicLaborRow / _LaborMetricCard.
  Widget _row(String title, String sub, String value) => AppCard(
        radius: AppRadius.md,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(sub, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Future<void> _exportCsv() async {
    final d = DateFormat('yyyy-MM-dd');
    final range = '${d.format(_start)}_to_${d.format(_end)}';
    if (_view == _JobOrderView.models) {
      final r = await ref.read(motorcycleModelReportProvider(_params).future);
      if (!mounted) return;
      if (r.byModel.isEmpty) return context.showSnackBar('Nothing to export');
      await saveReportCsv(context, buildMotorcycleModelReportCsv(r),
          'job_orders_models_$range.csv');
    } else {
      final r = await ref.read(mechanicPerformanceReportProvider(_params).future);
      if (!mounted) return;
      if (r.byMechanic.isEmpty) return context.showSnackBar('Nothing to export');
      await saveReportCsv(context, buildMechanicPerformanceReportCsv(r),
          'job_orders_mechanics_$range.csv');
    }
  }
}
```

- [ ] **Step 4: Add the gated hub card** — in `reports_hub_screen.dart`, add a flag `final canJobOrders = user != null && RolePermissions.hasPermission(user.role, Permission.viewJobOrderReports);` and, mirroring the Profit `if (canProfit) ...[]` block:

```dart
if (canJobOrders) ...[
  const SizedBox(height: 10),
  _ReportCard(
    icon: LucideIcons.clipboardList,
    title: 'Job Orders',
    subtitle: 'Models serviced + mechanic performance',
    onTap: () => context.pushNamed(RouteNames.jobOrderReports),
  ),
],
```

- [ ] **Step 5: Run the reports tests + analyze**

Run: `flutter test test/presentation/mobile/screens/reports/job_order_reports_screen_test.dart test/presentation/widgets/reports_hub_job_orders_card_test.dart && flutter analyze lib/presentation/mobile/screens/reports`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/reports/job_order_reports_screen.dart lib/presentation/mobile/screens/reports/reports_hub_screen.dart test/presentation/mobile/screens/reports/job_order_reports_screen_test.dart test/presentation/widgets/reports_hub_job_orders_card_test.dart
git commit -m "feat(job-orders): Job Orders reports screen (models + mechanics) + gated hub card"
```

---

## Final verification (before calling the epic done)

- [ ] **Full suite green:** `flutter test` (expect the existing ~800+ tests + the new ones all passing).
- [ ] **Analyzer clean:** `flutter analyze` (zero new issues).
- [ ] **Manual smoke (device/emulator):** create a Job Order (New Job Order → label + model + mechanic) → add parts in-ticket + labor → confirm the register cart stays free (ring a walk-in in parallel) → bill out → verify the sale carries the model + the ticket drops off the list → open Reports → Job Orders → see the model + mechanic rows → export CSV.
- [ ] **Rules deploy (gated):** with owner approval, `firebase deploy --only firestore:rules`.
- [ ] **Release:** `flutter build apk --release`; hand to the user for `adb install -r` (agent cannot install/smoke). Bump version in `pubspec.yaml`.
- [ ] **Finish the branch:** use `finishing-a-development-branch` (merge or PR `feature/job-orders`).

## Task dependency summary

- **A** (data foundation) → unblocks everything.
- **B** (models collection/picker/editor/rules) → independent of A; needed by C2/C3b.
- **C** (flow) needs A + B. Order: C1 → C2 → C3a → C3b → C4.
- **D** (reports) needs A only (reads `sale.motorcycleModel`) — can be built in parallel with C.

