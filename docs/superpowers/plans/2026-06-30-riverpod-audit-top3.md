# Riverpod audit top-3 (A2 / A1 / B1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reset session state on logout (A2), bound the lifetime of churning family providers (A1), and delete the dead swallowing uniqueness probes (B1).

**Architecture:** A2 adds one app-root `ref.listen(currentUserProvider)` (wrapped in a small `sessionResetProvider`) that clears the cart + user-scoped caches on sign-out. A1 adds the `.autoDispose` modifier to six named `.family` providers. B1 removes six unused notifier methods.

**Tech Stack:** Flutter, flutter_riverpod 2.6 (legacy `StateNotifier` / `Provider` / `FutureProvider` / `StreamProvider`), mocktail + flutter_test, Firestore (untouched here).

## Global Constraints

- No `firestore.rules`, schema, or shared-collection **write** changes (A2 only reads/invalidates; A1 is provider-lifetime; B1 deletes dead code).
- TDD where a behavioural assertion exists; mechanical edits (A1 modifier, B1 deletion) are verified by `flutter analyze` + the full `flutter test` suite staying green.
- `flutter analyze` must report "No issues found!" and `flutter test` must be all-green before each commit.
- Tests mirror `lib/` under `test/`.
- Work on branch `feat/riverpod-audit-top3` (already created; spec committed at `0324bf8`).
- Commit message trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: A2 — reset session state on logout

**Files:**
- Create: `lib/presentation/providers/session_reset_provider.dart`
- Create: `test/presentation/providers/session_reset_test.dart`
- Modify: `lib/app_mobile.dart` (add `ref.watch(sessionResetProvider);` in `MAKIPOSMobileApp.build`)

**Interfaces:**
- Produces: `final sessionResetProvider = Provider<void>(...)` — a side-effecting provider that, while alive, listens to `currentUserProvider` and on a non-null→null transition calls `cartProvider.notifier.reset()`, invalidates `allSuppliersProvider` / `securityLogsProvider` / `userActivityLogsProvider` / `entityLogsProvider`, and sets `selectedDraftProvider` to null.
- Consumes: `currentUserProvider` (`AsyncValue<UserEntity?>`, `auth_provider.dart`); `cartProvider` + `CartNotifier.reset()` + `CartNotifier.addItem(SaleItemEntity)` (`cart_provider.dart`); `allSuppliersProvider` (`supplier_provider.dart`); `securityLogsProvider`/`userActivityLogsProvider`/`entityLogsProvider` (`activity_log_provider.dart`); `selectedDraftProvider` (`draft_provider.dart`).

- [ ] **Step 1: Write the failing test**

Create `test/presentation/providers/session_reset_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/session_reset_provider.dart';

UserEntity _admin() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

const _item = SaleItemEntity(
  id: 'i-1',
  productId: 'p-1',
  sku: 'SKU-1',
  name: 'Widget',
  unitPrice: 10,
  unitCost: 5,
  quantity: 1,
);

DraftEntity _draft() => DraftEntity(
      id: 'd-1',
      name: 'Table 9',
      items: const [_item],
      discountType: DiscountType.amount,
      createdBy: 'u1',
      createdByName: 'Admin',
      createdAt: DateTime(2026, 6, 1, 9),
    );

void main() {
  test('clears cart + selected draft when the user signs out', () async {
    final auth = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWith((ref) => auth.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider); // activate the listener
    container.listen(currentUserProvider, (_, __) {}); // keep auth subscribed

    auth.add(_admin());
    await Future<void>.delayed(Duration.zero);

    container.read(cartProvider.notifier).addItem(_item);
    container.read(selectedDraftProvider.notifier).state = _draft();
    expect(container.read(cartProvider).isNotEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNotNull);

    auth.add(null); // sign out
    await Future<void>.delayed(Duration.zero);

    expect(container.read(cartProvider).isEmpty, isTrue);
    expect(container.read(selectedDraftProvider), isNull);
  });

  test('does NOT reset on initial sign-in (null -> user)', () async {
    final auth = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWith((ref) => auth.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    container.read(sessionResetProvider);
    container.listen(currentUserProvider, (_, __) {});

    container.read(cartProvider.notifier).addItem(_item); // cart built pre-auth
    auth.add(_admin());
    await Future<void>.delayed(Duration.zero);

    // Signing IN must not wipe a cart.
    expect(container.read(cartProvider).isNotEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/providers/session_reset_test.dart`
Expected: FAIL to compile — `Undefined name 'sessionResetProvider'` / target of URI doesn't exist.

- [ ] **Step 3: Implement `sessionResetProvider`**

