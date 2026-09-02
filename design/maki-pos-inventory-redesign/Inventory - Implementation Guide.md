# Inventory — Implementation Guide

Reference implementation: `Inventory.dc.html`
Skin, tokens and shared components: `Dashboard - Spec.md`. Read that first; everything here
assumes its §2 tokens, §7 component library and §4 theme rules.

---

## 1. What changed and why

The old screen spent roughly 500px of vertical space — the whole first screenful — on six
separate cards before a single product row appeared. Three stat cards (In stock / Low stock /
Out of stock), then the filter row, then three more money cards (Stock Cost / Retail Value /
Expected Profit), then finally the table. On a laptop you scrolled to see any inventory at
all, which is the one thing the screen is for.

Four changes:

1. **The three stock-status cards became one "Stock health" card** — a segmented bar plus
   three labeled rows. Same three numbers, one quarter of the height, and the proportion
   between them is now visible at a glance.
2. **The three money cards stay as cards but move into the same row**, so the whole summary
   band is one row instead of two bands separated by the filter row.
3. **Status became a filter, not just a readout.** Clicking a row in Stock health filters the
   table; the saved-view chips below do the same with counts. Previously "36 low stock" was a
   dead number — you could see the count but not the parts.
4. **Margin is now a column.** Cost and price were both already there; the number the buyer
   actually acts on was left for them to compute.

Also fixed: the `Add product` button was a black pill, the only pure-black element in the
app and off-palette. It is now the standard amber primary. Export lost its label and became
an icon-only button to its right.

---

## 2. Layout

Standard `AppShell`, page padding `20px 28px 36px`, content `flex column; gap: 12px`.

```
summary row     — Stock health card + 3 money cards
views row       — saved-view chips | Add product + Export
filters row     — search · Category dropdown · Active/Archived/All · clear · count
table card      — scroller + table, empty states, pagination footer
```

Summary row: `grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 12px`.
Four cards fit above ~1180px and reflow to 2×2 below it.

### Stock health card
Card padding `15px 17px`, `gap: 11px`. Header: `Stock health` at 11.5px `--text-2` with the
total SKU count right-aligned in mono `--text-3`. Then an 8px segmented bar
(`--pos` / `--accent` / `--neg`, 2px gaps, radius 4px) whose widths are the three shares.
Then three clickable rows: a 7px color square, the label at 12px, the value right-aligned at
13px mono / 600. The active filter's label goes `--text` / 600.

### Money cards
Label 11.5px `--text-2`, value 22px mono / 600 / -1px with `tnum`, note 11px `--text-3`.
Expected profit's value takes `--pos` — it is the only one of the three that is a result
rather than a measurement. Notes carry the basis (`at latest cost`, `at current price`,
`51.5% blended margin`) so the numbers aren't ambiguous.

---

## 3. Filters

Saved views: `All` · `In stock` · `Low stock` · `Out of stock`, each with a count.
Standard chip styling; `white-space: nowrap` on every chip.

Search: 290px, matches name and SKU.

**Category dropdown** — the shared `SelectFilter`, same contract as the Mechanic filter on
Job Orders. Trigger shows a `Category` label plus the value; when a category is selected the
trigger border and value switch to `--accent-text`. Menu is absolutely positioned at
`calc(100% + 6px)`, `z-index: 40`, `max-height: 280px; overflow-y: auto` (there are more
categories than mechanics), each option carrying a tick slot and a count.

It **must** close on: selecting, re-clicking the trigger, `mousedown` outside the wrapper,
and `Escape` — with both document listeners removed on unmount. See the Job Orders guide;
build it once.

Active / Archived / All is a segmented control in a `--surface-3` trough. It is currently
cosmetic — wire it to the `archivedAt` field.

`Clear filters` appears only when something is filtered.

---

## 4. Table

Columns, in order:

| Column | Content | Style |
|---|---|---|
| Product | 38px thumbnail + name + SKU with `CopyButton` | name 12.5px/500, SKU 10.5px mono |
| Category | chip | 11px/500, `--surface-3`/`--text-2`, radius 6px |
| Stock | `MiniBar` + label | 190px; label 11.5px mono/600, 66px right-aligned |
| Cost | peso | 12.5px mono `--text-2`, right, 104px |
| Price | peso | 13px mono/600, right, 104px |
| Margin | percent | 12px mono/600, right, 82px |

**Thumbnail:** 38px square, radius 9px, `--surface-2` fill, `1px --border`, with a 17px
image glyph in `--text-3`. This is a placeholder — swap for `<img>` with `object-fit: cover`
when product photos exist, keeping the same box and radius so rows don't reflow.

