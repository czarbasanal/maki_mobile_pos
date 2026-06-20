# Web POS — Atomic Draft Conversion — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Context:** Deferred follow-up from POS **Phase 4 (drafts)**. The Phase-4
code-review flagged that draft→sale conversion was a **best-effort, fire-and-
forget client write** after the sale (`markConverted.mutate`), so a failed
conversion left the draft open and re-resumable → a **duplicate-sale risk**.
Phase 4 surfaced the error but kept best-effort per its spec. This change makes
the conversion **atomic** and closes the window.

## 1. Problem

Today `PosPage.onComplete` completes the sale (writing `sale.draftId`), then
separately calls `markConverted.mutate({ id: draftId, saleId })` — a best-effort
write to the `drafts` doc. Two gaps:

1. **Not atomic** — if `markConverted` fails (network/permission/tab closed), the
   sale committed but the draft stays `isConverted: false`, lingering on `/drafts`
   and re-resumable → a second sale of the same order.
2. **No double-conversion guard** — two tabs/devices resuming the same draft can
   both check out, producing two sales for one draft.

## 2. Decision (from brainstorming)

When a cart originating from a draft is checked out and **that draft is already
converted**, the checkout **aborts** (the sale does not commit; the cashier's
cart is kept and they see a clear message). This is the real fix — it prevents
the duplicate sale, and Firestore's transaction concurrency makes it race-safe.

## 3. Architecture

### 3.1 Conversion moves into the sale transaction

`FirestoreSaleRepository.create()` already runs one `runTransaction` (counter
read → sale + items + counter + per-item stock decrement) and already receives
`input.draftId` on the `Sale`. Extend it: when `input.draftId` is set,

- **Read** the draft doc — `const draftSnap = await tx.get(draftRef)` — together
  with the existing counter read, **before any write** (Firestore requires all
  reads before writes).
- **Decide** via a pure helper `draftConversionOutcome(exists, isConverted)`:
  - draft exists **and** `isConverted === true` → **`'abort'`**: throw
    `This draft was already converted to a sale` (the whole transaction rolls
    back — no sale, no stock change).
  - draft exists **and** not converted → **`'convert'`**: among the other writes,
    `tx.update(draftRef, { isConverted: true, convertedToSaleId: saleRef.id,
    convertedAt: serverTimestamp() })`.
  - draft does **not** exist (deleted mid-checkout) → **`'skip'`**: commit the
    sale without touching any draft (a deleted draft never blocks a sale).
- The sale and the draft conversion thus **commit together or not at all**.

`draftRef = doc(this.db, FirestoreCollections.drafts, input.draftId)`. The new
read is the only addition to the read phase; the conditional draft write joins
the existing blind writes. `convertedToSaleId` is `saleRef.id` (already
pre-allocated before the transaction).

**Race safety:** two concurrent checkouts of the same draft both read it as
not-converted and both try to write it. Firestore serializes the transactions —
the second to commit detects the draft changed under it, **retries**, re-reads
the now-converted draft, and hits the `'abort'` branch. Exactly one sale wins.

### 3.2 Pure helper — `draftConversionOutcome`

`src/domain/sales/draftConversion.ts` (TDD):

```ts
export type DraftConversionOutcome = 'convert' | 'skip' | 'abort';
export function draftConversionOutcome(exists: boolean, isConverted: boolean): DraftConversionOutcome;
```

- `!exists` → `'skip'`
- `exists && isConverted` → `'abort'`
- `exists && !isConverted` → `'convert'`

The repo calls it with `draftSnap.exists()` and
`draftSnap.get('isConverted') === true`.

### 3.3 Remove the dead client path

- `PosPage.onComplete`: delete the `markConverted.mutate(...)` call (conversion
  is now server-side, driven by `sale.draftId`). The cart's `draftId` is still
  passed into the checkout (unchanged).
- `PosPage`: remove the `useMarkConverted` import + usage and the
  **`markConverted.error` warning banner** — a conversion failure now means the
  *sale* failed and is surfaced by the existing `checkout.error` banner.
- Delete the now-unused `useMarkConverted` (in `useDraftMutations.ts`),
  `markConverted` from the `DraftRepository` interface, and
  `FirestoreDraftRepository.markConverted` (impl).

### 3.4 No `firestore.rules` change

The transaction runs as the active admin and now additionally **reads and
updates** a `drafts` doc. The `drafts` rule already permits this: `read` for any
active user, `update` for the owner or an admin (web users are admins). The sale
create already wrote `sales` + `items` + `settings/sale_counters` + `products`;
adding a `drafts` update keeps every write within existing permissions.

## 4. Error handling & edges

- **Already-converted** → `'abort'`: the sale transaction throws; nothing
  commits; `checkout.error` shows `This draft was already converted to a sale`;
  the cashier's cart is intact (they can clear and re-ring if appropriate).
- **Deleted draft** → `'skip'`: the sale commits normally; no phantom draft doc
  is created.
- **Non-draft sale** (`draftId == null`) → the read/guard/write are all skipped;
  `create()` behaves exactly as today.
- **Concurrent checkouts** → race-safe via Firestore transaction retry (§3.1).

## 5. Testing

- **`draftConversion.test.ts`** — `draftConversionOutcome` for all three cases.
- The transactional behavior (atomic convert, abort-on-already-converted,
  skip-on-deleted) is verified by **manual browser smoke** — `create()` is
  Firestore and untested by unit tests (consistent with how the sale write,
  void, and stock paths are verified).
- **Manual browser smoke:**
  1. Resume a draft → checkout → the draft is gone from `/drafts` (converted) and
     the sale carries `draftId` (Sale Detail / Firestore).
  2. Resume the **same draft in two tabs**; complete tab A; in tab B complete →
     ✅ tab B's checkout **fails** with "already converted to a sale" and **no
     second sale** is created.
  3. Resume a draft, **delete it** from `/drafts` in another tab, then checkout →
     ✅ the sale **still completes**.
  4. A normal (non-draft) cash sale still completes unchanged.

`npm run typecheck && npm run test` green before done.

## 6. Out of scope

- Any change to the drafts list, the Save/Resume flow, or the Sale entity (the
  `draftId` field and the conversion fields already exist).
- Un-converting a draft; reverting a converted draft on void.
- `firestore.rules` (unchanged).
