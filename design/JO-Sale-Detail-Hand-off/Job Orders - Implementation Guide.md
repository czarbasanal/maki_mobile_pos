# Job Orders & Sale Detail — Implementation Guide

Reference implementation: `Job Orders & Sale Detail.dc.html` (both screens in one file —
clicking a billed row swaps the list for the detail view).
Skin, tokens and shared components: `Dashboard - Spec.md`. Read that first; everything
here assumes its §2 tokens, §7 component library and §4 theme rules.

These are screens three and four of the overhaul, after Dashboard and POS Register.

---

## A. Job Orders (list)

### Layout
Standard `AppShell`, page padding `20px 28px 36px`, content as a `flex column; gap: 12px`.
Three stacked bands, then the table card.

**Band 1 — saved views + primary action.** Status views on the left; on the right, the
date-range segmented control immediately followed by `+ New Job Order`. The two live in the
same right-aligned group (`margin-left:auto`) so the primary action always sits at the far
right edge.

**Band 2 — filters.** Search field (290px), then the Mechanic dropdown, then a `Clear filters`
text button that appears only when something is filtered. Result count right-aligned in mono.

**Band 3 — the table card**, with the pagination footer inside it.

### Status is a filter, not a column of identical pills
The old screen showed a `BILLED` pill on every row — six identical badges carrying no
information, while open and in-progress tickets were unreachable. Status is now the saved-view
strip: `All` · `Open` · `In progress` · `Billed`, each with a live count. The pill stays in the
row, but it now varies.

Status tones: `Billed` → `--pos-soft`/`--pos` · `In progress` → `--accent-soft`/`--accent-text`
· `Open` → `--info-soft`/`--info` · `Voided` → `--neg-soft`/`--neg`. Map these through the
shared `statusTone()` so they match the Dashboard and POS.

### Date range
A segmented control in a `--surface-3` trough (`gap:4px; padding:3px; radius:11px`), pills
`6px 13px`, radius 8px, active pill takes a `--surface` fill and `--text` at 600.
Presets: `Today` · `Yesterday` · `7 days` · `30 days`.
**Every pill needs `white-space: nowrap`** — without it "7 days" and "30 days" wrap to two
lines at narrow widths and the control doubles in height. Same on the view chips.

A custom range picker is not built. When you add it, put it as a fifth pill opening a popover.

### Mechanic dropdown (custom, not a native `<select>`)
Trigger: surface fill, `1px --border`, radius 10px, min-width 186px, showing a small
`Mechanic` label in `--text-3` then the value at 12.5px/600, with a chevron that rotates 180°
when open. When a mechanic is selected the trigger border and value both switch to
`--accent-text` so an active filter is visible without reading it.

Menu: `position:absolute; top: calc(100% + 6px)`, `z-index:40`, surface card, radius 12px,
5px padding, big soft shadow. Each option is a full-width row: a 14px tick slot
(`✓` in `--accent-text` when selected), the name, and a mono count right-aligned. Selected
option takes `--accent-soft`/`--accent-text`/600.

**Dismissal is mandatory and easy to forget.** The menu must close on:
- selecting an option,
- clicking the trigger again,
- a `mousedown` anywhere outside the wrapper,
- `Escape`.

Attach a ref to the `position:relative` wrapper, add `document` `mousedown` and `keydown`
listeners in `componentDidMount` (capture phase), test `wrapper.contains(e.target)`, and
**remove both listeners in `componentWillUnmount`**. Without this the panel floats over the
first table rows with no way out. Build this once as the shared `SelectFilter` — every other
list screen needs it.

### Table columns

| Column | Content | Style |
|---|---|---|
| JO no. | number + `CopyButton` | 12.5px mono / 500 |
| Status | pill | 11px / 500, radius 20px |
| Motorcycle | model | 12.5px / 500 |
| Mechanic | name, `—` when unassigned | 12.5px `--text-2` |
| Opened | `Sep 1 · 2:22 PM` | 12px mono `--text-2` |
| Items | count, `—` when zero | 12px mono, right |
| Total | peso, `—` when zero | 13px mono / 600, right |
| — | action button | 112px, right |

`Motorcycle` and `Items` are new, and `Opened` carries a time — a service shop needs to know
what unit is on the bench and how long the ticket has been open, not just the calendar day.

