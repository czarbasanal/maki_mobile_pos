# +17 Quad Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the four approved +17 items: product-category editing locked to staff+admin, hard delete on shared-list items, void-request notification sheet + filtered/paged screen, and the received-amount write fix with backfill script.

**Architecture:** Flutter mobile app (Riverpod StateNotifier/StreamProvider patterns, repository layer over Firestore). Firestore rules changes are edited in-repo but deployed separately with user confirmation. Spec: `docs/superpowers/specs/2026-07-25-plus17-quad-batch-design.md`.

**Tech Stack:** Flutter/Dart, Riverpod, cloud_firestore ^6.1.2, fake_cloud_firestore ^4.0.1 (repo tests), flutter_test, Firestore rules emulator suite in `tools/firestore-rules-test/`, Node ESM scripts in `scripts/`.

## Global Constraints

- Work on branch `feat/plus17-quad-batch` off `main`; one commit per task.
- TDD every task: failing test first, watch it fail, minimal code, watch it pass.
- `flutter analyze` must stay clean; run per task alongside the task's tests.
- Icons: Lucide only (`lucide_icons_flutter`). Confirm dialogs: `showAppConfirmDialog` from `common_widgets.dart`.
- Do NOT deploy firestore rules or indexes, and do NOT run the backfill against prod — those are user-confirmed deploy-time actions.
- Status labels stay "Pending / Approved / Rejected". Date filter defaults to Today.
- Widget-test gotcha: the test font renders every glyph 16px wide — wrap long menu/label texts in `Flexible` if a Row overflows.

---

## Part A — Product Categories staff+admin

### Task 1: `Permission.editProductCategories`

**Files:**
- Modify: `lib/core/constants/role_permissions.dart`
- Test: `test/core/constants/role_permissions_test.dart` (exists — append a group)

**Interfaces:**
- Produces: `Permission.editProductCategories`, in `_staffPermissions` and `_adminPermissions`, NOT in cashier set. Tasks 2–3 rely on this exact enum name.

- [ ] **Step 1: Write the failing test** — append to the existing test file:

```dart
group('editProductCategories (2026-07-25: product categories staff+admin)', () {
  test('cashier does NOT have editProductCategories', () {
    expect(
      RolePermissions.hasPermission(
          UserRole.cashier, Permission.editProductCategories),
      isFalse,
    );
  });

  test('staff and admin have editProductCategories', () {
    expect(
      RolePermissions.hasPermission(
          UserRole.staff, Permission.editProductCategories),
      isTrue,
    );
    expect(
      RolePermissions.hasPermission(
          UserRole.admin, Permission.editProductCategories),
      isTrue,
    );
  });

  test('cashier keeps editLists (other lists unaffected)', () {
    expect(
      RolePermissions.hasPermission(UserRole.cashier, Permission.editLists),
      isTrue,
    );
  });
});
```

- [ ] **Step 2: Run** `flutter test test/core/constants/role_permissions_test.dart` — expect FAIL (enum value undefined / compile error).
- [ ] **Step 3: Implement.** In `role_permissions.dart`, add to the `Permission` enum directly under `editLists` (~line 68):

```dart
  editProductCategories, // Product Categories editor — staff + admin (2026-07-25)
```

Add `Permission.editProductCategories,` to `_staffPermissions` (next to its `manageCategories`, ~line 161) and `_adminPermissions` (~line 217). Do NOT add to cashier.

- [ ] **Step 4: Run the same test** — expect PASS. Run `flutter analyze` — clean.
- [ ] **Step 5: Commit** `feat(mobile): editProductCategories permission (staff+admin)`

### Task 2: Hide Product Categories tile + route guard

**Files:**
- Modify: `lib/presentation/mobile/screens/settings/category_settings_screen.dart`
- Modify: `lib/config/router/route_guards.dart:200-204`
- Test: `test/config/router/route_guards_shared_lists_test.dart` (append), `test/presentation/mobile/screens/settings/category_settings_screen_test.dart` (create; if a test for this screen already exists under `test/presentation/`, append there instead)

**Interfaces:**
- Consumes: `Permission.editProductCategories` (Task 1); `CategoryKind.product.name == 'product'`; `RoutePaths.categorySettings == '/settings/categories'`.

- [ ] **Step 1: Failing guard test** — append to `route_guards_shared_lists_test.dart`, following that file's existing helper style (it already builds users per role and calls the guard's public check; mirror the surrounding tests exactly):

```dart
test('cashier is blocked from /settings/categories/product', () {
  expect(RouteGuards.canAccess('/settings/categories/product', cashier), isFalse);
});
test('staff can access /settings/categories/product', () {
  expect(RouteGuards.canAccess('/settings/categories/product', staff), isTrue);
});
test('cashier still accesses other kind editors', () {
  expect(RouteGuards.canAccess('/settings/categories/expense', cashier), isTrue);
  expect(RouteGuards.canAccess('/settings/categories/unit', cashier), isTrue);
});
```

