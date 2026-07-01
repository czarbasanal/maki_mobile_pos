# Sale idempotency — close the two residuals (design)

**Date:** 2026-07-01
**Branch:** `fix/sale-idempotency-residuals`
**Status:** approved (design), pending plan

## Context

Fixed-ID sales shipped (`docs/.../2026-07-01-sale-idempotency*`, [[project_duplicate_entry_prevention]]) with two documented residuals. This closes both:
- **A. Stock not in the sale transaction** — stock is subtracted in a separate best-effort step after the sale write, so a crash between the two leaves stock un-subtracted (and the idempotency short-circuit makes that permanent on retry).
- **B. The fixed ID is per checkout SCREEN** — backing out after a committed-but-errored charge and re-opening checkout for the same cart mints a new id → can still duplicate.

Two independent parts, one branch, separate commits.

## Part A — bundle stock into the sale transaction

**Today:** `createSale` writes sale + items + sale-number counter in one `runTransaction`; `ProcessSaleUseCase._updateInventory` then subtracts stock per item in separate best-effort writes (a failure is a warning, not a sale failure).

**Change:** subtract each item's stock **inside** `createSale`'s transaction, so sale + stock are one all-or-nothing unit.

**Design:**
- `createSale(SaleEntity sale, {String? id, bool decrementStock = false})`. `decrementStock` defaults **false** (backward-compatible: existing repo tests and any non-POS caller are unchanged); `ProcessSaleUseCase` opts in with `decrementStock: updateInventory`.
- Add `_productsRef` to `SaleRepositoryImpl` (`_firestore.collection(FirestoreCollections.products)`).
- Inside the transaction, AFTER the sale + items writes, when `decrementStock`, for each `sale.items` line:
  ```dart
  transaction.update(_productsRef.doc(item.productId), {
    'quantity': FieldValue.increment(-item.quantity),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': sale.cashierId,
    'updatedByName': sale.cashierName,
  });
  ```
  This mirrors `ProductRepositoryImpl.updateStock`'s exact 4-key write.
- `ProcessSaleUseCase.execute`: delete the step-4 `_updateInventory` call and the now-dead `_updateInventory` method; pass `decrementStock: updateInventory` to `createSale`. **Keep** `_checkInventoryAvailability` (the pre-transaction low-stock warning) — informational, unchanged.

**Reads-before-writes:** the transaction already does `get(saleDoc)` (idempotency guard) then `get(counter)` (number gen) before any write. The product `update`s are blind (FieldValue.increment, no prior read) and go last — all reads still precede all writes. Valid.

**No `firestore.rules` change** — verified: `products` update rule (lines 103–108) allows any active user to write exactly `['quantity','updatedAt','updatedBy','updatedByName']`; the transaction write hits exactly those keys.

**Behavior change (user-approved):** a stock-write failure now aborts the whole sale (vs today's succeed-with-warning). Near-impossible in practice — products are **soft-deleted** (never removed), so `transaction.update` always targets an existing doc. Overselling is still allowed (blind decrement, stock may go negative — same as today; no availability enforcement inside the transaction). Labor lines have no `productId` and never touch stock.

## Part B — tie the fixed ID to the cart

**Today:** `checkout_screen` holds `late final _checkoutId = const Uuid().v4()` — one id per screen instance, lost when the screen is re-entered.

**Change:** move the id onto `CartState`, which is app-wide and survives navigation.

**Design:**
- `CartState` gains `final String checkoutId` (default `''`); add it to the constructor, `copyWith`, and the Equatable `props`.
- `CartNotifier.ensureCheckoutId()`:
  ```dart
  String ensureCheckoutId() {
    if (state.checkoutId.isEmpty) {
      state = state.copyWith(checkoutId: _uuid.v4());
    }
    return state.checkoutId;
  }
  ```
  Idempotent — mints once, returns the same id on repeat calls (so a re-opened checkout for the same cart reuses it).
- `reset()` / `resetAfterCheckout()` already do `state = const CartState()` → `checkoutId` resets to `''` automatically (fresh id next order). `loadFromDraft` builds a fresh `CartState(...)` without `checkoutId` → `''` → fresh id. No changes needed to those three.
- `checkout_screen`: remove the `_checkoutId` field and the `uuid` import; in `_processCheckout`, `final checkoutId = ref.read(cartProvider.notifier).ensureCheckoutId();` and pass it to `execute(checkoutId: checkoutId)`.

**Effect:** back out of checkout (cart + its `checkoutId` persist) → re-open → same id → the idempotency guard short-circuits the duplicate. On a successful sale the cart resets, so the next order gets a fresh id.

## Scope / non-goals

- **Files:** Part A — `sale_repository.dart`, `sale_repository_impl.dart`, `process_sale_usecase.dart`. Part B — `cart_provider.dart`, `checkout_screen.dart`.
- **No `firestore.rules`, schema, or migration change.**
- Not touching drafts idempotency (still out of scope, harmless).
- Not adding stock-availability *enforcement* (overselling stays allowed, unchanged).

## Testing (TDD)

- **A / repo:** `createSale(sale, id: 'k', decrementStock: true)` against a seeded product decrements its quantity by the sold qty in the same transaction; a duplicate (second call, same id) throws `DuplicateSaleException` and does **not** decrement again (stock unchanged). `decrementStock: false` leaves stock untouched.
- **A / use case:** `execute` with `updateInventory: true` calls `createSale(..., decrementStock: true)` and no longer calls `productRepository.updateStock` (verifyNever). `updateInventory: false` passes `decrementStock: false`.
- **B / cart:** `ensureCheckoutId()` mints once and returns the same id on a second call; `reset()`/`resetAfterCheckout()` clear it (next `ensureCheckoutId` yields a different id); `CartState` equality includes `checkoutId`.
- Full suite + analyze green.

## Acceptance criteria

- Stock subtraction commits atomically with the sale; a retry never re-subtracts and never leaves it un-subtracted for a completed sale.
- Re-opening checkout for the same cart reuses the checkout id (no duplicate sale).
- No rules/schema/migration change. Per-item commits on `fix/sale-idempotency-residuals`.
