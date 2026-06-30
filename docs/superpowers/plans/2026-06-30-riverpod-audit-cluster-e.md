# Riverpod-audit cluster E Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear the quick-set of deferred Riverpod-audit findings (D1, E1, F1, G2, B1, dead `draftNameExists`) as small, independently-testable changes.

**Architecture:** Six independent, mostly-mechanical changes to the Flutter app's state/data layer. Each is behavior-preserving except B1 (adds error feedback) and F1 (enables Riverpod state dedup). No `firestore.rules`, schema, or shared-collection-write changes.

**Tech Stack:** Flutter, flutter_riverpod 2.6.1 (legacy StateNotifier), equatable 2.0.8, fake_cloud_firestore (tests).

## Global Constraints

- Mobile (Flutter) only — `lib/` + `test/`. No `web_admin/` changes.
- No `firestore.rules`, schema, or shared-collection-write changes.
- `equatable: ^2.0.8` is ALREADY a dependency — do not add it.
- Each task ends green: `flutter analyze` clean + `flutter test` passing.
- Per-task commit. Branch: `fix/riverpod-audit-cluster-e`.
- Baseline before this plan: 830 tests green.

---

### Task 1: F1 — value equality on 4 StateNotifier state classes

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart` (`CartState`, class at line 9)
- Modify: `lib/presentation/providers/inventory_provider.dart` (`InventoryState`, line 8)
- Modify: `lib/presentation/providers/receiving_provider.dart` (`CurrentReceivingState`, line 131)
- Modify: `lib/presentation/providers/user_provider.dart` (`UserOperationsState`, line 76)
- Test: `test/presentation/providers/state_equality_test.dart` (create)

**Interfaces:**
- Produces: each state class gains `extends Equatable` + `@override List<Object?> get props`. No field/constructor/copyWith changes.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/providers/state_equality_test.dart`. Use the non-const constructor (so instances are distinct, exercising `==` rather than const-canonicalization):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