(If the file's entry point is named differently — e.g. a top-level function or `checkRoute` — read the neighboring tests first and use the same call; the assertion targets are what matter.)

- [ ] **Step 2: Run it** — expect FAIL (cashier currently allowed).
- [ ] **Step 3: Implement guard.** In `route_guards.dart` `_checkDynamicRoute`, replace the per-kind block (lines ~200-204):

```dart
    // Per-kind editors live under /settings/categories/<kind> — editLists,
    // except Product Categories which is staff+admin (2026-07-25).
    if (path.startsWith('${RoutePaths.categorySettings}/')) {
      final kindSegment =
          path.substring('${RoutePaths.categorySettings}/'.length);
      if (kindSegment == CategoryKind.product.name) {
        return user.hasPermission(Permission.editProductCategories);
      }
      return user.hasPermission(Permission.editLists);
    }
```

Import `category_provider.dart` if `CategoryKind` isn't already visible in that file.

- [ ] **Step 4: Run guard tests** — PASS.
- [ ] **Step 5: Failing hub test** — the hub screen must hide the Product Categories tile for users without the permission:

```dart
// category_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_settings_screen.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
      ],
      child: const MaterialApp(home: CategorySettingsScreen()),
    );

void main() {
  testWidgets('cashier does not see the Product Categories tile',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.text('Product Categories'), findsNothing);
    expect(find.text('Expense Categories'), findsOneWidget);
  });

  testWidgets('staff sees the Product Categories tile', (tester) async {
    await tester.pumpWidget(_harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.text('Product Categories'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run it** — FAIL (tile always shown).
- [ ] **Step 7: Implement hub filter.** In `category_settings_screen.dart` `build`, filter the kinds list:

```dart
    final role = ref.watch(currentUserProvider).valueOrNull?.role;
    final canEditProductCats = role != null &&
        RolePermissions.hasPermission(role, Permission.editProductCategories);
    final kinds = CategoryKind.values
        .where((k) => k != CategoryKind.product || canEditProductCats)
        .toList();
```

Use `kinds` for `itemCount`/`itemBuilder` instead of `CategoryKind.values`. Add imports for `role_permissions.dart` and `auth_provider.dart` (via the providers barrel already imported as `category_provider.dart` — add `import 'package:maki_mobile_pos/core/constants/role_permissions.dart';` and `import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';`).

- [ ] **Step 8: Run both new test files + `flutter analyze`** — PASS/clean.
- [ ] **Step 9: Commit** `feat(mobile): product-categories editor gated to staff+admin (tile + route)`

### Task 3: Rules — `product_categories` create/update staff+admin

**Files:**
- Modify: `firestore.rules` (product_categories block, ~lines 325-339)
- Test: `tools/firestore-rules-test/test/` — find the shared-lists spec added by commit `90ac234` (`grep -rl product_categories tools/firestore-rules-test/test/`) and append cases there.

- [ ] **Step 1: Failing rules tests** — in the shared-lists rules spec, mirroring its existing helpers (authed contexts per role):

```js
test('cashier can no longer create a product category', async () => {
  await assertFails(
    cashierDb.collection('product_categories').add(validCategory()));
});
test('cashier can no longer rename a product category', async () => {
  await assertFails(cashierDb.collection('product_categories')
    .doc(seededId).update({ name: 'New Name' }));
});
test('staff can still create and rename product categories', async () => {
  await assertSucceeds(
    staffDb.collection('product_categories').add(validCategory()));
});
test('cashier can still create an expense category (unchanged)', async () => {
  await assertSucceeds(
    cashierDb.collection('expense_categories').add(validCategory()));
});
```

Use the file's existing seeded-doc/`validCategory` helpers; if names differ, adapt to the local helpers (the four behaviors above are the contract).

- [ ] **Step 2: Run the rules suite** (per `tools/firestore-rules-test/README.md`, typically `npm test` inside that dir with the emulator) — new cases FAIL.
- [ ] **Step 3: Implement.** In `firestore.rules` `product_categories` block, replace create/update:

```
      // Product Categories (2026-07-25): staff/admin only — cashiers keep
      // other shared lists but not product categories.
      allow create: if isStaffOrAdmin() && isActiveUser();
      allow update: if isStaffOrAdmin() && isActiveUser();
```

Leave `read` and `delete` lines untouched (delete changes in Task 7).

- [ ] **Step 4: Run the rules suite** — all green.
- [ ] **Step 5: Commit** `feat(rules): product_categories create/update staff+admin (NOT deployed)`

---

## Part B — Hard delete on shared-list items

### Task 4: Repository + provider `delete` for all four list families

**Files:**
- Modify: `lib/domain/repositories/category_repository.dart`, `mechanic_repository.dart`, `shop_fee_repository.dart`, `motorcycle_model_repository.dart` (interfaces)
- Modify: matching impls in `lib/data/repositories/` (`category_repository_impl.dart`, `mechanic_repository_impl.dart`, `shop_fee_repository_impl.dart`, `motorcycle_model_repository_impl.dart`)
- Modify: `lib/presentation/providers/category_provider.dart`, `mechanic_provider.dart`, `shop_fee_provider.dart`, `motorcycle_model_provider.dart` (ops notifiers)
- Test: `test/data/repositories/category_repository_delete_test.dart` (create), plus append a delete test to the existing ops-provider tests (e.g. `test/presentation/providers/motorcycle_model_provider_test.dart` shows the override pattern)

**Interfaces:**
- Produces (Task 5/6 depend on these exact names):
  - `CategoryRepository.deleteCategory(String categoryId)` / `CategoryOperationsNotifier.delete(String categoryId) → Future<bool>`
  - `MechanicRepository.deleteMechanic(String mechanicId)` / `MechanicOperationsNotifier.delete(String mechanicId) → Future<bool>`
  - `ShopFeeRepository.deleteShopFee(String shopFeeId)` / shop-fee ops `.delete(String shopFeeId) → Future<bool>`
  - `MotorcycleModelRepository.delete(String id)` / motorcycle ops `.delete(String id) → Future<bool>`

- [ ] **Step 1: Failing repo test** (fake_cloud_firestore):

```dart
// test/data/repositories/category_repository_delete_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/category_repository_impl.dart';

void main() {
  test('deleteCategory removes the document', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('product_categories')
        .doc('c1')
        .set({'name': 'Brakes', 'isActive': true});
    final repo = CategoryRepositoryImpl(
        collectionName: 'product_categories', firestore: firestore);

    await repo.deleteCategory('c1');

    final doc =
        await firestore.collection('product_categories').doc('c1').get();
    expect(doc.exists, isFalse);
  });
}
```

- [ ] **Step 2: Run it** — FAIL (`deleteCategory` undefined).
- [ ] **Step 3: Implement all four repos.** Interface (category shown; mirror on the other three with the names above):

```dart
  /// Permanently deletes the entry. Historical records keep the snapshotted
  /// name; prefer setActive(false) to merely hide an entry.
  Future<void> deleteCategory(String categoryId);
```

Impl (match each impl's existing error-wrap style — category shown):

```dart
  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _ref.doc(categoryId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

(If an impl's collection getter isn't `_ref`, use its local name.)

- [ ] **Step 4: Ops notifiers.** Add to each ops notifier, mirroring its `_setActive` shape — category shown:

```dart
  /// Permanently deletes the entry. Returns true on success.
  Future<bool> delete(String categoryId) async {
    state = const AsyncValue.loading();
    try {
      _requireUserId();
      await _repository.deleteCategory(categoryId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
```

(Mechanic/shop-fee/motorcycle notifiers: same body calling their repo method; if a notifier's auth helper is named differently — e.g. `_requireUser()` — use that.)

- [ ] **Step 5: Failing + passing ops test.** Append to the existing motorcycle-model provider test (it already overrides `currentUserProvider` + repo): assert `await container.read(<ops provider>.notifier).delete('m1')` returns true and the fake repo/collection no longer has the doc. Follow the file's existing override style exactly.
- [ ] **Step 6: Run** `flutter test test/data/repositories/category_repository_delete_test.dart test/presentation/providers/motorcycle_model_provider_test.dart` + `flutter analyze` — PASS/clean.
- [ ] **Step 7: Commit** `feat(mobile): hard-delete methods across shared-list repos + ops providers`

### Task 5: `SettingsCrudRow.onDelete`

**Files:**
- Modify: `lib/presentation/mobile/widgets/settings/settings_crud_row.dart`
- Test: `test/presentation/mobile/widgets/settings/settings_crud_row_test.dart` (append if it exists, else create)

**Interfaces:**
- Produces: `SettingsCrudRow({..., VoidCallback? onDelete})` — a trash icon button rendered after the archive/reactivate toggle when non-null. Task 6 passes it from every editor.

- [ ] **Step 1: Failing widget test:**

```dart
testWidgets('onDelete renders a trash action that fires the callback',
    (tester) async {
  var deleted = false;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SettingsCrudRow(
        name: 'Brakes',
        isActive: true,
        onEdit: () {},
        onToggleActive: () {},
        onDelete: () => deleted = true,
      ),
    ),
  ));
  await tester.tap(find.byIcon(LucideIcons.trash2));
  expect(deleted, isTrue);
});

testWidgets('no trash action when onDelete is null', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SettingsCrudRow(name: 'Brakes', isActive: true, onEdit: () {}),
    ),
  ));
  expect(find.byIcon(LucideIcons.trash2), findsNothing);
});
```

- [ ] **Step 2: Run** — FAIL (no `onDelete` param).
- [ ] **Step 3: Implement.** Add the field + doc:

```dart
  /// Permanent-delete action; null hides the button (users without
  /// full list-manage permission). Callers own the confirm dialog.
  final VoidCallback? onDelete;
