# Fixed-ID sales (idempotent checkout) — design

**Date:** 2026-07-01
**Branch:** `fix/sale-idempotency`
**Status:** approved (design), pending plan

## Context

Layer-1 duplicate-prevention (a `_isProcessing` button-lock + re-entry guard on
`checkout_screen._processCheckout`) is already shipped and covers the realistic double-tap.
This is the deferred **layer-2** (idempotent write) for the sale path — the money-critical one.
See [[project_duplicate_entry_prevention]].

**Finding that shaped scope:** completing a sale is a **4-step, non-atomic** orchestration in
`ProcessSaleUseCase.execute`: (1) generate sale number (separate counter transaction), (2) write
the sale + items (a `runTransaction`), (3) subtract stock per item (separate best-effort writes),
(4) mark the draft converted (best-effort). The user chose the **scoped fixed-ID** option: make the
sale write idempotent on a client-supplied checkout ID so a retry can't create a second sale or
double-subtract stock — **without** rewriting the whole flow into one atomic transaction (the "full"
option, explicitly out of scope).

## Goal

A retried checkout (network timeout after the write actually committed, or a re-tap after a
"failure" that had gone through) returns the **existing** sale instead of writing a duplicate, and
does **not** subtract stock again.

## Design

### 1. One fixed ID per checkout attempt
`_CheckoutScreenState` gains `late final String _checkoutId = const Uuid().v4();` (uuid is already a
dependency). The ID is created once when the checkout screen is built and reused for every "Confirm
Payment" tap on that screen. A new checkout = a new screen instance = a fresh ID. Retries within the
same screen (after a failure) reuse the same ID — that stability is what makes idempotency work.

### 2. `ProcessSaleUseCase.execute` — pre-check short-circuit
New **required** param `String checkoutId`. New order:
1. `_validateSale(sale)` (unchanged).
2. **Pre-check:** `final existing = await _saleRepository.getSaleById(checkoutId);` If non-null,
   return `ProcessSaleResult(success: true, sale: existing, warnings: ['This sale was already
   recorded.'])` and do nothing else (no number, no write, no stock, no draft). This handles the
   common sequential retry. Wrap the pre-check read in its own try/catch that **swallows read errors
   and proceeds** — a failed pre-check must not block a real sale; the transaction guard (step 4) is
   the authority.
3. Inventory availability check (warnings only, unchanged).
4. `createSale(sale.copyWith(saleNumber: ''), id: checkoutId)` — **stop pre-generating the sale
   number in the use case**; let `createSale` generate it inside its transaction (so the counter
   increment is now guarded by the same transaction as the sale write). Catch
   `DuplicateSaleException` → `getSaleById(checkoutId)` → return `success(existing)`, skipping stock +
   draft (covers the rare concurrent-same-ID race).
5. On a fresh create only: update inventory + mark draft converted (unchanged), return.

### 3. `createSale` — deterministic doc ID + last-moment guard
Signature gains `{String? id}`. Inside the existing `runTransaction`:
- `final saleDocRef = id != null ? _salesRef.doc(id) : _salesRef.doc();` (no id → today's auto-id
  behavior, unchanged for any other caller).
- `final existing = await transaction.get(saleDocRef);` **before any write** (reads-before-writes).
- `if (existing.exists) throw const DuplicateSaleException();`
- Else: generate sale number if empty (already implemented), `transaction.set` the sale + items,
  return — unchanged.

New `DuplicateSaleException` in `core/errors/exceptions.dart`, mirroring `DuplicateSkuException`.

### 4. Checkout screen wiring
`_processCheckout` passes `checkoutId: _checkoutId` into `execute`. On success (fresh or
short-circuited) the existing success path runs unchanged (reset cart, invalidate providers, show
`CheckoutSuccessDialog`). The `_isProcessing` re-entry guard stays.

## What it covers / residual

- **Covered:** retry-after-timeout and re-tap-after-apparent-failure → one sale, stock subtracted
  once. Duplicate sale **documents** are impossible for a given checkout ID (transaction guard).
- **Unchanged residual (pre-existing, by design — this is the "full" option we skipped):** stock
  subtraction is still a separate best-effort step after the sale write. A crash *between* the sale
  write and the stock step would under-subtract on that one attempt — exactly today's behavior, not
  made worse. Full atomicity is a separate future initiative.

## Scope / non-goals

- **Files:** `checkout_screen.dart`, `process_sale_usecase.dart`, `sale_repository_impl.dart`,
  `sale_repository.dart` (interface), `core/errors/exceptions.dart`.
- **No `firestore.rules` change** — verified: `sales` create is `isValidUser() && isActiveUser()`
  with a wildcard `{saleId}` and no field constraints; a client-chosen UUID doc ID and the `tx.get`
  read are already permitted.
- **No migration:** existing sales keep their auto-generated IDs; only new sales get a UUID ID. Sale
  detail / reports / web read by ID or by field/date — a UUID ID is fine everywhere.
- **No draft idempotency** — layer-1 covers drafts and a duplicate draft is harmless.
- **Not** doing full 4-step atomicity (the "full" option).

## Testing (TDD)

- **Repo:** `createSale` with the same `id` twice → the second throws `DuplicateSaleException`; one
  sale doc exists (`fake_cloud_firestore`).
- **Use case:** `execute` twice with the same `checkoutId` → exactly one sale created and inventory
  `updateStock` called once (fake/mock repos verify the second call short-circuits). A first call
  then a second returns the same sale.
- **Use case:** a fresh `checkoutId` still creates a sale + subtracts stock (no regression).
- Full suite + analyze green.

## Acceptance criteria

- Same checkout ID → one sale, stock once. Fresh ID → normal sale.
- No rules/schema/migration change. Per-item commits on `fix/sale-idempotency`.
