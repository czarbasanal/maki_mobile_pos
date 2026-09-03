# Purchase Orders — Implementation Guide

Reference implementation: `Purchase Orders.dc.html` (list and builder in one file — clicking
a row or `+ New purchase order` swaps views).
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library and this screen must be assembled from it, not hand-styled.

> ### Build this from the shared components
> Every element on both screens already exists in the library: `AppShell`, `Card`,
> `TableViews`, `FilterBar`, `SearchInput`, `SegmentedFilter`, `DataTable`, `Badge`,
> `CopyButton`, `Button`, `Toast`, `EmptyState`, `Skeleton`. Nothing here needs a new
> primitive except the two noted in §5 — and those get **added to the library**, not written
> into this screen.
>
> If you find yourself writing a `<table>`, a chip row, a status pill, a checkbox or a
> dropdown inside this feature's files, stop: use the shared one. Copy-pasted table CSS is
> how the old admin ended up with five different table styles.

---

## A. Purchase Orders (list)

### What changed and why

The old list had four problems, all of them structural rather than cosmetic:

1. **Three tabs, three empty states, no way to see anything.** `Pending 0`, `Completed 0`,
   `Cancelled 0` with "No pending purchase orders" under each. The counts were the only
   information on the screen.
2. **`+ New Purchase Order` was a pure-black pill** — the only black element in the product
   and off-palette. Now the standard amber primary.
3. **The empty state was one line of grey text** with no action and no explanation of what a
   purchase order is for. Each tab now has its own copy plus the primary action.
4. **No table at all**, so no columns had been decided. Defined below.

### Layout

Standard `AppShell`. Content `flex column; gap: 12px`, padding `20px 28px 36px`:

```
views row   — TableViews chips (Pending · Completed · Cancelled) | + New purchase order
table card  — DataTable, or EmptyState per view
```

No summary cards. Three tabs and a table is the whole screen — a KPI band here would be
padding, and this list is short by nature.

### Columns

| Column | Content | Style |
|---|---|---|
| Reference | `PO-…` + `CopyButton` | 12.5px mono / 500 |
| Status | `Badge` pill | 11px / 500, radius 20px |
| Trip | trip name | 12.5px / 500 |
| Created | date over `by <user>` | 12px mono + 10.5px `--text-3` |
| Lines | count | 12px mono `--text-2`, right |
| Est. cost | peso | 13px mono / 600, right |

Status tones through the shared `statusTone()`: `Pending` → `--accent-soft`/`--accent-text` ·
`Completed` → `--pos-soft`/`--pos` · `Cancelled` → `--neg-soft`/`--neg`.

**Trip** is the column that makes this list usable. A PO here is a shopping list for a buying
run, so "which trip was that" is how the user recalls it — not the reference number.
Confirm the field name with the client; the reference invents `Cebu City run`,
`Argao suppliers`, `Colon parts row`.

Row click opens the PO. Pending opens editable; Completed and Cancelled open read-only.

### Empty states — one per view, not one for all three

| View | Title | Body |
|---|---|---|
| Pending | Nothing pending | Start a purchase order to plan a buying trip. |
| Completed | No completed orders | Orders you have finished buying against will land here. |
| Cancelled | No cancelled orders | Orders you abandon keep their trail here. |

Amber `EmptyState` tile with a document glyph, 14.5px/600 title, 12.5px `--text-3` body capped
at 340px with `text-wrap: pretty`, then `+ New purchase order`. The Cancelled and Completed
copy explains what *will* appear there — an empty tab should teach, not just report absence.

---

## B. New purchase order (builder)

### The problem this solves

The old flow gave you a blank order to fill by hand, which means the buyer decides what to
buy from memory. The builder starts from what the shelf actually needs and lets the buyer
argue with it.

### Suggested quantity

```
rate      = soldInWindow / windowDays
suggested = max(0, ceil(rate × coverDays) − onHand)
```

Two segmented controls drive it, both in the header card:

- **Movement window** — 7 / 30 / 90 days. How far back to read demand.
- **Cover** — 7 / 14 / 30 days. How long the shelf should last after the trip.

Changing either recomputes every unedited line and **discards manual overrides** (the
reference clears `qty` state). Confirm that with the client: preserving overrides across a
window change is defensible too, but silently mixing old overrides with new suggestions is
not. Whichever you pick, say it in the UI.

Defaults: 30-day window, 14-day cover. Ask the client — a shop that buys weekly wants a
7-day cover and will find 14 wasteful.

### Line table

| Column | Content |
|---|---|
| checkbox | include this line; unchecking greys the row (`--surface-2`) and blanks Amount |
| Part | name + `OUT` / `LOW` badge |
| SKU | own column, 12px mono, `CopyButton` |
| Buy from | supplier, or `Not set` in `--text-3` |
| On hand | count, colored `--neg` at 0, `--accent-text` at ≤10 |
| Sold {window}d | count — header text follows the window control |
| Qty | editable input, 56px, right-aligned mono; amber border when overridden, with a reset button beside it |
| Cost | last known unit cost |
| Amount | qty × cost, `—` when the line is off |