```

constructor: `this.onDelete,` after `onToggleActive`. In the Row children, after the `onToggleActive` button block:

```dart
            if (onDelete != null)
              _RowIconButton(
                icon: LucideIcons.trash2,
                color: AppColors.error,
                tooltip: 'Delete',
                onPressed: onDelete!,
              ),
```

(`AppColors.error` is available via the existing `theme.dart` import; if analyze flags it, use `AppColors.errorText(dark)`.)

- [ ] **Step 4: Run + analyze** — PASS/clean.
- [ ] **Step 5: Commit** `feat(mobile): SettingsCrudRow optional delete action`

### Task 6: Wire delete into the four editors

**Files:**
- Modify: `lib/presentation/mobile/screens/settings/category_editor_screen.dart`, `mechanic_editor_screen.dart`, `motorcycle_model_editor_screen.dart`, `shop_fee_editor_screen.dart`
- Test: `test/presentation/mobile/screens/settings/category_editor_delete_test.dart` (create; use the same harness style as existing editor tests in that folder if present — override `currentUserProvider` + `allCategoriesProvider`/repo family)

**Interfaces:**
- Consumes: Task 4 ops `.delete(id)`; Task 5 `onDelete`; `showAppConfirmDialog` (`common_widgets.dart`).

- [ ] **Step 1: Failing widget test** (category editor; staff user): pump the editor for `CategoryKind.product` with one seeded active category, tap the trash icon, expect the confirm dialog (`find.text('Delete this entry?')`), tap `Delete`, and assert the ops delete ran (override `categoryOperationsProvider(kind)` with a recording fake notifier, same subclass technique as `_FakeExpenseOps` in `test/presentation/widgets/end_of_day_review_test.dart`).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement per editor.** Each editor already computes `canManage` (`manageCategories`). Pass to its `SettingsCrudRow`:

```dart
  onDelete: canManage ? () => _confirmDelete(item) : null,