void main() {
  group('UserOperationsState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = UserOperationsState(isLoading: true);
      // ignore: prefer_const_constructors
      final b = UserOperationsState(isLoading: true);
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = UserOperationsState(isLoading: true);
      // ignore: prefer_const_constructors
      final b = UserOperationsState(isLoading: false);
      expect(a, isNot(equals(b)));
    });
  });

  group('InventoryState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = InventoryState(searchQuery: 'x');
      // ignore: prefer_const_constructors
      final b = InventoryState(searchQuery: 'x');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = InventoryState(searchQuery: 'x');
      // ignore: prefer_const_constructors
      final b = InventoryState(searchQuery: 'y');
      expect(a, isNot(equals(b)));
    });
  });

  group('CartState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = CartState(amountReceived: 10);
      // ignore: prefer_const_constructors
      final b = CartState(amountReceived: 10);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = CartState(amountReceived: 10);
      // ignore: prefer_const_constructors
      final b = CartState(amountReceived: 20);
      expect(a, isNot(equals(b)));
    });
  });

  group('CurrentReceivingState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = CurrentReceivingState(referenceNumber: 'RCV-1');
      // ignore: prefer_const_constructors
      final b = CurrentReceivingState(referenceNumber: 'RCV-1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = CurrentReceivingState(referenceNumber: 'RCV-1');
      // ignore: prefer_const_constructors
      final b = CurrentReceivingState(referenceNumber: 'RCV-2');
      expect(a, isNot(equals(b)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/state_equality_test.dart`
Expected: FAIL — the `identical fields compare equal` cases fail (default identity equality).

- [ ] **Step 3: Add Equatable to each state class**

In each file: add `import 'package:equatable/equatable.dart';`, change the class declaration to `extends Equatable`, and add a `props` getter listing **every field in declaration order**.

`cart_provider.dart` — `class CartState extends Equatable {` and add (after the constructor / computed members):
```dart
  @override
  List<Object?> get props => [
        items,
        discountType,
        paymentMethod,
        amountReceived,
        secondaryMethod,
        splitAmount,
        notes,
        sourceDraftId,
        draftName,
        laborLines,
        mechanicId,
        mechanicName,
        isProcessing,
        errorMessage,
      ];
```

`inventory_provider.dart` — `class InventoryState extends Equatable {` and add:
```dart
  @override
  List<Object?> get props =>
      [searchQuery, categoryFilter, stockFilter, showCost, sortOption, sortAscending];
```

`receiving_provider.dart` — `class CurrentReceivingState extends Equatable {` and add:
```dart
  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        supplierId,
        supplierName,
        items,
        notes,
        status,
        completedAt,
        isProcessing,
        isLoading,
        errorMessage,
      ];
```

`user_provider.dart` — `class UserOperationsState extends Equatable {` and add:
```dart
  @override
  List<Object?> get props => [isLoading, errorMessage];
```

(`const` constructors are preserved — `Equatable`'s constructor is `const`.)

- [ ] **Step 4: Run the new test + full suite**

Run: `flutter test test/presentation/providers/state_equality_test.dart` → PASS
Run: `flutter analyze` → No issues
Run: `flutter test` → all green (830 + 8 new)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/cart_provider.dart lib/presentation/providers/inventory_provider.dart lib/presentation/providers/receiving_provider.dart lib/presentation/providers/user_provider.dart test/presentation/providers/state_equality_test.dart
git commit -m "perf(state): value-equality on Cart/Inventory/CurrentReceiving/UserOperations state (F1)"
```

---

### Task 2: D1 — wire 8 repo providers through the `firestoreProvider` seam

**Files:**
- Modify: `lib/presentation/providers/auth_provider.dart:13`
- Modify: `lib/presentation/providers/sale_provider.dart:18`
- Modify: `lib/presentation/providers/user_provider.dart:15`
- Modify: `lib/presentation/providers/cost_code_provider.dart:11`
- Modify: `lib/presentation/providers/draft_provider.dart:14`
- Modify: `lib/presentation/providers/product_provider.dart:15`
- Modify: `lib/presentation/providers/receiving_provider.dart:18`
- Modify: `lib/services/activity_logger.dart:312`
- Test: `test/presentation/providers/firestore_seam_test.dart` (create)

**Interfaces:**
- Consumes: existing `firestoreProvider` (`lib/services/firebase_service.dart:184`). Every impl constructor already accepts `firestore:`. Behavior unchanged (default remains `FirebaseFirestore.instance`); this only makes the firestore overridable in tests.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/providers/firestore_seam_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  test('productRepositoryProvider honors a firestoreProvider override', () async {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    // Before D1: the provider builds ProductRepositoryImpl() ->
    // FirebaseFirestore.instance, which throws in tests (no Firebase app).
    // After D1: it uses the injected fake and emits an empty list.
    final repo = container.read(productRepositoryProvider);
    final products = await repo.watchProducts().first;
    expect(products, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/firestore_seam_test.dart`
Expected: FAIL — constructing `ProductRepositoryImpl()` evaluates `FirebaseFirestore.instance` and throws (no Firebase app in the test).

- [ ] **Step 3: Pass `ref.watch(firestoreProvider)` at each call-site**

Each edit adds the `firestore:` argument (keep any other existing args):
- `auth_provider.dart:13` → `return AuthRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `sale_provider.dart:18` → `return SaleRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `user_provider.dart:15` → `return UserRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `cost_code_provider.dart:11` → `return CostCodeRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `draft_provider.dart:14` → `return DraftRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `product_provider.dart:15` → `return ProductRepositoryImpl(firestore: ref.watch(firestoreProvider));`
- `receiving_provider.dart:18` → `return ReceivingRepositoryImpl(firestore: ref.watch(firestoreProvider), productRepository: productRepo);`
- `activity_logger.dart:312` → `return ActivityLogRepositoryImpl(firestore: ref.watch(firestoreProvider));`

For each file, ensure `firestoreProvider` is imported. The providers under `lib/presentation/providers/` get it via the `providers.dart` barrel or a direct `import 'package:maki_mobile_pos/services/firebase_service.dart';`. For `activity_logger.dart`, add the `firebase_service.dart` import if not already present.

- [ ] **Step 4: Run the new test + full suite**

Run: `flutter test test/presentation/providers/firestore_seam_test.dart` → PASS
Run: `flutter analyze` → No issues
Run: `flutter test` → all green

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/auth_provider.dart lib/presentation/providers/sale_provider.dart lib/presentation/providers/user_provider.dart lib/presentation/providers/cost_code_provider.dart lib/presentation/providers/draft_provider.dart lib/presentation/providers/product_provider.dart lib/presentation/providers/receiving_provider.dart lib/services/activity_logger.dart test/presentation/providers/firestore_seam_test.dart
git commit -m "refactor(di): route 8 repo providers through firestoreProvider seam (D1)"
```

---

### Task 3: E1 — remove dead Future-twin reads

**Files:**
- Modify: `lib/domain/repositories/supplier_repository.dart` (remove `getSuppliers` decl, ~line 19)
- Modify: `lib/data/repositories/supplier_repository_impl.dart` (remove `getSuppliers`, ~line 66)
- Modify: `lib/domain/repositories/product_repository.dart` (remove `getProducts` decl, ~line 48)
- Modify: `lib/data/repositories/product_repository_impl.dart` (remove `getProducts`, ~line 210)
- Modify: `lib/domain/repositories/sale_repository.dart` (remove `getTodaysSales` decl, ~line 81)
- Modify: `lib/data/repositories/sale_repository_impl.dart` (remove `getTodaysSales`, ~line 189)
- Modify: `test/data/repositories/sale_repository_impl_test.dart` (remove the `getTodaysSales` test, ~line 117)
- Modify: `lib/domain/repositories/receiving_repository.dart` (remove `getReceivings` decl, ~line 16)
- Modify: `lib/data/repositories/receiving_repository_impl.dart` (privatize `getReceivings` → `_getReceivings`, lines 58–99; update callers at 103 + 108)

**Interfaces:**
- Produces: `getSuppliers`/`getProducts`/`getTodaysSales` no longer exist; `getReceivings` becomes a private impl helper. `getAllSuppliers`, `getSalesForDay`, `getRecentReceivings`, `getDraftReceivings`, and all `watch*` twins are unchanged.

- [ ] **Step 1: Confirm no remaining callers**

Run: `grep -rn "\.getSuppliers(\|\.getProducts(\|\.getTodaysSales(\|\.getReceivings(" lib/ test/`
Expected: only the declarations/impls listed above, the two internal `getReceivings` callers in `receiving_repository_impl.dart`, and the one `getTodaysSales` test. If any production caller appears, STOP and reassess.

- [ ] **Step 2: Delete the three dead getters + the orphan test**

- Delete `getSuppliers` from `supplier_repository.dart` (interface decl) and its `@override` method in `supplier_repository_impl.dart` (the body `return getAllSuppliers(includeInactive: false, limit: limit);`).
- Delete `getProducts` from `product_repository.dart` (interface decl) and the entire `@override Future<List<ProductEntity>> getProducts({...}) async { ... }` method in `product_repository_impl.dart`.
- Delete `getTodaysSales` from `sale_repository.dart` (interface decl) and the `@override` method in `sale_repository_impl.dart` (body `final today = DateTime.now(); return getSalesForDay(...)`).
- In `test/data/repositories/sale_repository_impl_test.dart`, delete the single `test('...getTodaysSales...')` block (and an enclosing `group` only if it becomes empty).

- [ ] **Step 3: Privatize `getReceivings`**

In `receiving_repository_impl.dart`:
- Remove the `@override` annotation above `getReceivings` (lines 58–59) and rename the method `getReceivings` → `_getReceivings` (keep the body verbatim).
- Update caller line 103: `return getReceivings(limit: limit);` → `return _getReceivings(limit: limit);`
- Update caller line 108: `return getReceivings(status: ReceivingStatus.draft);` → `return _getReceivings(status: ReceivingStatus.draft);`

In `receiving_repository.dart` (interface): delete the `getReceivings({...})` declaration (~line 16).

- [ ] **Step 4: Verify**

Run: `flutter analyze` → No issues (catches any missed reference)
Run: `flutter test` → all green (minus the deleted `getTodaysSales` test)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/supplier_repository.dart lib/data/repositories/supplier_repository_impl.dart lib/domain/repositories/product_repository.dart lib/data/repositories/product_repository_impl.dart lib/domain/repositories/sale_repository.dart lib/data/repositories/sale_repository_impl.dart test/data/repositories/sale_repository_impl_test.dart lib/domain/repositories/receiving_repository.dart lib/data/repositories/receiving_repository_impl.dart
git commit -m "refactor(data): drop dead Future twins; privatize getReceivings (E1)"
```

---

### Task 4: Delete dead `draftNameExists`; verify B4 draft-load ordering

**Files:**
- Modify: `lib/domain/repositories/draft_repository.dart` (remove `draftNameExists` decl if present)
- Modify: `lib/data/repositories/draft_repository_impl.dart` (remove `draftNameExists`, ~line 406)
- Investigate: the drafts-load handler (`_performLoadDraft` or the draft-load notifier path)

- [ ] **Step 1: Confirm `draftNameExists` is dead, then delete it**

Run: `grep -rn "draftNameExists" lib/ test/`
Expected: only the interface decl + impl definition. If a caller exists, STOP.
Delete the `draftNameExists` declaration from `draft_repository.dart` (if it's declared there) and the `Future<bool> draftNameExists({...}) async { ... }` method from `draft_repository_impl.dart`.

- [ ] **Step 2: Verify the B4 residual**

Locate the draft-load handler (search `_performLoadDraft` and the drafts list/detail screen + draft load in the cart notifier). Determine the ordering: is the cart populated BEFORE a delete that can fail, such that on delete failure the cart is populated AND the draft still exists (duplicate-resume risk)?
- If NOT present (delete precedes cart-load, or there is no delete-on-load), add a one-line code comment noting B4 is not present and move on.
- If present, fix by ordering the delete before the cart is populated, OR by surfacing the failure and not populating the cart on delete failure. Keep the fix minimal and mirror the existing error-handling style. Add/adjust a focused test for the ordering only if a fix is made.

- [ ] **Step 3: Verify**

Run: `flutter analyze` → No issues
Run: `flutter test` → all green

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(data): delete dead draftNameExists; verify B4 draft-load order"
```

---

### Task 5: B1 — surface init failure on the bulk-receiving screen

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart:54-59`
- Test: `test/presentation/mobile/screens/receiving/bulk_receiving_init_test.dart` (create)

**Interfaces:**
- Consumes: `currentReceivingProvider` (StateNotifierProvider) + its `initNewReceiving()`; `context.showErrorSnackBar` (`core/extensions/navigation_extensions.dart`, already imported); go_router `context.canPop()/pop()` (`config/router/router.dart`, already imported).

- [ ] **Step 1: Write the failing test**

Create `test/presentation/mobile/screens/receiving/bulk_receiving_init_test.dart`. Override `currentReceivingProvider` with a notifier whose `initNewReceiving` throws (other notifier members are unused in initState, so `noSuchMethod` stubs them):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/bulk_receiving_screen.dart';

class _ThrowingReceivingNotifier extends StateNotifier<CurrentReceivingState>
    implements CurrentReceivingNotifier {
  _ThrowingReceivingNotifier() : super(const CurrentReceivingState());

  @override
  Future<void> initNewReceiving() async => throw Exception('boom');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows an error snackbar when initNewReceiving fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentReceivingProvider
              .overrideWith((ref) => _ThrowingReceivingNotifier()),
          // currentUserProvider is read by the screen (_isAdmin); stub it.
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: BulkReceivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not start a new receiving'), findsOneWidget);
  });
}
```

If pumping reveals additional providers the screen reads that hit Firebase, add the corresponding overrides (the test output names them).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/receiving/bulk_receiving_init_test.dart`
Expected: FAIL — no snackbar today (the exception is swallowed by the fire-and-forget callback; the test runner reports the uncaught async error).

- [ ] **Step 3: Add error handling to the postFrame callback**

In `bulk_receiving_screen.dart`, replace the `else` branch (lines 54–59):
```dart
    } else {
      // Initialize a new receiving. Mirror _startNewReceiving's guard so a
      // reference-number failure surfaces instead of failing silently.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await ref.read(currentReceivingProvider.notifier).initNewReceiving();
        } catch (e) {
          if (!mounted) return;
          context.showErrorSnackBar('Could not start a new receiving: $e');
          if (context.canPop()) context.pop();
        }
      });
    }
```

- [ ] **Step 4: Run the new test + full suite**

Run: `flutter test test/presentation/mobile/screens/receiving/bulk_receiving_init_test.dart` → PASS
Run: `flutter analyze` → No issues
Run: `flutter test` → all green

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart test/presentation/mobile/screens/receiving/bulk_receiving_init_test.dart
git commit -m "fix(receiving): surface init failure on bulk-receiving screen (B1)"
```

---

### Task 6: G2 — drop the unused riverpod codegen toolchain

**Files:**
- Modify: `pubspec.yaml` (remove `riverpod_annotation` line 43, `build_runner` 47, `riverpod_generator` 48, `json_serializable` 49)

- [ ] **Step 1: Re-confirm zero usage**

Run: `grep -rn "riverpod_annotation\|@riverpod\|@Riverpod\|JsonSerializable\|part '.*\.g\.dart'" lib/ test/`
Expected: no matches. (`.g.dart` files: `find lib -name '*.g.dart'` → none.) If anything matches, STOP.

- [ ] **Step 2: Remove the four dependencies**

In `pubspec.yaml`, delete these four lines (keep `equatable` and `flutter_riverpod`):
```yaml
  riverpod_annotation: ^2.6.1
  build_runner: ^2.4.15
  riverpod_generator: ^2.6.5
  json_serializable: ^6.9.5
```

- [ ] **Step 3: Resolve + full gate**

Run: `flutter pub get` → resolves cleanly
Run: `flutter analyze` → No issues
Run: `flutter test` → all green
Run: `flutter build apk --release` → builds (sanity: the dependency change doesn't break the release build)

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): drop unused riverpod codegen toolchain (G2)"
```

---

## Self-Review

**Spec coverage:** D1 → Task 2; E1 → Task 3; F1 → Task 1; G2 → Task 6; B1 → Task 5; dead `draftNameExists` + B4 → Task 4. All spec items covered. Out-of-scope (name-claims epic, FirebaseAuth seam) correctly excluded.

**Placeholder scan:** No TBD/TODO. Test code is complete; edits are exact operations with file:line. The only conditional is Task 4's B4 (a genuine verify-then-maybe-fix, bounded with concrete branches) and Task 5's "add overrides if the pump names more" (a normal widget-test iteration).

**Type consistency:** `firestoreProvider` (Provider<FirebaseFirestore>) consistent across Tasks 2. `_getReceivings` rename consistent in Task 3 (decl + 2 callers). `props` field lists match each class's declared fields verbatim. `initNewReceiving()` signature consistent (Task 5 + receiving_provider).
