# Web POS — dedicated Checkout & Draft-edit screens

**Date:** 2026-07-07
**Surface:** React web admin (`web_admin/`)
**Status:** design — awaiting review

## Goal

Turn the two remaining placeholder routes into real, dedicated screens that mirror the
mobile app's structure:

- **`/pos/checkout`** — a standalone payment/confirmation step, reached from the POS cart
  (today the web does payment inline on `/pos`; mobile has a dedicated `checkout_screen`).
- **`/drafts/:id`** — a standalone editor for a held order, reached from the Drafts list
  (today the web edits drafts by "resume into POS"; mobile has a dedicated `draft_edit_screen`).

Both were `<PagePlaceholder phase="…">` and already pass the route guards (`/pos/checkout` is a
common route; `/drafts/*` is treated as common), so no permission/guard changes are needed.

## Non-goals

- No change to the sale-write path, payment helpers, draft schema, Firestore rules, or reporting.
- The existing **resume-into-POS** flow stays (it's how you continue selling a held order); the
  new draft-edit screen is an additional entry point for *modifying* a held order in place.
- No mobile changes.

---

## Architecture

### Shared building block: the cart editor

`PosPage` today owns the whole editing surface (product search, cart lines with qty/discount,
`LaborSection`, mechanic select, discount-type toggle, totals) wired directly to the global
`useCartStore`. The draft-edit screen needs the *same* surface but bound to a **separate** cart
so editing a held order never disturbs an in-progress POS sale.

**Refactor:** extract that surface into a presentational `<CartBuilder store={storeHook} />`
component that takes the store hook as a prop and prop-drills it to its children (the cart line
list and `LaborSection` become `store`-parameterized). No global singleton assumptions inside.

**Store factory:** change `cartStore.ts` from a single `create<CartState>()` singleton to a
factory:

```ts
export const createCartStore = () => create<CartState>((set) => ({ /* unchanged */ }));
export const useCartStore = createCartStore();       // the POS global instance (unchanged import)
```

`CartState`, its actions, and behavior are untouched — only wrapped in a factory. `useCartStore`
keeps its current identity so every existing import and the existing `cartStore.test.ts` keep
working. A second instance, `useDraftEditStore = createCartStore()`, backs the draft editor.

### Screen 1 — Checkout (`/pos/checkout`) — *independent of the refactor*

`CheckoutPage` reads the **global** `useCartStore`, so it needs none of the store-factory work
and can ship first.

- **`PosPage` change:** the right-column payment block (the `<PaymentSection>` + "Complete sale"
  button + `usePaymentDraft`/`onComplete`) moves off `/pos`. In its place, a primary **Checkout**
  button (enabled when `lines.length > 0`) that navigates to `/pos/checkout`. The cart, labor,
  totals, discount toggle, and the Save-as-draft button/dialog stay on `/pos`.
- **`CheckoutPage` (`/pos/checkout`):**
  - **Empty-cart guard:** `if (lines.length === 0) return <Navigate to="/pos" replace />` — covers
    hard refresh / direct nav (the cart is in-memory Zustand).
  - Layout: back link "← Back to cart" → `/pos`; a **read-only order summary** (items with qty +
    net, labor lines, discount, subtotal/labor/total — the same figures `PosPage` shows, rendered
    read-only); then `<PaymentSection>` (moved here) + **Complete sale**.
  - `usePaymentDraft(grandTotal)` now lives here; `grandTotal` derives from the global cart store.
  - **On success:** run the existing `checkout.mutateAsync({...})` payload verbatim, then
    `pay.reset()`, `clear()`, and `navigate('/pos', { state: { completedSaleNumber } })`.
  - `PosPage` reads `location.state.completedSaleNumber` on mount to show the existing green
    "Sale … completed." banner, then clears the router state (`navigate(replace)`), preserving
    today's "land back on POS ready for the next sale" behavior.
- **Wiring:** `routes.tsx` swaps the placeholder for `<CheckoutPage/>`. No guard change.

### Screen 2 — Draft edit (`/drafts/:id`) — *uses the refactor*

- **New hook `useDraft(id)`** → `repo.getById(id)` via React Query (`queryKeys.drafts.byId(id)`).
- **`DraftEditPage` (`/drafts/:id`):**
  - States: loading → `LoadingView`; error → `ErrorView "Could not load draft"`; not found →
    `EmptyState "Draft not found"` + back link; **converted guard** — if `draft.isConverted`, show
    a short notice ("This draft was already billed out and can't be edited") + back link, no editor.
  - On load, hydrate `useDraftEditStore` from the draft via `loadDraft(draft)`.
  - Layout: header (back link "← Drafts", title "Edit draft"); an editable **Draft name** field;
    `<CartBuilder store={useDraftEditStore} />` (search to add items, cart lines, labor, mechanic,
    totals — bound to the draft-edit store); footer **Save changes** + **Cancel**.
  - **Save:** `useSaveDraft` with `draftId = id` (→ `repo.update`), payload from the draft-edit
    store; on success `navigate('/drafts')`. **Cancel:** `navigate('/drafts')`, discard (reset the
    draft-edit store). The global POS cart is never touched.
- **`DraftsPage` change:** each draft row gains an **Edit** link → `/drafts/:id`, alongside the
  existing **Resume** and delete actions (Resume = load into POS to sell; Edit = modify in place).
- **Wiring:** `routes.tsx` swaps the placeholder for `<DraftEditPage/>`. `/drafts/:id` is already
  a common route — no guard change.

---

## Data flow

- Checkout reads the global cart, writes the sale through the existing `useCheckout` mutation, and
  hands the sale number back to `/pos` via router state. Nothing new touches Firestore.
- Draft edit reads one draft (`getById`), edits a private store instance, and writes via the
  existing `useSaveDraft` update path. No schema or rules change.

## Error handling

- Checkout: existing `checkout.error` banner renders on the checkout page; empty-cart redirect
  guards refresh/direct-nav.
- Draft edit: load error / not-found / converted-draft each have an explicit state; save errors
  surface from `useSaveDraft.error`; the save button locks (`isPending`) as elsewhere.

## Testing (Vitest — TDD)

- `cartStore` factory: existing tests pass unchanged; add a test that two `createCartStore()`
  instances mutate independently.
- Checkout: unit-test the empty-cart guard (redirect) and that the success navigation carries the
  sale number; the sale payload is already covered by existing checkout tests.
- Draft edit: `useDraft(id)` load; hydrate → edit → save calls `repo.update` with the draft id;
  converted-draft guard renders the notice, not the editor.
- Route guards: `routeGuards.test.ts` already covers `/pos/checkout` and `/drafts/:id` as common.

## Implementation slices

1. **Checkout** — move payment to `CheckoutPage`, add the Checkout button + success-state handoff,
   wire the route. Independent of the store refactor; ships first.
2. **Draft edit** — store factory + `<CartBuilder>` extraction, `useDraft(id)`, `DraftEditPage`,
   the DraftsPage **Edit** entry point, wire the route.

Each slice: TDD → `/code-review` → `/verify` (`npm run typecheck` + `npm run test`) → finish.