```

and add (category editor shown — adapt entity/ops names per screen):

```dart
  Future<void> _confirmDelete(CategoryEntity category) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: '"${category.name}" will be permanently deleted. '
          'Past records that used it keep the name. '
          'Use Deactivate instead to just hide it.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(categoryOperationsProvider(widget.kind).notifier)
        .delete(category.id);
    if (!mounted) return;
    ok
        ? context.showSuccessSnackBar('Deleted')
        : context.showErrorSnackBar('Failed to delete');
  }
```

(For ConsumerWidget editors without `mounted`, use `context.mounted`. Mechanic/motorcycle/shop-fee: same flow with their ops provider and entity; streams auto-refresh the list, no invalidation needed.)

- [ ] **Step 4: Run new test + the four editors' existing tests + analyze** — PASS/clean.
- [ ] **Step 5: Commit** `feat(mobile): delete action wired into shared-list editors (staff+admin)`

### Task 7: Rules — list delete staff+admin (×7)

**Files:**
- Modify: `firestore.rules` — `product_categories`, `expense_categories`, `units`, `void_reasons`, `mechanics`, `shop_fees`, `motorcycle_models`
- Test: same shared-lists rules spec as Task 3

- [ ] **Step 1: Failing rules tests** — for at least `product_categories`, `mechanics`, `motorcycle_models`:

```js
test('staff can delete a list entry', async () => {
  await assertSucceeds(
    staffDb.collection('mechanics').doc(seededId).delete());
});
test('cashier cannot delete a list entry', async () => {
  await assertFails(
    cashierDb.collection('mechanics').doc(seededId).delete());
});
```

- [ ] **Step 2: Run suite** — staff-delete cases FAIL (admin-only today).
- [ ] **Step 3: Implement.** In each of the seven collection blocks replace

```
      allow delete: if isAdmin() && isActiveUser();
```

with

```
      // Hard delete (2026-07-25): staff+admin — in-app delete shipped.
      allow delete: if isStaffOrAdmin() && isActiveUser();
```

- [ ] **Step 4: Run suite** — green.
- [ ] **Step 5: Commit** `feat(rules): shared-list delete staff+admin (NOT deployed)`

---

## Part C — Void requests

### Task 8: `itemsSummary` on void requests

**Files:**
- Modify: `lib/domain/entities/void_request_entity.dart`, `lib/data/models/void_request_model.dart`, `lib/domain/usecases/pos/request_void_sale_usecase.dart`
- Test: `test/domain/usecases/pos/request_void_sale_usecase_test.dart` (append; it exists — check its mock style) and `test/data/models/void_request_model_test.dart` (append/create)

**Interfaces:**
- Produces: `VoidRequestEntity.itemsSummary` (`String?`, optional ctor param, preserved by `copyWith`); model reads/writes `'itemsSummary'`; use case fills it from `sale.items` as `"2× Brake Shoe, 1× Bulb"` (joined `, `, truncated to 80 chars with `…`; empty items + labor → `'Service / labor'`; otherwise null).

- [ ] **Step 1: Failing use-case test** — in the existing use-case test file, assert the entity passed to the mocked repository carries the summary:

```dart
test('request stores an items summary built from the sale items', () async {
  // sale with items: 2× Brake Shoe, 1× Bulb  (build via the file's existing
  // sale fixture helper, adjusting quantities/names)
  final captured = <VoidRequestEntity>[];
  when(() => repository.createRequest(captureAny()))... // per file's mocktail style
  await useCase.execute(actor: staffActor, sale: sale, reason: 'Damaged');
  expect(captured.single.itemsSummary, '2× Brake Shoe, 1× Bulb');
});
```

Also a model round-trip test: `toCreateMap` includes `'itemsSummary'` when non-null; `fromFirestore` reads it and defaults to null.

- [ ] **Step 2: Run** — FAIL (field undefined).
- [ ] **Step 3: Implement.** Entity: add `final String? itemsSummary;`, ctor `this.itemsSummary,`, include in `copyWith` passthrough (`itemsSummary: itemsSummary`) and in `props`. Model `fromFirestore`: `itemsSummary: map['itemsSummary'] as String?`; `toCreateMap`: `if (e.itemsSummary != null) 'itemsSummary': e.itemsSummary,`. Use case, before `createRequest`:

```dart
      String? itemsSummary;
      if (sale.items.isNotEmpty) {
        final joined =
            sale.items.map((i) => '${i.quantity}× ${i.name}').join(', ');
        itemsSummary =
            joined.length <= 80 ? joined : '${joined.substring(0, 79)}…';
      } else if (sale.laborLines.isNotEmpty) {
        itemsSummary = 'Service / labor';
      }