`min-width: 1080px` inside the `DataTable` scroller — nine columns will clip otherwise.

**Qty is the only editable cell**, and it must show that it has been touched: `--accent-text`
border plus a circular-arrow reset that restores the suggestion. Without that the buyer can't
tell their own edits from the system's numbers.

**`Not set` for a missing supplier**, in `--text-3` — not a bare `—`. It reads as "nobody has
decided yet", which is a task, rather than "no data", which isn't.

Scope chips: `Needs buying` · `Out of stock` · `Low stock`, each with a count.

### Sticky action bar

Pinned to the bottom (`position: sticky; bottom: 0`), `--surface` with a top border and an
upward shadow. Left: **Lines**, **Units**, **Suppliers** (distinct supplier count — it tells
the buyer how many stops the trip is). Right: **Estimated cost** at 23px mono/600, then
`Save draft` (secondary) and `Create purchase order` (primary, `opacity .45` and refusing
while nothing is selected).

The bar must stay visible while scrolling a 200-line order. A buyer adjusting quantities is
watching that total.

---

## C. Data wiring

### List
`GET /api/purchase-orders?status=&q=&page=&size=`

```ts
{
  rows: Array<{
    reference: string,               // 'PO-20260902-002'
    status: 'pending' | 'completed' | 'cancelled',
    tripName: string | null,
    createdAt: string,               // ISO
    createdBy: { id, name },
    lineCount: number,
    estimatedCost: number            // centavos
  }>,
  totalCount: number,
  statusCounts: { pending, completed, cancelled }
}
```

`statusCounts` respects search but **not** the status filter, or the chip counts contradict
the rows. Same rule as every list in this app.

### Suggestions
`GET /api/purchase-orders/suggestions?windowDays=30&coverDays=14&scope=needs_buying`

```ts
Array<{
  sku, name, imageUrl,
  supplier: { id, name } | null,     // preferred supplier
  onHand: number,
  soldInWindow: number,
  lastUnitCost: number,              // centavos
  suggestedQty: number               // server computes; client shows
}>
```

Compute `suggestedQty` server-side so the POS, a future mobile view and any scheduled
reorder report agree. The client recomputes only when the user moves a slider before a
refetch lands.

### Create
`POST /api/purchase-orders`

```ts
{
  tripName: string,
  status: 'pending' | 'draft',
  lines: [{ sku, qty, supplierId: string | null, estimatedUnitCost: number }],
  windowDays: number, coverDays: number,   // provenance: what produced these numbers
  idempotencyKey: string
}
→ { reference, estimatedCost }
```

Store `windowDays` / `coverDays` on the order. Six weeks later, "why did we buy 40 of these"
is answerable only if the assumptions were recorded.

A PO **reserves nothing and moves no stock**. It is a plan. Stock moves in Receiving — see
that guide.

### Other endpoints
- `POST /api/purchase-orders/{ref}/cancel { reason }`
- `POST /api/purchase-orders/{ref}/complete` → typically triggered by receiving against it
- `GET /api/purchase-orders/{ref}/print` → the list the buyer carries
- `PATCH /api/purchase-orders/{ref}/lines/{sku} { qty, supplierId }`

Every create, cancel and completion goes to Activity Logs with user and timestamp.

---

## D. Two additions to the shared library

Both belong in §7, not in this feature:

1. **`DataTable` row selection.** `selection={{ selectedKeys, onToggle, onToggleAll }}`, a
   header checkbox reflecting all/none/indeterminate, and the 17px tokenized checkbox
   (`--accent` fill, `--accent-line` border, `--accent-ink` tick — never a native checkbox).
   Void Requests and bulk inventory edits need the same thing.
2. **`StickyActionBar`.** Summary figures left, primary and secondary actions right, `--surface`
   with a top border and upward shadow. Any multi-select bulk screen will want it.

---

## E. Open questions

- Does a PO record a **trip**, or is it per-supplier? The whole list design turns on this.
  The reference assumes one order can span several suppliers with the supplier recorded per
  line, matching how the shop appears to buy.
- What default cover period? 14 days is a guess.
- When the window or cover changes, should manual qty overrides survive?
- Does receiving against a PO complete it automatically, and does a short delivery leave it
  pending?
- Should the builder offer parts that have **never** sold but are out of stock? Demand-based
  suggestion hides them entirely.

---

## F. Definition of done

- Assembled from §7 components. No table, chip, pill, checkbox or dropdown written locally.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- All three empty states present with their own copy; counts derive from the same filtered set.
- Overridden qty is visually distinct and resettable.
- Action bar stays pinned while the table scrolls; primary disabled on an empty selection.
- Skeleton rows at real dimensions while loading; `Escape` closes any menu.
- Keyboard: rows reachable, qty inputs tabbable in order, focus rings visible.
