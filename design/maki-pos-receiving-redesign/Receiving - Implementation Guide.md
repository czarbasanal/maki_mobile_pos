# Receiving — Implementation Guide

Reference implementation: `Receiving.dc.html` (list and detail in one file — clicking a row
swaps the list for the detail view).
Skin, tokens and shared components: `Dashboard - Spec.md`. Read that first; everything here
assumes its §2 tokens, §7 component library and §4 theme rules.

---

## A. Receiving (list)

### What changed and why

The old screen spent its first ~350px on three cards carrying three small numbers — `3`,
`0`, `₱30,983.00` — then showed a "Recent receivings" table of three rows with no search, no
filters and no pagination, followed by roughly half a screen of empty white. The one thing a
stockman needs (find a receipt, see what's still open) wasn't reachable.

1. **The two status counts became one "September" pipeline card** — Completed / Partial /
   Drafts as clickable rows that filter the table. `Open drafts: 0` was a dead zero; drafts
   are now a working view.
2. **Two money cards were added** next to it: `Units in` and `Awaiting count`. A receipt
   that is partially counted is money sitting in a box, and the old screen couldn't show it.
3. **"Recent receivings" became the full table** with saved views, search, a Supplier filter,
   a date range and pagination.
4. **Status is a real column** with four tones, not the single `COMPLETED` badge the old
   screen repeated on every row.
5. **`Lines`, `Received by` and copy buttons** added. The old table showed Units and Total
   only, and nothing was copyable.
6. `+ New Receiving` was a pure-black pill — the only black element in the product. It is now
   the standard amber primary; `Import CSV` became an icon-only button to its right.

### Layout

Standard `AppShell`, padding `20px 28px 36px`, `flex column; gap: 12px`:

```
summary row   — pipeline card + 3 money cards   (auto-fit, minmax(236px, 1fr))
views row     — saved-view chips | New receiving + Import CSV
filters row   — search · Supplier dropdown · date range · clear · count
table card    — scroller + table, empty states, pagination footer
```

### Counts must agree — the trap on this screen

The pipeline card is **September-scoped** and the view chips were **all-time**, so the card
read `Completed 3` while the chip eight pixels below read `Completed 4` (the extra being an
August receipt), with nothing explaining the difference. And the card's header said
`4 receipts` while its own three rows summed to 5.

Rule: **every count on the screen derives from the same filtered set.** In the reference the
chips now follow the active date range and the card header is `inMonth.length`, computed —
never a hard-coded string. Server-side that means one `statusCounts` object computed over the
date range and search but *not* the status filter. Same rule as Job Orders.

### Table columns

| Column | Content | Style |
|---|---|---|
| Reference | `RCV-…` + `CopyButton` | 12.5px mono / 500 |
| Status | pill | 11px / 500, radius 20px |
| Supplier | name, or `Unassigned` in `--text-3` | 12.5px |
| Received | date over `by <user>` | 12px mono + 10.5px `--text-3` |
| Lines | count | 12px mono `--text-2`, right |
| Units | count, `—` when 0 | 12.5px mono, right |
| Total cost | peso, `—` when 0 | 13px mono / 600, right |

Status tones: `Completed` → `--pos-soft`/`--pos` · `Partial` → `--accent-soft`/`--accent-text`
· `Draft` → `--info-soft`/`--info` · `Cancelled` → `--neg-soft`/`--neg`. Route through the
shared `statusTone()`.

A missing supplier renders as `Unassigned` in `--text-3` — not the bare `—` the old screen
used, which read as "no data" rather than "nobody recorded it".

Draft rows should open into the receiving form to be resumed; completed and partial rows open
the detail view.

### Overflow

Seven columns, min-content ~900px, card has `overflow: hidden` for its radius. Use the
standard inner scroller or the right columns clip with no scrollbar:

```html
<div class="card" style="overflow:hidden">
  <div style="overflow-x:auto"><table style="width:100%;min-width:900px">…</table></div>
  <!-- empty states + footer outside the scroller -->
</div>
```

### Empty states

- **No receipts at all**: truck glyph in an amber tile, `No receipts yet`, one line — *counting
  stock in here is what updates on-hand quantities and the cost the register sells against* —
  then `New receiving` and `Import CSV`. Condition is `totalCount === 0` from the server.
- **No matches**: `No receipts match these filters` + `Clear filters`.

Footer hidden entirely when there are no rows. The reference's `showEmptyState` prop exists
only to preview the first case; drop it in production.

---

## B. Receiving detail

### What changed and why

The old detail buried the three facts that matter — supplier, when, who recorded it — in a
single dim 12px line under the reference (`No supplier · Sep 1, 2026, 11:36 PM · Czar`),
unlabeled and lowest-contrast on the page. The items table then spanned full width while a
small totals card floated alone in the middle-right, leaving a large empty band between them.
There were no actions at all.

### New structure — one card, four bands

**1. Identity and actions.** Reference at 19px mono / 600 with its `CopyButton`, the status
pill, then `Print slip` (amber primary) and `Adjust` (secondary) right-aligned.

**2. Facts strip.** `repeat(auto-fit, minmax(170px, 1fr))`, `1px --border-2` dividers, each
tile `14px 20px` with an uppercase 10px label, a 13.5px/600 value and an 11px `--text-3` sub:

| Label | Value | Sub |
|---|---|---|
| Supplier | `No supplier` *(in `--text-3` when absent)* | Walk-in or unrecorded |
| Received | `11:36 PM` *(mono)* | Sep 1, 2026 · Tue |
| Recorded by | `Czar` | Recorded this receipt |
| Total cost | `₱240.00` *(mono)* | 16 units in |

Time leads with the date beneath it — the same treatment as Sale detail, for the same reason.

**3. Items, full width.** Columns: Item (36px thumbnail + name), **SKU** (own column, 12px
mono with its `CopyButton`), Qty, Unit cost, Sell price, **Margin**, Line total. SKU is a
separate column rather than a sub-line under the name — it is scanned down the column when
checking a delivery against a paper invoice. Margin is new and is the number a buyer acts
on: `(price − cost) / price`, colored `≥50%` `--pos`, `25–49%` `--text-2`, `<25%` `--neg`.
Confirm those thresholds with the client.

**4. Totals, then expected value.** Both right-aligned in a `max-width: 340px` column so
labels sit beside their figures. Totals: Lines · Total units · **Total cost** at 23px mono/600.
Below in `--surface-2`: `Retail value` and `Expected profit` at these prices — what the shop
stands to make on the delivery, which the old screen never showed.

---

## C. Data wiring

### List
`GET /api/receivings?status=&supplierId=&from=&to=&q=&page=&size=`

```ts
{
  rows: Array<{
    reference: string,        // 'RCV-20260901-002'
    status: 'draft' | 'partial' | 'completed' | 'cancelled',
    supplier: { id, name } | null,
    receivedAt: string,       // ISO
    recordedBy: { id, name },
    lineCount: number,
    unitCount: number,        // counted units, 0 on a draft
    totalCost: number         // centavos
  }>,
  totalCount: number,
  statusCounts: { all, draft, partial, completed }
}
```

`statusCounts` respects the date range and search but **not** the status filter. Sort newest
first.

### Summary
`GET /api/receivings/summary?month=YYYY-MM`

```ts
{
  receiptCount: number,       // all statuses in the month
  byStatus: { completed, partial, draft },
  receivedCost: number,       // completed only
  unitsIn: number,            // completed only
  awaitingCount: number       // cost on partial receipts
}
```

`byStatus` must sum to `receiptCount`. Say the scope in the label (`September`) and use the
same scope for the chips, or the two disagree on screen.

### Detail
`GET /api/receivings/{reference}`

```ts
{
  reference: string,
  status: string,
  supplier: { id, name } | null,
  receivedAt: string,
  recordedBy: { id, name },
  purchaseOrderRef: string | null,   // link back when it came from a PO
  lines: [{
    sku, name, imageUrl,
    qtyOrdered?: number,             // present when from a PO
    qtyReceived: number,
    unitCost: number,                // centavos, landed
    sellPrice: number                // price at time of receipt
  }],
  totals: { lineCount, units, cost }
}
```

Server sends `totals`; do not recompute a historical receipt in the client. `Retail value`
and `Expected profit` **are** client-derived from the lines — they are projections, not
recorded facts. Money is integer centavos, divided at the render edge.

### Actions
- `POST /api/receivings` → new draft, returns the reference; open the form.
- `POST /api/receivings/{ref}/complete` → posts the count. **This is the write that moves
  stock**: it increments on-hand and updates each product's cost. Must be idempotent and
  transactional — a partial failure that moves some lines and not others is unrecoverable
  from the UI.
- `POST /api/receivings/{ref}/lines/{sku}/adjust` → correct a miscount after completion.
  Should write an adjustment record rather than mutating the receipt, so the paper trail
  survives.
- `POST /api/receivings/import` → CSV. Needs a preview step showing what will be created and
  which rows failed to match a SKU; never import blind.
- `GET /api/receivings/{ref}/slip` → printable slip.

Every completion and adjustment goes to Activity Logs with user, timestamp and delta.

---

## D. Open questions

- Does receiving update each product's cost to the new landed cost, or keep a moving average?
  This is the single most consequential unanswered question here — it changes every margin
  figure in the app.
- Do receipts come from Purchase Orders? If so, the detail needs `qtyOrdered` beside
  `qtyReceived` and a short/over-delivery flag, and `Partial` should mean "less than ordered"
  rather than "not fully counted".
- Can a completed receipt be edited, or only adjusted with a new record?
- Should `Sell price` be editable during receiving, or does it come from the product?

---

## E. Definition of done

- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Every count on the screen derives from the same filtered set — no hard-coded totals.
- Table through `DataTable` with its inner scroller; filters through `FilterBar`; the supplier
  filter through the shared `SelectFilter` (closes on outside `mousedown` and `Escape`, both
  listeners removed on unmount).
- Both empty states present and distinct; footer hidden when empty.
- Skeleton rows at real dimensions while loading.
- Keyboard: rows reachable and activatable, focus rings visible, `Escape` closes the menu.