Create `lib/presentation/providers/session_reset_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/supplier_provider.dart';

/// Clears all user-scoped session state when the signed-in user transitions
/// to null (any sign-out path: manual, token expiry, forced). Activate with
/// `ref.watch(sessionResetProvider)` at the app root so the listener lives for
/// the app's lifetime.
final sessionResetProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<UserEntity?>>(currentUserProvider, (prev, next) {
    final wasSignedIn = prev?.valueOrNull != null;
    final nowSignedOut = next.valueOrNull == null && !next.isLoading;
    if (wasSignedIn && nowSignedOut) {
      ref.read(cartProvider.notifier).reset();
      ref.invalidate(allSuppliersProvider);
      ref.invalidate(securityLogsProvider);
      ref.invalidate(userActivityLogsProvider);
      ref.invalidate(entityLogsProvider);
      ref.read(selectedDraftProvider.notifier).state = null;
    }
  });
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/presentation/providers/session_reset_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Wire the listener into the app root**

In `lib/app_mobile.dart`, add the import and activate the provider at the top of `MAKIPOSMobileApp.build` (before reading the router):

```dart
// add with the other provider imports:
import 'package:maki_mobile_pos/presentation/providers/session_reset_provider.dart';
```

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionResetProvider); // clears session state on sign-out
    final router = ref.watch(mobileRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // ...unchanged...
```

- [ ] **Step 6: Verify analyze + full suite**

Run: `flutter analyze lib/app_mobile.dart lib/presentation/providers/session_reset_provider.dart test/presentation/providers/session_reset_test.dart`
Expected: No issues found!
Run: `flutter test`
Expected: All tests passed!

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/session_reset_provider.dart \
        test/presentation/providers/session_reset_test.dart \
        lib/app_mobile.dart
git commit -m "fix(state): reset cart + user-scoped caches on sign-out (A2)

Root sessionResetProvider listens on currentUserProvider; on a non-null->null
transition it resets cartProvider and invalidates the non-auth-gated
user-scoped caches (suppliers, activity logs) + clears selectedDraft. Fixes the
shared-device cart bleed between cashiers. First ref.listen in the app.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: A1 — `.autoDispose` on the churning families

**Files (modify the provider declarations only):**
- `lib/presentation/providers/product_provider.dart:77` (`localProductSearchProvider`)
- `lib/presentation/providers/product_provider.dart:67` (`productSearchProvider`)
- `lib/presentation/providers/sale_provider.dart:47` (`salesByDateRangeProvider`)
- `lib/presentation/providers/expense_provider.dart:59` (`expensesByDateRangeProvider`)
- `lib/presentation/providers/activity_log_provider.dart:45` (`activityLogsProvider`)
- `lib/presentation/providers/void_request_provider.dart:65` (`pendingVoidRequestForSaleProvider`)

**Interfaces:**
- Produces: the same six provider names with unchanged value/param types; only their lifetime changes. Consumer `ref.watch(provider(arg))` call sites are unchanged.

The edit is identical in shape for each: insert `.autoDispose` between the provider constructor and `.family`.

- [ ] **Step 1: Edit `localProductSearchProvider`**

`lib/presentation/providers/product_provider.dart` — change:
```dart
final localProductSearchProvider =
    Provider.family<AsyncValue<List<ProductEntity>>, String>((ref, query) {
```
to:
```dart
final localProductSearchProvider =
    Provider.autoDispose.family<AsyncValue<List<ProductEntity>>, String>((ref, query) {
```

- [ ] **Step 2: Edit `productSearchProvider`**

`lib/presentation/providers/product_provider.dart` — change:
```dart
final productSearchProvider =
    FutureProvider.family<List<ProductEntity>, String>((ref, query) async {
```
to:
```dart
final productSearchProvider =
    FutureProvider.autoDispose.family<List<ProductEntity>, String>((ref, query) async {
```

- [ ] **Step 3: Edit `salesByDateRangeProvider`**

`lib/presentation/providers/sale_provider.dart` — change:
```dart
final salesByDateRangeProvider =
    FutureProvider.family<List<SaleEntity>, DateRangeParams>(
```
to:
```dart
final salesByDateRangeProvider =
    FutureProvider.autoDispose.family<List<SaleEntity>, DateRangeParams>(
```

- [ ] **Step 4: Edit `expensesByDateRangeProvider`**

`lib/presentation/providers/expense_provider.dart` — change:
```dart
final expensesByDateRangeProvider =
    FutureProvider.family<List<ExpenseEntity>, ExpenseDateRangeParams>(
```
to:
```dart
final expensesByDateRangeProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntity>, ExpenseDateRangeParams>(
```

- [ ] **Step 5: Edit `activityLogsProvider`**