The action button reads **View sale** on billed tickets (`--text-2`) and **Resume** on open
ones (`--accent-text`); `Resume` pushes the ticket back into the POS cart. Whole rows are
clickable and do the same thing.

### Overflow — the bug to not re-introduce
Eight columns have an intrinsic min-content width of ~820px. The card wrapper carries
`overflow:hidden` for its radius, so at narrower viewports the Total column and the action
button were clipped **with no scrollbar** — unreachable, not just ugly.

Fix, and the pattern for every table in this app:

```html
<div class="card" style="overflow:hidden">        <!-- keeps the radius -->
  <div style="overflow-x:auto">                   <!-- the scroller -->
    <table style="width:100%;min-width:820px">…</table>
  </div>
  <!-- empty state + pagination footer live outside the scroller -->
</div>
```

Bake it into `DataTable` so no screen has to remember. A grid with `overflow-x:auto` does
**not** solve this — a table can overflow its grid column without the grid ever reporting a
scrollable width.

### Pagination footer
Inside the card, `--surface-2` fill, `1px --border` top. Left: `1–25 of 60` in mono
`--text-3`. Right: `Rows per page` with 25 / 50 / 100 as small mono buttons (active takes a
`--surface` fill), then Prev / Next. **Hide the whole footer when there are no rows** — a
pagination bar under an empty state is noise.

### Empty states — two of them, different
1. **No job orders at all.** A 52px `--accent-soft` rounded tile with a ticket glyph, then
   `No job orders yet` (14.5px/600), one explanatory line at 12.5px `--text-3` capped at
   330px with `text-wrap: pretty`, then a `+ New Job Order` primary button. This is the
   first-run state and it should teach: *open a ticket when a unit comes in, add parts and
   labor as the work goes, bill it at the register.*
2. **No matches for the current filters.** `No job orders match these filters` plus a
   `Clear filters` button. Never show the first-run copy here — the shop does have tickets,
   the filter is just too narrow.

The reference exposes a `showEmptyState` prop purely to preview state 1. Drop it in
production; the real condition is `totalCount === 0` from the server, not `rows.length === 0`
after filtering.

---

## B. Sale detail

### What was wrong with the old screen
The important facts — cashier, mechanic, motorcycle, date and time — were crammed into one
dim 12px subtitle line under the sale number: `Sep 1, 2026, 2:22 PM · Bern · Mechanic: Jeric
· Motorcycle: Smash`. Unlabeled, unscannable, lowest-contrast text on the page. Meanwhile the
items table used the full width, the totals panel floated at the far bottom-right, and a
~600px band of empty white sat between them.

### New structure — one card, four stacked bands

**Band 1 — identity and actions.** Sale no. at 19px mono/600 with its `CopyButton`, a `Paid`
status pill, the originating JO number as a mono `--surface-3` chip (clickable, returns to the
ticket), then `Print receipt` (primary) and `Void sale` (`--neg` text, hovers to `--neg-soft`)
right-aligned.

**Band 2 — the facts strip.** The fix for the buried subtitle. Five tiles in
`grid-template-columns: repeat(auto-fit, minmax(160px, 1fr))`, divided by `1px --border-2`,
each `14px 20px` with three lines:

| | Label (10px, 1px tracked, uppercase, `--text-3`) | Value (13.5px / 600) | Sub (11px `--text-3`) |
|---|---|---|---|
| 1 | Date & time | `2:22 PM` *(mono)* | `Sep 1, 2026 · Tue` |
| 2 | Cashier | `Bern` | Cashier on shift |
| 3 | Mechanic | `Jeric` | Assigned mechanic |
| 4 | Motorcycle | `Smash` | Motorcycle serviced |
| 5 | Tender | `Cash` | Paid in full |

`auto-fit` is deliberate: the strip reflows to 3+2 or 2+2+1 on narrow windows instead of
crushing five columns. Time leads the first tile because "which sale was that" is almost
always answered by time of day, with the date as context beneath it.

**Band 3 — items, full width.** One table across the whole card. Columns: Item (name 12.5px
/500 + SKU 10.5px mono with `CopyButton`), Qty (52px), Unit (92px), Net (100px, 13px mono/600)
— all three numeric columns right-aligned. Wrap it in the same `overflow-x:auto` +
`min-width:400px` scroller as above.

