# Riverpod audit — top-3 follow-ups (A2, A1, B1)

**Date:** 2026-06-30
**Status:** Design — approved for planning
**Surface:** Flutter mobile app (`lib/`)

## Background

The 2026-06-30 multi-agent state-management audit (37 confirmed findings) shipped
two batches of quick wins (merged to local `main` at `0250be4`): receiving/void
error-path hardening + dead-stub cleanup (Batch 1), and UI loading/error/empty-state
consolidation + draft-load hardening (Batch 2).

This spec covers the three highest-impact deferred findings. They are independent
but small; one plan keeps them cohesive.

- **A2** — session state (cart, user-scoped caches) is never reset on logout.
- **A1** — high-cardinality `.family` providers never `autoDispose` → unbounded
  cache + a leaked per-sale Firestore listener.
- **B1** — six `*Exists` uniqueness probes swallow errors to `false`. *Investigation
  revised this finding* (see B1 below).

Non-goals: the broader audit backlog (E/F/G themes, the strategic uid-scoped
ProviderScope, repo-level transactional name-claims). See "Deferred".

---

## A2 — Reset session state on logout

### Problem
The single `ProviderScope` (`main.dart`) is never rebuilt, and `_handleSignOut`
(`dashboard_screen.dart:103`) only calls `signOut()` + navigates. The cart
(`cartProvider`, a ref-less `StateNotifier` with `reset()` at `cart_provider.dart:639`)
and non-auth-gated user-scoped caches are never cleared. On a shared POS device,
cashier A's half-built cart and prior-session data persist for cashier B.

### Approach — root auth-listener
Add a single `ref.listen(currentUserProvider, …)` in the root `ConsumerWidget`
`MAKIPOSMobileApp.build` (`app_mobile.dart:8`), which is always mounted. On a
**non-null → null** transition (i.e. a real sign-out, not a transient loading blip):

```dart
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
```

- This is the app's **first** `ref.listen` — the correct tool for a state-change
  side effect (the audit flagged that zero existed). It fires for **every** logout
  path (manual, token-expiry, forced), not just the dashboard button.
- Auth-gated streams (`authGatedStream`) re-gate themselves on sign-out, so they are
  **not** invalidated here — only the non-gated user-scoped futures
  (`allSuppliersProvider` `supplier_provider.dart:54`; the three activity-log futures
  `activity_log_provider.dart:74/81/90`) plus `cartProvider` and `selectedDraftProvider`.
- Guard on `!next.isLoading` so a transient loading state doesn't fire a reset.

### Testing
Widget/unit test with a controllable auth stream: seed a signed-in user, populate
the cart via `cartProvider`, emit `null`, assert the cart is empty and the listed
providers were invalidated (e.g. via a rebuild/`read` returning fresh state).

---

## A1 — `.autoDispose` on the churning families (selective)

### Problem
46 `.family` providers, 0 `autoDispose`. The worst offenders accumulate forever:
per-query search families on the POS hot path (each also holds a live
`productsProvider` watch and re-filters on every emission), per-date-range report
families, and a per-`saleId` `.snapshots()` stream whose Firestore listener never
tears down.

### Approach — add `.autoDispose` to exactly these
| Provider | File | Kind |
|---|---|---|
| `localProductSearchProvider` | `product_provider.dart:77` | `Provider.family` |
| `productSearchProvider` | `product_provider.dart:67` | `FutureProvider.family` |
| `salesByDateRangeProvider` | `sale_provider.dart:47` | `FutureProvider.family` |
| `expensesByDateRangeProvider` | `expense_provider.dart:59` | `FutureProvider.family` |
| `activityLogsProvider` (keyed by `ActivityLogParams` start/end date) | `activity_log_provider.dart:45` | `FutureProvider.family` |
| `pendingVoidRequestForSaleProvider` | `void_request_provider.dart:65` | `StreamProvider.family` |

Each is keyed per-query / per-date-range / per-sale and recomputed on demand, so
none rely on surviving navigation — safe to dispose with no `keepAlive`. The change
is `X.family<…>` → `X.autoDispose.family<…>`; consumer `ref.watch(provider(arg))`
call sites are unchanged.

### Testing
Existing tests for these providers/screens must stay green (the change is
transparent to consumers). Add a focused test that a disposed family instance is
recreated fresh on next watch (or rely on existing coverage + `flutter analyze`).

---

## B1 — Delete dead swallowing `*Exists` probes (finding revised)

### Investigation result (premise corrected)
The audit flagged six notifier-level probes that `catch { return false }`
(`category/supplier/mechanic nameExists`, `user emailExists`, `draft draftNameExists`,
`product skuExists`) as a "false-negative duplicate guard." Tracing the call graph:

- **Live uniqueness enforcement is the repository `create` methods**, which call the
  *repo-level* `nameExists`/`emailExists` and throw `AlreadyExistsException` on
  duplicate (e.g. `category_repository_impl.dart:57`). The repo-level `nameExists`
  **rethrows** Firestore errors as `DatabaseException` (`category_repository_impl.dart:147`)
  — already fail-closed.
- The six **notifier-level** probes have **zero callers** in `lib/` (UI duplicate
  checks go through repo `create` or a local-stream check). They are dead, misleading
  code.

### Approach — delete the dead probes
Remove the six unused notifier-level `*Exists` methods (and any now-unused private
helpers they pull in). No call sites to update; the live guard already fails closed.

### Deferred (out of scope, noted for the backlog)
The repo-level `nameExists` check is a read-then-write **TOCTOU** — two concurrent
creates of the same name could both pass. Closing it properly needs transactional
name-claims (mirroring the `product_skus` / `product_barcodes` guards), which is a
larger, rules-touching change. Not included here.

---

## Testing strategy
- TDD per fix: failing test first where a behavioural assertion exists (A2 reset;
  A1 disposal if practical), implementation, then green.
- `flutter analyze` clean + full `flutter test` suite green before finishing.
- No `firestore.rules`, schema, or shared-collection **write** changes in this work
  (A2 only reads/invalidates; A1 is provider-lifetime; B1 deletes dead code).

## Risk / rollback
Low. A2 adds one idempotent listener (reset on an already-empty cart is a no-op).
A1 only shortens provider lifetimes. B1 removes unreachable code. Each fix is an
independent commit on a feature branch; revert is per-commit.

## Deferred backlog (unchanged, not in this plan)
A2-strategic (uid-scoped ProviderScope), B1-TOCTOU (transactional name-claims),
and audit themes E (stream/future twins), F (Equatable on StateNotifier payloads),
G (drop/adopt the unused codegen toolchain).
