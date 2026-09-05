# New Receiving — Implementation Guide

Reference implementation: `Receiving.dc.html` — press `+ New receiving` on the list.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library. The Receiving list and detail views are covered by the separate
Receiving handoff; this document is only the builder.

> ### Build from the shared components
> Everything here already exists in the library: `AppShell`, `Card`, `SearchInput`,
> `SelectFilter`, `DataTable`, `Badge`, `Button`, `StickyActionBar`, `Toast`, `EmptyState`.
>
> The `StickyActionBar` is the one specified in the Purchase Orders handoff — summary figures
> left, actions right. Same component, same screen furniture. If it isn't in the library yet,
> add it there rather than writing it into this screen.

---

## 1. What changed and why

The original was a form that recorded keystrokes rather than a counting tool. Six problems:

1. **A native `<select>` for supplier**, ~380px wide, unstyleable in either theme, above an
   otherwise empty band of page.
2. **`+ New product` sat above the search field**, given equal prominence to the thing the
   user does forty times per delivery. Adding a brand-new part is the rare case; it is now a
   secondary button beside the search, and it also appears inside the no-results dropdown,
   which is where you actually discover a part doesn't exist.
3. **A table header with no rows, no inputs and no way in.** `SKU / Item name / Qty / Cost /
   Price / Line total` was rendered as a promise, with `No items yet.` centred beneath it. The
   header now hides until there is a line, replaced by an empty state that says what to do.
4. **`Receive` was a grey disabled pill and `Save draft` an outline button** — the primary
   action styled as the least prominent thing on the screen, and grey-disabled rather than
   amber-at-reduced-opacity.
5. **No margin column.** Cost and sell price were both collected and the number that decides
   whether the price is right was left uncomputed.
6. **No sense of consequence.** Nothing said that receiving moves stock and rewrites cost.
   Now a `Draft` badge plus *Nothing moves until you receive it* in the header, and a line
   under the card restating it.

Added: a search dropdown with live results, a per-line stepper, `on hand → new` per line,
edited-value borders, a three-figure sticky footer, and `Retail value` beside `Total cost`.

Every original field and label is preserved: Supplier, Add items, SKU, Item name, Qty, Cost,
Price, Line total, Total, Save draft, Receive.

---

## 2. Layout

Full content width — **no `max-width`**. This is a data-entry table and the columns should
have all the room the window offers.

```
[Back to receiving]
card
├ header      — RCV reference + CopyButton · Draft badge · consequence line
├ meta grid   — Supplier · Invoice/DR no. · Received      (auto-fit, minmax(220px,1fr))
├ add bar     — search (flex 1) + New product
├ line table  — hidden until a line exists                (min-width 900px, inner scroller)
├ empty state — shown instead of the table when empty
└ sticky foot — Lines · Units in · Retail value ...... Total cost · Save draft · Receive
```

### Header
Reference at 19px mono / 600 with `CopyButton`, an `--info` `Draft` badge, then
*Nothing moves until you receive it* at 11.5px `--text-3`.

### Meta row
**Supplier** is the shared `SelectFilter`; when set, the trigger border and value go
`--accent-text` so a chosen supplier is visible at a glance, and `No supplier` renders in
`--text-3` — it reads as "nobody recorded it", which is a task, not as data.

**Invoice / DR no.** is new and explicitly optional, in mono. Every real delivery arrives with
a paper number on it, and without a field for it the receipt can't be matched back to the
supplier's paperwork.

**Received** shows the business date, read-only in the reference. Wire it to the shared
single-date calendar — a delivery counted the next morning must be dateable to the day it
arrived.

### Add bar
Search field at 14px (larger than the app's 12.5px default — it's the primary target),
`flex: 1`, with a results dropdown at `calc(100% + 6px)`, `z-index: 40`, max 6 results.

Each result row: 30px thumbnail, name, then `SKU · N on hand · last cost ₱X` in mono. The
right-hand action reads **`Add`**, or **`+1`** when the part is already on the receipt — so
scanning the same box twice is legible rather than mysterious.

No results shows the query back plus `+ Create it as a new product`.

**Required behaviors not yet built:**
- Autofocus the search on mount and after every add.
- A barcode scan arrives as fast keystrokes ending in `Enter`; on `Enter` with exactly one
  match, add it and clear.
- `↑`/`↓` to move a highlight, `Enter` to add it.
- Debounce the server query at 250ms.

### Line table

| Column | Content |
|---|---|
| Item | 34px thumbnail + name + `34 on hand → 50` |
| SKU | own column, 12px mono |
| Qty | `− [input] +`, 30px tall, centred mono |
| Unit cost | editable, right-aligned mono |
| Sell price | editable, right-aligned mono |
| Margin | percent, colored by band |
| Line total | qty × cost |
| — | remove (hovers to `--neg`) |

`on hand → new` under each name is the most useful thing on the row: it turns an abstract
quantity into the shelf state the user is looking at.

**Cost and price default to the last known values and mark themselves when changed** — border
goes `--accent-text` on any deviation from the seeded value. A changed cost is a price event
that will propagate to margins across the app, so it should not be possible to change one by
accident and not notice.

