# POS Register — Implementation Guide

Reference implementation: `MAKI POS Register.dc.html`
Skin, tokens and shared components: `MAKI POS Dashboard - Spec.md` (read that first —
this document assumes its §2 tokens, §7 component library and §4 theme rules).

This is the second screen in the overhaul, after the Dashboard. It is the highest-traffic
screen in the product: a counter clerk uses it dozens of times a day, often one-handed, often
with a customer waiting. Speed and keyboard reach matter more than polish here.

---

## 1. Layout

Two columns inside the standard `AppShell`, page padding `20px 28px 32px`:

```css
display: grid;
grid-template-columns: minmax(480px, 1fr) minmax(360px, 420px);
gap: 16px;
align-items: start;
overflow-x: auto;   /* pane scrolls rather than crushing */
```

The `minmax` floors are not decoration — a bare `1fr 420px` collapses the catalog column to
~174px on a 924px viewport and the part names overlap the price column. Below ~1000px, drop
to a single column with the cart first.

Both columns start at the same Y so the search bar's top edge is flush with the Cart card's.
Do **not** give the cart column `position: sticky` — the catalog list owns its own inner
scroll, so the page barely scrolls and sticky only breaks that alignment.

### Left column — catalog
1. Search field (full column width), with the result count directly beneath it.
2. Results card: a fixed header row, then a scrolling body
   (`max-height: calc(100vh - 300px); overflow-y: auto`).

No category filter chips. Search is the only filter — clerks type or scan, they do not browse.

### Right column — cart
One Card with stacked sections, divided by `1px solid var(--border-2)`:
cart header → line items (`max-height: 300px`, scrolls) → Labor → Order discount →
totals block (`--surface-2` fill) → then the two action buttons **outside** the card.

---

## 2. Component-by-component

### Search field
Surface card, `1px --border`, radius 12px, padding `12px 15px`, `--shadow`.
16px magnifier in `--text-3`; input at **14px** (larger than the app's 12.5px default — it is
the primary target on the screen); a clear (×) IconButton appears only when non-empty.
Placeholder: `Search part name or SKU — scan barcode`.

Result count below: 12px mono `--text-3`, e.g. `8 parts` / `1 part`.

**Required behaviors not yet built:**
- Autofocus on mount and after every completed sale.
- A barcode scan arrives as fast keystrokes ending in `Enter` — on `Enter`, if exactly one
  result matches, add it to the cart and clear the field.
- `↑`/`↓` move a highlighted row, `Enter` adds the highlight.
- Debounce server search at 250ms; keep the local list for the last response.

### Results row
`display: flex; gap: 12px; padding: 13px 18px`, divider `1px --border-2`, hover
`--surface-2`, whole row clickable.

| Element | Style |
|---|---|
| Part name | 13.5px / 500 / -0.1px |
| SKU | 11px mono `--text-3`, with a `CopyButton` beside it |
| On-hand chip | 11.5px mono / 600, radius 7px — see tones below |
| Price | 14px mono / 600 / -0.4px, right-aligned, 96px column |
| Add button | 74px, radius 9px, `--accent` fill, `--accent-ink` text, 12px / 600 |

On-hand chip tones: `0` → `--neg-soft` / `--neg`, label `none`; `1–5` → `--accent-soft` /
`--accent-text`; `> 5` → `--surface-3` / `--text-2`. Adding an out-of-stock part is refused
with an error toast, not a disabled row — the clerk still needs to see it exists.

The `CopyButton` must `stopPropagation()` or copying a SKU also adds the part to the cart.

### Cart line item
Two rows per line. Top: name (13px / 500) + `SKU · ₱price ea` (10.5px mono `--text-3`) +
a trash IconButton that hovers to `--neg-soft` / `--neg`. Bottom: a bordered `− qty +`
stepper (radius 9px, 30px tall, qty 13px mono / 600, floor of 1), a `₱ off` field for the
per-line discount, and the line total right-aligned at 14px mono / 600.

Adding a part already in the cart increments its qty rather than appending a second line.

### Labor
Section header `Labor` (12.5px / 600) with an `+ Add labor` secondary button.
Each row: a description input (flex 1) + a `₱` amount field (56px, mono, right-aligned) +
a remove ×. Mechanic assignment is a chip row (`None` / staff names) — not a dropdown; there
are only a handful of mechanics and a chip is one tap instead of three.

### Order discount
Mode chips `₱ amount` / `% percent`, then a value field whose prefix follows the mode.
Percent clamps to 100; amount clamps to the gross. Active chip styling is the shared
filter-chip treatment: `--accent-soft` fill, `--accent-text` text and border.

### Totals
`--surface-2` block, 16px 18px, rows at 12.5px with mono values:
Parts subtotal · Labor · Discount (shown as `− ₱x` in `--neg` when non-zero) · then a
`1px --border` rule and **Total** at 23px mono / 600 / -1px.