**Stock cell:** a 5px rail (`--surface-3` track, `min-width: 52px`) filled to
`stock / reorderMax`, plus a text label. Bar and label color by bucket:
out of stock → `--neg` (bar at 0%, label `none`); low → `--accent-line` bar with
`--accent-text` label; healthy → `--pos` bar with `--text-2` label. A non-zero stock always
renders at least 4% width so a count of 1 is still visible.

The old pill (`78 · In stock`) repeated the status word on every row; the bar carries the
same information positionally and leaves the number legible.

**Margin color:** `≥50%` → `--pos`, `25–49%` → `--text-2`, `<25%` → `--neg`. Confirm those
thresholds with the client — they are a guess at what counts as a thin margin on parts.

**Overflow.** Eight columns have a min-content width of ~920px and the card carries
`overflow: hidden` for its radius. Wrap the table in an inner scroller or the right-hand
columns are clipped with no scrollbar:

```html
<div class="card" style="overflow:hidden">
  <div style="overflow-x:auto">
    <table style="width:100%;min-width:920px">…</table>
  </div>
  <!-- empty states + footer outside the scroller -->
</div>
```

**Footer:** `1–25 of 1,647` in mono, `Rows per page` 25/50/100, Prev/Next. Hidden entirely
when there are no rows.

### Empty states — two, distinct
- **No products at all** (first run): amber tile with a box glyph, `No products yet`, one
  explanatory line, `+ Add product`. Condition is `totalCount === 0` from the server.
- **No matches**: `No products match these filters` + `Clear filters`.

The reference exposes a `showEmptyState` prop only to preview the first case; drop it in
production.

---

## 5. Data wiring

### List
`GET /api/products?status=&category=&archived=&q=&page=&size=&sort=`

```ts
{
  rows: Array<{
    sku: string,             // '00270002'
    name: string,            // '2PIN SOCKET BLACK'
    category: string,        // 'SOCKETS'
    imageUrl: string | null,
    stock: number,           // on hand at the active branch
    reorderPoint: number,    // drives the low-stock bucket
    reorderMax: number,      // drives the bar's 100%
    price: number,           // centavos
    cost: number,            // centavos, latest landed cost
    archivedAt: string | null
  }>,
  totalCount: number,
  statusCounts: { all, inStock, lowStock, outOfStock },
  categories: [{ name, count }]
}
```

Buckets: `stock <= 0` → out of stock; `stock <= reorderPoint` → low; otherwise in stock.
The reference hard-codes `reorderPoint = 10` for all SKUs — real reorder points are per-part
and must come from the server.

`statusCounts` must ignore the status filter but respect category, search and archived state,
or the chip counts contradict the rows. Same for `categories`.

Sort defaults to name ascending; make Stock, Price, Cost and Margin sortable server-side.

### Summary
`GET /api/inventory/summary`

```ts
{
  totalSkus: number,        // 1647
  inStock: number,          // 1509
  lowStock: number,         // 36
  outOfStock: number,       // 102
  stockCost: number,        // 159310200 centavos
  retailValue: number,      // 328571000
  expectedProfit: number    // 169260800
}
```

Compute this server-side over the whole catalog, not from the current page. `expectedProfit`
is `retailValue - stockCost`; the blended margin in the note is `expectedProfit / retailValue`.
Ask the client whether these should respect the active filters — the reference treats them as
whole-catalog totals, which is the more useful reading, but it means the numbers don't move
when you filter and that can confuse.

### Margin
`(price - cost) / price`, rounded to a whole percent, computed client-side from the two
values already in the row. Show `—` when price is 0.

### Actions
- Row click → product detail (stock history, price history, supplier, adjustments). Not built.
- `POST /api/products` → Add product. Not built; needs name, SKU, category, cost, price,
  reorder point, supplier, photo.
- `GET /api/products/export?…` → CSV honoring the current filters. Toast on queue.
- `CopyButton` on every SKU, per the spec's §5.7.

---

## 6. Open questions

- Are reorder points per-part today, or is there a single global threshold?
- Should the three money cards respect the active filters or stay whole-catalog?
- What margin percentage counts as too thin? (Coloring currently breaks at 50 / 25.)
- Is there a second branch? Every stock number here is implicitly single-branch.

---

## 7. Definition of done

- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Table goes through `DataTable` with its inner scroller; filters through `FilterBar`;
  the category filter through the shared `SelectFilter` with outside-click and `Escape`.
- Both empty states present and distinct; footer hidden when empty.
- Skeleton rows at real dimensions while loading — not a spinner.
- Keyboard: rows reachable and activatable, focus rings visible, `Escape` closes the menu.