`lib/presentation/providers/activity_log_provider.dart` — change:
```dart
final activityLogsProvider =
    FutureProvider.family<List<ActivityLogEntity>, ActivityLogParams>(
```
to:
```dart
final activityLogsProvider =
    FutureProvider.autoDispose.family<List<ActivityLogEntity>, ActivityLogParams>(
```

- [ ] **Step 6: Edit `pendingVoidRequestForSaleProvider`**

`lib/presentation/providers/void_request_provider.dart` — change:
```dart
final pendingVoidRequestForSaleProvider =
    StreamProvider.family<List<VoidRequestEntity>, String>((ref, saleId) {
```
to:
```dart
final pendingVoidRequestForSaleProvider =
    StreamProvider.autoDispose.family<List<VoidRequestEntity>, String>((ref, saleId) {
```

- [ ] **Step 7: Verify analyze + full suite (autoDispose is transparent to consumers)**

Run: `flutter analyze`
Expected: No issues found!
Run: `flutter test`
Expected: All tests passed! (the modifier is invisible to `ref.watch(provider(arg))`; any failure here means a consumer held the provider across a dispose — investigate that consumer before proceeding.)

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/providers/product_provider.dart \
        lib/presentation/providers/sale_provider.dart \
        lib/presentation/providers/expense_provider.dart \
        lib/presentation/providers/activity_log_provider.dart \
        lib/presentation/providers/void_request_provider.dart
git commit -m "perf(state): autoDispose churning search/date-range/per-sale families (A1)

Bounds the lifetime of localProductSearch/productSearch (POS hot path),
sales/expense/activity date-range families, and the per-saleId pending-void
StreamProvider (a Firestore listener that never tore down). Selective; no
keepAlive needed since each is recomputed on demand.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: B1 — delete the dead swallowing `*Exists` probes

**Files (delete one unused method from each):**
- `lib/presentation/providers/category_provider.dart` — `nameExists` (~:175)
- `lib/presentation/providers/supplier_provider.dart` — `nameExists` (~:190)
- `lib/presentation/providers/mechanic_provider.dart` — `nameExists` (~:115)
- `lib/presentation/providers/user_provider.dart` — `emailExists` (~:195)
- `lib/presentation/providers/draft_provider.dart` — `draftNameExists` (~:219)
- `lib/presentation/providers/product_provider.dart` — `skuExists` (~:321)

Each is a notifier method of the shape (it swallows the repo error to `false`, and has no callers):
```dart
Future<bool> nameExists(String name, {String? excludeXId}) async {
  try {
    return await _repository.nameExists(name: name, excludeXId: excludeXId);
  } catch (e) {
    return false;
  }
}
```

- [ ] **Step 1: Re-confirm zero callers (safety gate)**

Run:
```bash
grep -rnE "\.(nameExists|emailExists|draftNameExists|skuExists)\(" lib --include='*.dart' \
  | grep -vE "_repository\.|repositoryProvider\)\."
```
Expected: NO output. (Every remaining match is a repo-level call inside the probe body itself, which is excluded. If any UI/use-case caller appears, STOP — the probe is live; do not delete it, and revisit the spec.)

- [ ] **Step 2: Delete each probe method**

For each file above: open it, locate the named method (the notifier method that does `try { return await _repository.X(...) } catch { return false }`), and delete the whole method (its doc comment, signature, body, and closing brace). Do not touch the repository-level `X` methods or anything else.

- [ ] **Step 3: Verify analyze + full suite**

Run: `flutter analyze`
Expected: No issues found! (no dangling references, since Step 1 proved there were no callers.)
Run: `flutter test`
Expected: All tests passed!

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/category_provider.dart \
        lib/presentation/providers/supplier_provider.dart \
        lib/presentation/providers/mechanic_provider.dart \
        lib/presentation/providers/user_provider.dart \
        lib/presentation/providers/draft_provider.dart \
        lib/presentation/providers/product_provider.dart
git commit -m "refactor(state): delete dead swallowing *Exists notifier probes (B1)

These six notifier-level uniqueness probes catch repo errors and return false
(a false-negative duplicate guard) but have zero callers — the live guard is
the repository create methods, which already fail closed. Removes misleading
dead code. Repo-level read-then-write TOCTOU deferred (needs transactional
name-claims).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes
- **Spec coverage:** A2 (Task 1), A1 (Task 2), B1 (Task 3) — all three spec sections map to a task. Deferred items (uid-scoping, repo TOCTOU, E/F/G themes) are explicitly out of scope and not tasked.
- **No placeholders:** every code step shows the exact before/after; the only judgement is locating each B1 method, gated by the Step-1 zero-caller grep.
- **Type consistency:** `sessionResetProvider` is `Provider<void>` throughout; A1 keeps each provider's value/param types unchanged (only inserts `.autoDispose`); B1 deletes methods named exactly as grepped.