### Actions
Below the card, full width, `gap: 8px`:
- **Checkout** — primary, 14px / 600, radius 12px, `--accent`, with an amber glow
  (`0 6px 18px -8px var(--accent-line)`), labelled `Checkout · ₱total`. The running total on
  the button is deliberate: it is the number the clerk reads aloud.
- **Save as Job Order** — secondary, 13px / 500, surface fill, `--border` outline.

Both refuse an empty cart with an error toast.

### Empty states
Empty cart: `Cart is empty` (13px `--text-2`) + `Search a part and press Add to start a sale.`
No results: `No parts match "<query>"` + `Check the SKU, or search a shorter term.`

### Toasts
Shared singleton from the spec's §7. This screen fires: added to cart (name as detail),
copied to clipboard (SKU), out of stock (error), catalog refreshed, cart cleared,
sale completed (total), saved as job order (JO number).

---

## 3. Money math

Compute in one place — a `useCartTotals` hook or equivalent — never in the view.

```
lineTotal   = max(0, unitPrice * qty - lineOff)
partsSubtotal = Σ lineTotal
laborTotal  = Σ laborAmount
gross       = partsSubtotal + laborTotal
discount    = mode === 'percent'
                ? gross * min(100, pct) / 100
                : min(gross, amount)
total       = max(0, gross - discount)
```

Store money as **integer centavos** and divide only at the render edge. Never accumulate
floats. Format with `'₱' + n.toLocaleString('en-PH', { minimumFractionDigits: 2 })`.
Parse every user-typed number defensively — an empty or garbage field is `0`, not `NaN`.

Confirm before building: is there VAT on the receipt, and is it inclusive or added? The
current design shows no tax line, matching the existing screen. Also confirm whether labor
is discountable and whether per-line and order discounts can stack — the reference lets them.

---

## 4. Data wiring

### Catalog search
`GET /api/parts?q=&limit=50`

```ts
Array<{
  sku: string,          // '00040047'
  name: string,         // 'BRAKE SHOE ASK HD3'
  price: number,        // centavos
  onHand: number,       // at THIS branch
  category?: string,
  barcode?: string
}>
```

Server-side search across `name`, `sku` and `barcode`, prefix-weighted. Return `onHand` for
the active branch only. Cap at 50 and let the field narrow — no pagination in this list.

### Draft cart
Persist the working cart to `localStorage` on every change and restore on mount. A dropped
connection or an accidental refresh mid-sale must not lose the basket.

### Checkout
`POST /api/sales`

```ts
{
  lines:     [{ sku, qty, unitPrice, lineDiscount }],
  labor:     [{ description, amount, mechanicId }],
  discount:  { mode: 'amount' | 'percent', value: number },
  tender:    { method: 'cash' | 'card' | 'gcash' | 'maya', amountTendered?: number },
  cashierId: string,
  idempotencyKey: string   // client-generated UUID
}
→ { saleNo: 'SALE-20260901-028', total, change, receiptUrl }
```

Non-negotiables:
- **Idempotency key per attempt.** A double-tapped Checkout must not create two sales.
- **Server re-prices.** Never trust client `unitPrice`; return an error if it drifted.
- **Stock is decremented server-side in the same transaction.** If a part sold out between
  search and checkout, fail the whole sale and say which line.
- On success: toast the sale number, clear the cart and draft storage, refocus search.

### Save as Job Order
`POST /api/job-orders` — same payload, returns `{ jobOrderNo }`. Reserves stock rather than
decrementing it; the sale is completed later from the Job Orders screen.

### Tender step (to build)
Checkout should open a Drawer, not complete silently: tender method, amount tendered,
change due in large mono, then Confirm. The reference implementation skips it.

### Mechanics
`GET /api/staff?role=mechanic&active=true` → `[{ id, name }]`. Render as chips with `None`
first. If the list ever exceeds ~6, switch to a Select.

---

## 5. Keyboard map

| Key | Action |
|---|---|
| `/` or `Ctrl/Cmd+K` | focus search |
| `Enter` in search | add sole match, or the highlighted row |
| `↑` / `↓` | move result highlight |
| `Esc` | clear search, then close any drawer |
| `F2` | Checkout |
| `F4` | Save as Job Order |
| `+` / `−` on a focused line | adjust qty |

A counter clerk should be able to ring a sale without touching the mouse.

---

## 6. Still to build

Tender/change drawer · receipt print and reprint · held/parked sales · customer attach ·
returns and exchanges · offline queue for dropped connections · price override with manager
PIN · barcode scanner hardware testing.

Build all of it from the §7 primitives in the skin spec. If something is missing there, add
it to the library — not to this screen.