Margin: `(price − cost) / price`, `≥50%` `--pos`, `25–49%` `--text-2`, `<25%` `--neg`.
Confirm the thresholds.

Qty floors at 1 — removing a line is the remove button's job, not a zero quantity.

### Sticky footer
`position: sticky; bottom: 0`, `--surface-2` with a top border. Lines · Units in ·
**Retail value** (`--pos`) on the left; **Total cost** at 23px mono / 600 on the right, then
`Save draft` (secondary) and **`Receive into stock`** (amber primary, `opacity .45` while
empty).

The primary is labelled `Receive into stock`, not `Receive`. The verb alone doesn't say that
on-hand quantities are about to change.

`Retail value` sits next to `Total cost` deliberately: it is what the delivery is worth once
sold, and it makes an accidentally-wrong sell price obvious before the receipt is committed.

---

## 3. Data wiring

### Part search
`GET /api/parts?q=&limit=6`

```ts
Array<{
  sku, name, imageUrl,
  onHand: number,
  lastUnitCost: number,     // centavos — seeds the Cost field
  sellPrice: number,        // centavos — seeds the Price field
  barcode?: string
}>
```

Prefix-weighted across name, SKU and barcode. `lastUnitCost` is what makes the form fast:
most deliveries arrive at the price you last paid.

### Draft
`POST /api/receivings` → `{ reference, status: 'draft' }`

Allocate the reference **server-side on create**, not client-side. Two clerks starting a
receipt at once must not both get `RCV-20260905-002`.

Persist the working draft to `localStorage` on every change and restore on mount. A
half-counted delivery lost to an accidental refresh has to be recounted from the boxes.

`PATCH /api/receivings/{ref}` `{ supplierId, invoiceNo, receivedOn, lines }` on save-draft.

### Receive
`POST /api/receivings/{ref}/complete`

```ts
{
  supplierId: string | null,
  invoiceNo: string | null,
  receivedOn: string,                // YYYY-MM-DD
  lines: [{ sku, qty, unitCost, sellPrice }],
  idempotencyKey: string
}
→ { reference, onHandAfter: [{ sku, onHand }], costChanges: [...], priceChanges: [...] }
```

Six non-negotiables:

1. **One transaction.** Increment on hand, write a stock movement per line, update each
   product's cost, write a price-history row for every changed cost or price, mark the receipt
   complete. A partial failure that moves some lines and not others is unrecoverable from the
   UI.
2. **Idempotency key per attempt.** A double-tapped Receive must not double the stock.
3. **Stock moves as append-only movements**, never by overwriting `products.stock`. Same rule
   as the Stock Adjustment modal — on-hand is the sum of its movements, and that is what makes
   sales, receipts and adjustments reconcilable.
4. **Every changed cost or price writes to Price History** with reason `receiving`. The Price
   Changes report reads exactly this.
5. **Money is integer centavos**, parsed at the edge, never accumulated as floats.
6. **`receivedOn` crosses the wire as `YYYY-MM-DD`.** A client `toISOString()` shifts the date
   across midnight west of UTC and files the delivery on the wrong day.

Completion bumps each product's `updatedAt` / `updatedBy` so Record history in the product
modal stays truthful, and writes to Activity Logs with user, reference, unit count and total.

---

## 4. The unanswered question this screen turns on

**Does receiving set each product's cost to the new landed cost, or keep a moving average?**

Raised in the Receiving handoff and still open. It changes every margin figure in the app, and
this screen is where the write happens. Until it is answered the reference assumes *last cost
wins*, which is the simpler and more common choice for a parts shop but overstates margin
after a cheap batch.

---

## 5. Not built

Receiving against a Purchase Order — the important one. When a receipt originates from a PO the
table needs `qtyOrdered` beside `qtyReceived`, a short/over-delivery flag, and `Partial` must
mean *less than ordered* rather than *not fully counted*. The PO handoff assumes this link
exists.

Also missing: the `New product` inline form · CSV import with a preview step (never import
blind) · barcode scanner hardware testing · attaching a photo of the delivery receipt ·
per-line notes for damaged items · a warning when a cost has moved more than some percentage
from the last one, which is the cheapest guard against a typo'd cost propagating everywhere.

---

## 6. Open questions

- Last cost or moving average? (See §4.)
- Should `Sell price` be editable here at all, or does it belong only in the product modal?
  Editing it during receiving is convenient and also the easiest way to mis-price a part.
- Can a receipt be received with no supplier? The reference allows it; the list already shows
  one such historical receipt.
- Should over-receiving against a PO be blocked, warned, or allowed?
- Who may receive — any staff member, or admins only?

---

## 7. Definition of done

- Assembled from §7 components; table through `DataTable` with its inner scroller and
  `min-width: 900px`; footer is the shared `StickyActionBar`.
- Full content width, no `max-width`.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Table header hidden until a line exists; empty state says what to do.
- Cost and price seed from last known values and mark themselves when changed.
- Draft persists to `localStorage` and restores on mount.
- Receive is one idempotent transaction; disabled while empty; reference allocated
  server-side.
- Search autofocused; barcode `Enter` adds a sole match; `↑`/`↓`/`Enter` navigate results.
- `Escape` closes the search dropdown first, the supplier menu next, and only then leaves the
  screen.