```

and pass `itemsSummary: itemsSummary` into the `VoidRequestEntity`.

- [ ] **Step 4: Run both test files + analyze** — PASS/clean.
- [ ] **Step 5: Commit** `feat(mobile): void requests store an items summary at creation`

### Task 9: Repo — paged query + status counts

**Files:**
- Modify: `lib/domain/repositories/void_request_repository.dart`, `lib/data/repositories/void_request_repository_impl.dart`
- Test: `test/data/repositories/void_request_repository_paging_test.dart` (create, fake_cloud_firestore)

**Interfaces:**
- Produces (Task 10 depends on exact signatures):

```dart
  /// One page of requests within [start, end], newest first. [status] null =
  /// all statuses. Pass the last item's id as [startAfterId] for the next page.
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  });

  /// Count of requests with [status] within [start, end] (aggregate query).
  Future<int> countByStatus({
    required VoidRequestStatus status,
    required DateTime start,
    required DateTime end,
  });
```

- [ ] **Step 1: Failing repo test** — seed 3 pending + 1 approved across two days into `FakeFirebaseFirestore` (`createdAt: Timestamp.fromDate(...)`), then assert: status filter works; date window excludes the other day; `limit: 2` + `startAfterId` returns the remaining item without duplicates; `countByStatus` returns 3 for pending in-window. (fake_cloud_firestore 4.x supports `count()`; if the count assertions throw `UnimplementedError`, keep the count test `skip:`-annotated with a note and rely on the emulator precheck — do NOT fake it.)
- [ ] **Step 2: Run** — FAIL (methods undefined).
- [ ] **Step 3: Implement** in the impl (wrap in the file's `DatabaseException` style):

```dart
  Query _pageQuery({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
  }) {
    Query q = _ref
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (status != null) q = q.where('status', isEqualTo: status.value);
    return q.orderBy('createdAt', descending: true);
  }

  @override
  Future<List<VoidRequestEntity>> getRequestsPage({...}) async {
    var q = _pageQuery(status: status, start: start, end: end);
    if (startAfterId != null) {
      final cursor = await _ref.doc(startAfterId).get();
      if (cursor.exists) q = q.startAfterDocument(cursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map(VoidRequestModel.fromFirestore).toList();
  }

  @override
  Future<int> countByStatus({...}) async {
    final agg = await _pageQuery(status: status, start: start, end: end)
        .count()
        .get();
    return agg.count ?? 0;
  }
```

- [ ] **Step 4: Run + analyze** — PASS/clean.
- [ ] **Step 5: Commit** `feat(mobile): void-request paged query + status count aggregates`

### Task 10: Providers — filters, paged list, counts

**Files:**
- Modify: `lib/presentation/providers/void_request_provider.dart`
- Test: `test/presentation/providers/void_request_paging_provider_test.dart` (create)

**Interfaces:**
- Consumes: Task 9 repo methods; `dateRangeForPreset` (`lib/core/utils/report_date_range.dart`); `DateRangePreset` (`date_range_picker.dart`).
- Produces (Task 11 depends on these):

```dart
final voidRequestStatusFilterProvider =
    StateProvider.autoDispose<VoidRequestStatus?>((_) => null);
final voidRequestDatePresetProvider =
    StateProvider.autoDispose<DateRangePreset>((_) => DateRangePreset.today);
final voidRequestDateRangeProvider =
    StateProvider.autoDispose<DateTimeRange>(
        (_) => dateRangeForPreset(DateRangePreset.today, DateTime.now()));

class PagedVoidRequests {
  final List<VoidRequestEntity> items;
  final bool hasMore;
  const PagedVoidRequests({required this.items, required this.hasMore});
}

final pagedVoidRequestsProvider = AsyncNotifierProvider.autoDispose<
    PagedVoidRequestsNotifier, PagedVoidRequests>(PagedVoidRequestsNotifier.new);
// notifier exposes: Future<void> loadMore()

final voidRequestStatusCountProvider = FutureProvider.autoDispose
    .family<int, VoidRequestStatus>(...); // watches the range provider
```

- [ ] **Step 1: Failing provider test** — `ProviderContainer` with `voidRequestRepositoryProvider` overridden to a fake (hand-written class implementing the two Task-9 methods over an in-memory list) + `currentUserProvider` admin. Assert: initial build loads page 1 (`hasMore` true when a full `limit` page returned); `loadMore()` appends without duplicates and flips `hasMore` false on a short page; changing `voidRequestStatusFilterProvider` re-builds from page 1; count family returns the fake's number and re-fetches when the range provider changes.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** the notifier:

```dart
class PagedVoidRequestsNotifier
    extends AutoDisposeAsyncNotifier<PagedVoidRequests> {
  static const _pageSize = 20;

  @override
  Future<PagedVoidRequests> build() async {
    final status = ref.watch(voidRequestStatusFilterProvider);
    final range = ref.watch(voidRequestDateRangeProvider);
    final items = await ref.read(voidRequestRepositoryProvider).getRequestsPage(
        status: status, start: range.start, end: range.end, limit: _pageSize);
    return PagedVoidRequests(
        items: items, hasMore: items.length == _pageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    final status = ref.read(voidRequestStatusFilterProvider);
    final range = ref.read(voidRequestDateRangeProvider);
    final next = await ref.read(voidRequestRepositoryProvider).getRequestsPage(
        status: status,
        start: range.start,
        end: range.end,
        limit: _pageSize,
        startAfterId: current.items.last.id);
    state = AsyncValue.data(PagedVoidRequests(
        items: [...current.items, ...next],
        hasMore: next.length == _pageSize));
  }
}
```

Count family: `ref.watch(voidRequestDateRangeProvider)` then `repo.countByStatus(status: status, start: range.start, end: range.end)`. Add `ref.invalidate(pagedVoidRequestsProvider); ref.invalidate(voidRequestStatusCountProvider);` next to every existing `_ref.invalidate(voidRequestsProvider)` in `VoidRequestOperationsNotifier` (requestVoid/approve/reject/markRead/markAllRead).

- [ ] **Step 4: Run + analyze** — PASS/clean.
- [ ] **Step 5: Commit** `feat(mobile): void-request filter/paging/count providers`

### Task 11: Void-requests screen — cards, date filter, load more

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/void_requests_screen.dart`
- Create: `lib/presentation/mobile/widgets/sales/void_status_summary_cards.dart`
- Test: `test/presentation/mobile/widgets/sales/void_status_summary_cards_test.dart` (create), `test/presentation/mobile/screens/sales/void_requests_screen_filter_test.dart` (create)

**Interfaces:**
- Consumes: Task 10 providers; `DateRangePicker` (`selectedPreset/startDate/endDate/onPresetChanged/onCustomRangeSelected`); `dateRangeForPreset`; existing `VoidStatusStyle` colors (`void_status_style.dart`); Inventory card look: `AppCard` with icon, big count, label, 1.5px colored border when selected (`inventory_screen.dart:264-318` is the reference).

- [ ] **Step 1: Failing cards test** — `VoidStatusSummaryCards` is a pure widget:

```dart
VoidStatusSummaryCards(
  pendingCount: 2, approvedCount: 5, rejectedCount: 1,
  selected: VoidRequestStatus.pending, // nullable
  onSelect: (status) {...},            // ValueChanged<VoidRequestStatus?>
)
```

Assert: three cards render label + count ('Pending' with '2', 'Approved' '5', 'Rejected' '1'); tapping 'Approved' fires `onSelect(VoidRequestStatus.approved)`; tapping the already-selected 'Pending' fires `onSelect(null)` (toggle-off).

- [ ] **Step 2: Run** — FAIL (widget missing).
- [ ] **Step 3: Implement `VoidStatusSummaryCards`** — a `Row` of three expanded `AppCard`s copying the inventory summary-card structure (icon + count + label, `selectedBorderColor` ring when selected). Status colors/icons from `VoidStatusStyle` (pending amber `LucideIcons.clock`-style, approved green, rejected red — reuse whatever icon set `void_status_style.dart` exposes; fall back to `LucideIcons.clock/checkCheck/x`). `onTap: () => onSelect(selected == status ? null : status)`.
- [ ] **Step 4: Run cards test** — PASS.
- [ ] **Step 5: Failing screen test** — pump `VoidRequestsScreen` with overrides: `pagedVoidRequestsProvider` list of 2 pending requests w/ `hasMore: false` is awkward to override directly — instead override `voidRequestRepositoryProvider` with the Task-10 fake + `currentUserProvider` admin + count family untouched (flows through fake). Assert: `DateRangePicker` present with Today preset; three cards with counts from the fake; tapping the Pending card narrows the list (fake returns filtered); a 21-item fake shows a `Load more` button that appends the 21st on tap; screen no longer watches the old full stream for the list body.
- [ ] **Step 6: Run** — FAIL.
- [ ] **Step 7: Rework the screen.** Keep the existing request tile widget + resolve bottom sheet + mark-read-on-tap exactly as-is. Replace the body's data source: header column = `VoidStatusSummaryCards` (counts from the three `voidRequestStatusCountProvider(status)` watches, `valueOrNull ?? 0`; selected from `voidRequestStatusFilterProvider`) + `DateRangePicker` wired to the preset/range StateProviders (`onPresetChanged`: set preset + `dateRangeForPreset(preset, DateTime.now())` into the range provider; `onCustomRangeSelected`: set preset `custom` + explicit range) — then the paged list from `pagedVoidRequestsProvider` (loading → existing skeleton; error → `ErrorStateView` invalidating the provider), with a trailing `Load more` `OutlinedButton` when `hasMore`, calling `ref.read(pagedVoidRequestsProvider.notifier).loadMore()`. Remove the old `_CountCaption` pill (superseded by the cards).
- [ ] **Step 8: Run both new test files + any existing void_requests screen tests + analyze** — PASS/clean (update existing screen tests that assumed the old full-stream body).
- [ ] **Step 9: Commit** `feat(mobile): void-requests screen — status cards, date filter, paged loading`

### Task 12: Bell → notification sheet

**Files:**
- Modify: `lib/presentation/shared/widgets/dashboard/void_requests_bell.dart`
- Create: `lib/presentation/shared/widgets/dashboard/void_request_notification_sheet.dart`
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart:171-174` (bell wiring)
- Test: `test/presentation/shared/widgets/dashboard/void_request_notification_sheet_test.dart` (create), `test/presentation/shared/widgets/dashboard/void_requests_bell_test.dart` (update)

**Interfaces:**
- Consumes: `voidRequestsProvider` (existing 50-cap stream — fine for a notification sheet), `unreadVoidRequestCountProvider`, `voidRequestOperationsProvider.markRead`, `RoutePaths.voidRequests`, `itemsSummary` (Task 8).
- Produces: `showVoidRequestNotificationSheet(BuildContext context)` (top-level function in the new file); `VoidRequestsBell` loses its `onPressed` parameter and opens the sheet itself.

- [ ] **Step 1: Failing sheet test** — pump a button that calls `showVoidRequestNotificationSheet(context)` inside a `ProviderScope` overriding `voidRequestsProvider` with two requests (one unread pending w/ `itemsSummary: '2× Brake Shoe'`, one read approved). Assert: entry text `'Belle sent a void request'` (from `requestedByName`); detail line contains the sale number, `₱`-formatted `saleGrandTotal`, and `'2× Brake Shoe'`; a `'View all'` action exists. Tap the unread entry → assert navigation to void requests (wrap in a `MaterialApp` with a test router/`onGenerateRoute` capturing pushes, matching how other nav tests in `test/presentation/shared/widgets/dashboard/` do it) and that a recording fake ops notifier got `markRead(id)`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement the sheet.** `showModalBottomSheet` (rounded top, drag handle, matching the app's existing sheet styling — see the resolve sheet in `void_requests_screen.dart` for idiom). Content: header row 'Void requests' + unread count chip; `ListView` of up to 20 entries from `voidRequestsProvider` (`valueOrNull ?? []`), each entry:

```
{requestedByName} sent a void request          [unread dot]
{saleNumber} · ₱{saleGrandTotal} [· {itemsSummary}]
{relative time, e.g. 5m ago — reuse the app's existing relative-time helper
 if one exists (grep 'timeAgo'/'relative'); else format inline: <60m → Xm ago,
 <24h → Xh ago, else MMM d}
```

Unread entries: bold name + small primary-color dot. `onTap`: `Navigator.pop(context)`, `ref.read(voidRequestOperationsProvider.notifier).markRead(r.id)` (fire-and-forget), then `context.push(RoutePaths.voidRequests)`. Footer `TextButton 'View all'` → pop + push the same route. Empty state: 'No void requests'.

- [ ] **Step 4: Bell rework.** `VoidRequestsBell` drops the `onPressed` param; its `IconButton.onPressed` becomes `() => showVoidRequestNotificationSheet(context)`. Update `dashboard_screen.dart` call site to `const VoidRequestsBell()`. Update the existing bell test (badge assertions unchanged; tap now opens the sheet — assert sheet content appears instead of navigation).
- [ ] **Step 5: Run new + updated tests + analyze** — PASS/clean.
- [ ] **Step 6: Commit** `feat(mobile): bell opens void-request notification sheet`

### Task 13: Composite index

**Files:**
- Modify: `firestore.indexes.json`

- [ ] **Step 1: Add** (alongside the existing sales index objects):

```json
    {
      "collectionGroup": "void_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
```

- [ ] **Step 2: Note in the commit body**: index deploy + a prod precheck of both query shapes (status+range page, status+range count) is a deploy-time step — the emulator does not enforce composite indexes (prior gotcha: detector sale-probe `3c5b1ba`).
- [ ] **Step 3: Commit** `feat(firestore): void_requests (status, createdAt) composite index (NOT deployed)`

---

## Part D — Received amount

### Task 14: `amountReceivedForSale` + `toSale` fix

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart` (`CartState` getters ~line 200; `toSale` ~line 713)
- Test: `test/presentation/providers/cart_provider_test.dart` (append; the file exists with CartState fixtures)

**Interfaces:**
- Produces: `CartState.amountReceivedForSale` — cash (no secondary) → typed `amountReceived`; everything else → `collectedToday` (salmon → `splitAmount`, digital → `grandTotal`).

- [ ] **Step 1: Failing tests** (use the file's existing CartState/notifier fixture helpers to build a cart with one item totaling 320):

```dart
group('amountReceivedForSale (2026-07-25 received-amount fix)', () {
  test('cash stores the typed tender, not the total', () {
    // cart total 320, cashier typed 1000
    expect(state.amountReceivedForSale, 1000);
    expect(state.change, 680);
  });
  test('digital methods store the collected total', () {
    expect(gcashState.amountReceivedForSale, gcashState.grandTotal);
  });
  test('salmon stores the split (collected-today) amount', () {
    expect(salmonState.amountReceivedForSale, salmonState.splitAmount);
  });
  test('toSale persists amountReceivedForSale', () {
    final sale = notifier.toSale(saleNumber: 'S1', cashierId: 'c', cashierName: 'C');
    expect(sale.amountReceived, 1000);
    expect(sale.changeGiven, 680);
  });
});
```

- [ ] **Step 2: Run** — the cash + toSale cases FAIL (today they yield 320).
- [ ] **Step 3: Implement.** In `CartState`, next to `collectedToday`:

```dart
  /// What the customer actually handed over — persisted as the sale's
  /// amountReceived. Cash keeps the typed tender (change comes out of it);
  /// salmon/digital collect exactly collectedToday. (Regression ae42b75
  /// stored collectedToday for cash, losing the tendered amount.)
  double get amountReceivedForSale {
    if (paymentMethod == PaymentMethod.cash && secondaryMethod == null) {
      return amountReceived;
    }
    return collectedToday;
  }
```

`toSale`: `amountReceived: state.amountReceivedForSale,`.

- [ ] **Step 4: Consumer sweep** (spec requirement): run `grep -rn "amountReceived" lib/ --include="*.dart" | grep -v cart_provider` and confirm every consumer is display/serialization (sale model, sale detail, receipt, checkout dialog, entity) — none feed EOD/report math (those use `tenders`/totals). Paste the grep result into the commit body as the audit record. If any consumer DOES treat `amountReceived` as collected-cash math, STOP and surface it before committing.
- [ ] **Step 5: Run the cart test file + full `flutter test` + analyze** — PASS/clean.
- [ ] **Step 6: Commit** `fix(mobile): persist the real tendered cash as amountReceived (regression ae42b75)`

### Task 15: Backfill script

**Files:**
- Create: `scripts/backfill-amount-received-lib.mjs`, `scripts/backfill-amount-received.mjs`, `scripts/backfill-amount-received-lib.test.mjs`

**Interfaces:**
- Produces: pure `planPatch(doc)` → `{amountReceived: number} | null`; CLI dry-run by default, `--execute` to write. NOT run in this plan — deploy-time step.

- [ ] **Step 1: Failing node test** (`node --test scripts/backfill-amount-received-lib.test.mjs`, mirroring `import-inventory-lib.test.mjs` style):

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { planPatch } from './backfill-amount-received-lib.mjs';

test('bug-signature cash sale is patched to received+change', () => {
  assert.deepEqual(
    planPatch({ paymentMethod: 'cash', amountReceived: 320,
                changeGiven: 680, tenders: { cash: 320 } }),
    { amountReceived: 1000 });
});
test('web-written correct doc is skipped (received != tenders.cash)', () => {
  assert.equal(
    planPatch({ paymentMethod: 'cash', amountReceived: 1000,
                changeGiven: 680, tenders: { cash: 320 } }),
    null);
});
test('zero-change and non-cash docs are skipped', () => {
  assert.equal(planPatch({ paymentMethod: 'cash', amountReceived: 320,
                           changeGiven: 0, tenders: { cash: 320 } }), null);
  assert.equal(planPatch({ paymentMethod: 'gcash', amountReceived: 320,
                           changeGiven: 680, tenders: { gcash: 320 } }), null);
});
```

- [ ] **Step 2: Run** — FAIL (module missing).
- [ ] **Step 3: Implement** `planPatch` exactly to the guard: `paymentMethod === 'cash' && changeGiven > 0 && tenders && amountReceived === tenders.cash` → `{ amountReceived: amountReceived + changeGiven }`, else `null`. CLI script: init firebase-admin with `applicationDefault` + `projectId: 'maki-mobile-pos'` (copy the header idiom from `scripts/wipe-transactions.mjs` including the dry-run/`--execute` convention), stream all `sales` docs, log every planned patch (`saleNumber old → new`), summary count; only write (batched `update`) under `--execute`.
- [ ] **Step 4: Run the node test** — PASS. Do NOT run the script against prod.
- [ ] **Step 5: Commit** `feat(scripts): amount-received backfill (dry-run default; deploy-time)`

---

### Task 16: Full verification + finish branch

- [ ] **Step 1:** `flutter test` (expect ~1460+, all green) and `flutter analyze` (clean).
- [ ] **Step 2:** Run the rules suite in `tools/firestore-rules-test/` — green.
- [ ] **Step 3:** `/code-review` the branch diff; fix findings; re-run affected tests.
- [ ] **Step 4:** Use superpowers:finishing-a-development-branch — merge `feat/plus17-quad-batch` into local `main` (no push, no deploys; those are user-confirmed follow-ups: rules deploy, index deploy + prod precheck, backfill dry-run → execute).
