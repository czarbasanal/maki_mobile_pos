# Reports — Implementation Guide

Reference implementation: `Reports.dc.html` — the index plus all four report screens in one
file; clicking a card opens a report, the `Reports` button returns.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build from the shared components
> Everything on these five screens already exists in the library: `AppShell`, `Card`,
> `StatCard`, `DateRangeFilter`, `FilterBar`, `SearchInput`, `DataTable`, `SegmentedBar`,
> `MiniBar`, `Badge`, `CopyButton`, `Button`, `Toast`, `EmptyState`, `Skeleton`.
>
> Four report screens means four chances to fork the table. Don't: every table here is
> `DataTable`, every KPI is `StatCard`, every date control is the one `DateRangeFilter`.
> If you catch yourself writing a `<table>`, a chip row or a bar fill inside this feature's
> files, stop and use the shared one.

---

## 1. What changed and why

### Across all five screens

1. **Pure-black KPI cards are gone.** Each screen highlighted one arbitrary card in solid
   black — `Gross Sales` on Sales, `Gross Profit` on Profit, `Total Labor` on Labor — the
   only black surfaces in the product, and off-palette. The lead metric now takes
   `--accent-soft` with an `--accent-line` border and an `--accent-text` label: still clearly
   the headline, still in the palette.
2. **The native `<select>` date dropdown** became the shared segmented `DateRangeFilter`
   (`Today · 7 days · 30 days · Custom`), so all four reports scope identically and the
   control can be styled in both themes.
3. **Every KPI carries a note.** `₱23,729.00` under a bare `Total COGS` label is a number
   without a frame; it now reads `51.4% of sales`. A figure a manager can't situate is a
   figure they can't act on.
4. **CSV export is a consistent header action** rather than a link floating above one table.

### Reports index

Four cards with a small icon, a title and a sentence — a menu with no information. Each card
now carries **two live figures for the active range** (`Gross ₱20,000.00 · Sales 6`), so the
index answers the common question without opening anything. Icons moved into an amber tile,
and a chevron marks them as navigation.

### Sales report

Everything read `₱0.00` with `No sales in this range` and no hint as to why. The empty state
now explains and offers recovery — *The register recorded nothing today. Try Last 7 days, or
check whether the shift was opened* with a **Show last 7 days** button.

`By payment method` was a flat list of four zeros above two unexplained rows
(`Service / Labor`, `Shop fees`). It is now a `SegmentedBar` with per-method share, and the
revenue split is a labelled sub-section carrying `Parts` as well — the parts/labor split is
the shop's fundamental revenue division and was previously implied but never stated.

`Top products` gained quantity, revenue and a proportional bar. Both cards stretch to equal
height (`align-items: stretch`, list `flex: 1; justify-content: space-between`).

**Payment colors:** `Cash` → `--accent` (amber), `Gcash` → `--info` (blue), `Maya` → `--pos`
(green), `Salmon` → `--neg` (red). Map these once, centrally — they must be the same four
tones wherever a payment split appears.

### Profit report

Five KPI cards wrapped 4 + 1, leaving an orphan `Service / Labor profit` on its own row. Now
four cards in one row, `Gross profit` leading with its margin as the note. `Margin` became a
column on the product table with a `MiniBar`, colored `≥50%` `--pos`, `25–49%` `--text-2`,
`<25%` `--neg` — confirm those thresholds.

### Labor report

`Service Sales 42` was labelled like money and read like a count. It is now
**`Jobs with labor: 6`**, plus a derived `Avg per job`. The single mechanic row gained a
share-of-labor bar and an average, and the card foot states the limitation plainly: *One
mechanic is recorded on every job in this range. Assign mechanics on the job order to break
this down.* A one-row breakdown should say why it is one row.

### Price changes

A 25-row wall with an almost-empty `Δ` column, a stray `ΔReason` header, and `9/4/2026`
dates. Now: four KPIs (changes logged, increases, cuts, new products), reason as filter chips
with counts (`receiving` `--info`, `Initial price` `--surface-3`, `Price update` `--accent`),
search, `CopyButton` on every SKU, and the delta as a signed chip **inline with the price**
rather than a mostly-blank column — `+40.00` in `--neg`, `−20.00` in `--pos`, because a price
rise is bad news for the customer and good for margin; confirm which polarity the client
reads.

---

## 2. The rule this screen set broke three times

> **Every figure derives from one scoped set.**

It went wrong twice in a row during design, and both are worth knowing about:

**First:** Sales showed `Gross sales ₱10,710.00` while Profit — same label, same stated range
— showed `₱38,325.00`, because Sales summed a fixture array and Profit used hard-coded
literals. On the index, a profit figure sat *above* a smaller gross sales figure. The
`Top products by profit` table couldn't be reconciled with the sales list either.

**Second:** after fixing that, Price changes still ignored the range control entirely — under
`Today` it claimed 18 changes logged, every row dated Sep 4.

The fix in both cases was the same: **one line-level fixture, everything derived.**

```
SALES: [{ no, day, when, paid, mechanic, labor,
          lines: [{ name, qty, price, cost }] }]

parts   = Σ line.qty × line.price
labor   = Σ sale.labor
gross   = parts + labor
cogs    = Σ line.qty × line.cost
profit  = gross − cogs
margin  = profit / gross
```