Labor rows sit in the same table, tagged with a 9.5px `LABOR` chip in `--info-soft`/`--info`
before the description, with `—` in Qty and Unit. The old screen used a 🔧 emoji; the chip
reads cleaner and matches the badge system. If a mechanic is attached per labor line, show
the name after the description.

**Band 4 — totals, then tender.** Both below the table, right-aligned in a `max-width:340px`
column so the labels sit next to their figures instead of a screen apart.
Totals block: Parts subtotal · Labor · Discount, then a `1px --border` rule and **Total** at
23px mono/600/-1px. Tender block: `--surface-2` fill, an uppercase `TENDER · CASH` label, then
Amount received and Change.

Discount renders as `− ₱x` in `--neg` when non-zero, plain `₱0.00` in `--text-3` when not.

### Not built yet
Void reason and manager approval flow, receipt preview, reprint history, refund/exchange, an
audit trail of who voided what and when.

---

## C. Data wiring

### List
`GET /api/job-orders?status=&mechanicId=&from=&to=&q=&page=&size=`

```ts
{
  rows: Array<{
    jobOrderNo: string,      // 'JO-090126-006'
    status: 'open' | 'in_progress' | 'billed' | 'voided',
    motorcycle: string,      // free text today; see below
    mechanic: { id, name } | null,
    openedAt: string,        // ISO
    itemCount: number,       // parts + labor lines
    total: number,           // centavos
    saleNo: string | null    // set once billed
  }>,
  totalCount: number,        // drives pagination AND the first-run empty state
  statusCounts: { all, open, in_progress, billed }   // drives the view chip counts
}
```

`statusCounts` must be unfiltered by status but respect the date range and search — otherwise
the chip counts contradict the rows. Sort newest-opened first. Filter server-side; the
reference filters in the client only because it holds fixture data.

`GET /api/staff?role=mechanic&active=true` → the dropdown options, each with a ticket count
for the active range.

### Detail
`GET /api/sales/{saleNo}` — or `GET /api/job-orders/{jobOrderNo}/sale`

```ts
{
  saleNo: string,
  jobOrderNo: string,
  status: 'paid' | 'voided' | 'refunded',
  soldAt: string,                    // ISO — render time large, date beneath
  cashier: { id, name },
  mechanic: { id, name } | null,
  motorcycle: { model: string, plate?: string, customerName?: string },
  parts: [{ sku, name, qty, unitPrice, lineDiscount, net }],
  labor: [{ description, amount, mechanicId? }],
  discount: { mode: 'amount' | 'percent', value: number, amount: number },
  totals: { parts, labor, discount, total },
  tender: { method: 'cash' | 'card' | 'gcash' | 'maya', amountReceived, change }
}
```

**Server sends `totals`; never recompute them in the client.** A historical sale must show
what was actually charged, even if prices or discount rules changed since. (The POS screen is
the opposite case — it computes live.) Money is integer centavos, divided only at the render
edge; format `'₱' + n.toLocaleString('en-PH', { minimumFractionDigits: 2 })`.

### Actions
- `POST /api/sales/{saleNo}/print` → queues the receipt, returns a job id. Toast the sale no.
- `POST /api/void-requests { saleNo, reason }` → a **request**, not an immediate void. Admins
  approve from Void Requests; stock is only restored on approval. The reference toasts
  "Void request submitted" — wire it to a reason drawer before shipping.
- `POST /api/job-orders` → new ticket, returns the JO number; navigate straight into it.
- Resume: load the ticket's lines into the POS cart and route to POS.

### Open question for the client
`motorcycle` is free text today (`Smash`, `MioSporty`, `Adv`, `AIRBLADE`, `MioI125`) — the
casing is inconsistent, which suggests hand entry. Ask whether they want a model list and a
plate number field. Both screens have room for a plate under the model without redesign, and
it would make sale history searchable by unit.

---

## D. Definition of done

- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Every table goes through `DataTable` (with the inner scroller); every filter row through
  `FilterBar`; every identifier gets a `CopyButton`; every dropdown closes on outside click
  and `Escape`.
- Both empty states present and distinct; pagination hidden when empty.
- Loading skeletons at real content dimensions, not spinners.
- Keyboard: rows reachable and activatable, focus rings visible, `Escape` closes menus.
