# Riverpod-audit cluster (item E, quick set) — design

**Date:** 2026-06-30
**Branch:** `fix/riverpod-audit-cluster-e`
**Status:** approved (design), pending plan

## Context

The 2026-06-30 Riverpod state-management audit produced a deferred "lower-priority"
backlog (item E). A grounded re-investigation (workflow `wf_d9c75f5c-b19`, 6 read-only
agents) confirmed all findings still exist in current code. This spec covers the **quick
cluster** only — five small/trivial, mobile-only, no-rules, low-risk items plus one dead-code
deletion. The **name-uniqueness TOCTOU epic is explicitly out of scope** (see below).

All changes are behavior-preserving except B1 (adds error feedback) and F1 (enables state
dedup). No `firestore.rules` change, no shared-collection writes, no schema change.

## Scope — six changes

### D1 — repository providers bypass the `firestoreProvider` DI seam
**Problem:** 8 of 14 repo providers construct `…RepositoryImpl()` with no argument, so the
impl falls back to `FirebaseFirestore.instance` internally. Every impl constructor already
accepts an optional `firestore`, so the seam exists — only the call-sites bypass it. This
blocks `ProviderScope(overrides: [firestoreProvider.overrideWith(...)])` in tests.

**Fix:** pass `firestore: ref.watch(firestoreProvider)` at each call-site. Bypassing providers:
- `lib/presentation/providers/auth_provider.dart:13` (`AuthRepositoryImpl`)
- `lib/presentation/providers/sale_provider.dart:18` (`SaleRepositoryImpl`)
- `lib/presentation/providers/user_provider.dart:15` (`UserRepositoryImpl`)
- `lib/presentation/providers/cost_code_provider.dart:11` (`CostCodeRepositoryImpl`)
- `lib/presentation/providers/draft_provider.dart:14` (`DraftRepositoryImpl`)
- `lib/presentation/providers/product_provider.dart:15` (`ProductRepositoryImpl`)
- `lib/presentation/providers/receiving_provider.dart:18` (`ReceivingRepositoryImpl` — keep `productRepository:`)
- `lib/services/activity_logger.dart:312` (`ActivityLogRepositoryImpl`) — verify `ref` access; wire the same way or leave if no `ref` in scope.

**Out of scope:** the `FirebaseAuth?` params on `AuthRepositoryImpl`/`UserRepositoryImpl`.
No `firebaseAuthProvider` exists; adding one is scope creep. Firestore-seam only.

**Behavior:** unchanged (default still `FirebaseFirestore.instance`). Testability only.

### E1 — dead Future/Stream twins
Production reads use the `watch*` Stream twins; the Future getters are dead.
- Delete `getSuppliers` — `lib/domain/repositories/supplier_repository.dart:19` + `lib/data/repositories/supplier_repository_impl.dart:66` (delegated to `getAllSuppliers`, which stays).
- Delete `getProducts` — `lib/domain/repositories/product_repository.dart:48` + `lib/data/repositories/product_repository_impl.dart:210`.
- Delete `getTodaysSales` — `lib/domain/repositories/sale_repository.dart:81` + `lib/data/repositories/sale_repository_impl.dart:189` **and its orphan test** at `test/data/repositories/sale_repository_impl_test.dart:117`.
- `getReceivings` — `lib/domain/repositories/receiving_repository.dart:16` + `lib/data/repositories/receiving_repository_impl.dart:59`: remove from the **interface**, keep impl logic as a **private `_getReceivings`** (still called by `getRecentReceivings`/`getDraftReceivings`).

### F1 — StateNotifier state classes lack value equality
Four custom state classes rely on identity equality, so `copyWith` with identical values
still notifies listeners. `equatable: ^2.0.8` is already a project dependency (16 users;
entities incl. `SaleItemEntity` already `extends Equatable`), so this is a consistency fix.
Add `extends Equatable` + `@override List<Object?> get props` to:
- `CartState` — `lib/presentation/providers/cart_provider.dart:9` (items are `SaleItemEntity`, already equatable → real dedup)
- `InventoryState` — `lib/presentation/providers/inventory_provider.dart:8`
- `CurrentReceivingState` — `lib/presentation/providers/receiving_provider.dart:131`
- `UserOperationsState` — `lib/presentation/providers/user_provider.dart:76`

### G2 — unused codegen toolchain
0 `.g.dart` files, 0 `@riverpod`/`@Riverpod` annotations, 0 `part '*.g.dart'`, 0
`riverpod_annotation` imports, 0 `@JsonSerializable`. Remove from `pubspec.yaml`:
`riverpod_annotation` (line 43), `build_runner` (47), `riverpod_generator` (48),
`json_serializable` (49). **Keep** `equatable` (38) and `flutter_riverpod` (42).
Gate: `flutter pub get` + `flutter analyze` + `flutter test` + a release-APK sanity build.

### B1 — bulk-receiving init has no error handling
`lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart:56` calls
`initNewReceiving()` fire-and-forget in a postFrame callback. If it throws, the user gets no
feedback. Mirror `receiving_screen._startNewReceiving` (`receiving_screen.dart:261`): make the
callback async, `await`, `try/catch`, show `context.showErrorSnackBar(...)` (guarded by
`context.mounted`), and abort.

### `draftNameExists` — dead method (cheap bit of name-TOCTOU)
`lib/data/repositories/draft_repository_impl.dart:406` defines `draftNameExists` but it has
zero callers; `createDraft`/`updateDraftName` enforce no uniqueness. Since the transactional
name-claim approach is deferred, wiring a racy check now would only be undone later. **Delete
it** (interface + impl), consistent with the audit's earlier dead-`*Exists`-probe removal.

### B4 (verify-then-maybe-fix) — drafts cart-loaded-before-delete
Unverified by the investigation. While in the drafts repo, confirm the draft-load handler's
ordering (cart populated before delete; on delete failure cart is populated AND draft lingers).
Fold in a fix **only if confirmed**; otherwise note as not-present.

## Out of scope (separate future initiative)

- **Name-uniqueness TOCTOU epic** — transactional claim collections + `firestore.rules` +
  backfill for `suppliers`/`mechanics`/`product_categories`/`expense_categories` (and likely
  web parity), mirroring the SKU/barcode-guard effort. Lower-value than it appears: Firebase
  Auth already rejects duplicate emails (the `users` case is backstopped), and supplier/
  category/mechanic name-dups are low-probability and admin-recoverable. Its own brainstorm.
- The `FirebaseAuth` DI seam (no provider exists today).

## Testing (TDD)

- **F1:** equality tests — two state instances with identical fields compare `==` and share `hashCode`; a changed field is `!=`.
- **D1:** a representative test proving a `firestoreProvider` override flows into a repo impl (e.g. via `ProviderScope(overrides:)` + a fake Firestore).
- **B1:** init-failure surfaces an error (notifier throws → snackbar shown / nav aborted), mirroring any existing `receiving_screen` test.
- **E1 / G2 / `draftNameExists`:** deletions gated by the full green suite + `flutter analyze` (+ APK build for G2).

## Acceptance criteria

- `flutter analyze` clean; full `flutter test` green (≥ current 830, minus the deleted `getTodaysSales` test, plus new F1/D1/B1 tests).
- Release APK builds after the G2 dependency removal.
- No `firestore.rules`, schema, or shared-collection-write changes.
- Per-item commits on `fix/riverpod-audit-cluster-e`.