Product tables roll up from the same lines; the payment split sums the same sale totals; the
labor breakdown groups the same sales by mechanic; price changes filter on a `day` key
against the same range. **Nothing on any of these screens is a literal.**

Invariants to assert in tests:

- The profit table's revenue column sums to parts revenue; its cost column sums to COGS.
- `gross − cogs === profit` as displayed.
- The payment split sums to gross, and to the sales table's `Total shown`.
- Item counts agree between the sales table and the product table.
- Every KPI, chip count and index-card figure changes when the range changes.

Guard the zero case: `count ? gross / count : 0`, and render `—` rather than `NaN` or
`Infinity` for a share with no denominator.

---

## 3. Layout

```
header row    — [back to Reports] ......... [date range] [CSV]
KPI strip     — StatCards, lead card in accent-soft   (auto-fit, minmax(200px,1fr))
body          — per screen (see below)
```

The date control stays in the same place on all five screens so it never has to be hunted
for. The back button is a filled surface button above the content, consistent with Receiving
and Sale detail.

| Screen | Body |
|---|---|
| Index | 4 nav cards, `auto-fit minmax(300px,1fr)` |
| Sales | payment + top products two-up (`stretch`), then the sales table |
| Profit | one table, `min-width: 820px` |
| Labor | one table, `min-width: 640px`, with a footnote row |
| Price | filter row, then one table, `min-width: 880px` |

Every table sits in the standard inner `overflow-x: auto` scroller — a card with
`overflow: hidden` clips columns with no scrollbar.

---

## 4. Data wiring

One endpoint per report, all taking the same `from`/`to`:

```
GET /api/reports/sales?from=&to=
{
  gross, parts, labor, shopFees, cogs, profit,      // centavos
  saleCount, itemCount,
  byPaymentMethod: [{ method, amount }],            // sums to gross
  topProducts:     [{ sku, name, qty, revenue }],
  sales:           [{ saleNo, soldAt, paidVia, itemCount, total }]
}

GET /api/reports/profit?from=&to=
{
  gross, cogs, profit, margin, laborProfit,
  products: [{ sku, name, qty, revenue, cost, profit, margin }]   // revenue sums to parts
}

GET /api/reports/labor?from=&to=
{
  totalLabor, jobCount,
  byMechanic: [{ mechanicId, name, jobs, labor }]   // labor sums to totalLabor
}

GET /api/reports/price-changes?from=&to=&reason=&q=
{
  rows: [{ sku, name, option, reason, oldPrice, newPrice, delta,
           oldCost, newCost, changedAt, changedBy }],
  totalCount, counts: { receiving, initial, update, increases, cuts }
}

GET /api/reports/summary?from=&to=       // the four index cards, one call
```

Four rules:

1. **The server computes the totals.** A report is a historical statement; the client must not
   re-derive gross from a page of rows. The reference computes client-side only because it
   holds fixtures.
2. **All five endpoints must agree.** `sales.gross === profit.gross`, and
   `profit.profit === profit.gross − profit.cogs`. Ideally they share one query layer, so they
   cannot disagree.
3. **Dates cross the wire as `YYYY-MM-DD`.** A client `toISOString()` shifts the boundary
   across midnight west of UTC and silently drops a day. `to` is inclusive through 23:59:59 in
   `Asia/Manila` — state it in the contract.
4. **COGS uses the cost recorded at the time of sale**, captured on the sale line, not the
   product's current cost. Otherwise every historical margin moves whenever a part is
   received.

Voided and refunded sales must be excluded consistently, and **expenses are not in COGS** —
net profit is a Reports-level figure (`gross − cogs − expenses`) and isn't shown yet. See the
open questions.

CSV export honors the active filters and is generated server-side.

---

## 5. Not built

Net profit including expenses · a revenue-over-time chart (a 12-week `LineChart` on the
Profit report is the obvious next addition) · comparison against the previous period · a
cashier breakdown to sit beside the mechanic one · scheduled emailed reports · drill-through
from a report row to the sale or product · print layout.

---

## 6. Open questions

- **Should Reports show net profit after expenses?** Expenses are recorded but never
  subtracted anywhere in the product, so "profit" here is gross margin only. This is probably
  the most valuable missing figure in the app.
- `Salmon` appears as a payment method with zero in every range. Is it live, a typo, or a
  channel that should be retired?
- `Shop fees` is always `₱0.00`. Real, or dead?
- What margin percentage is too thin? Coloring currently breaks at 50% and 25%.
- On price changes, should a **rise** read as positive (better margin) or negative (costs the
  customer more)? The reference treats a rise as `--neg`.
- Are report figures VAT-inclusive? Same unanswered question as the POS receipt.

---

## 7. Definition of done

- Assembled from §7 components. No table, chip, pill, bar or date control written locally.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- **Every figure on every screen derives from one scoped set**, and every one of them changes
  when the range changes. Invariants from §2 covered by tests.
- No `NaN`, `Infinity` or `₱0.00`-with-no-explanation in the zero case; empty ranges get a
  recovery action, and an empty *filter* result is a different message from an empty *range*.
- All four tables in the inner scroller with a `min-width`.
- Skeleton rows at real dimensions while loading; every async region has an error state.
- Keyboard: index cards reachable and activatable, focus rings visible.
