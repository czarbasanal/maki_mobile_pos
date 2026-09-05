# MAKI MOTOR PARTS — Reports Redesign Handoff

All five report screens reskinned: the Reports index, Sales report, Profit report, Labor
report and Price changes.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **These screens are assembled from
them** — `AppShell`, `Card`, `StatCard`, `DateRangeFilter`, `FilterBar`, `SearchInput`,
`DataTable`, `SegmentedBar`, `MiniBar`, `Badge`, `CopyButton`, `Button`, `Toast`,
`EmptyState`, `Skeleton`.

Nothing here needs a new primitive. Four report screens means four chances to fork the table
— don't. Every table is `DataTable`, every KPI is `StatCard`, every date control is the one
`DateRangeFilter`. If you catch yourself writing a `<table>`, a chip row or a bar fill inside
this feature's files, stop and use the shared one.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Reports - Implementation Guide.md** — what changed on each screen and why, the
   single-scoped-set rule with its derivation formulas, layout, all five endpoints, open
   questions.

## Reference implementation

**Reports.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider.

Five views in one file:
- **Index** — the default. Each card shows two live figures for the active range.
- **Sales / Profit / Labor / Price changes** — click a card; the `Reports` button returns.

Try these:
- **Move the date range** on any screen → every KPI, table, chip count and index-card figure
  re-derives. Nothing on these screens is a literal.
- **Today** on Sales → the empty state explains why and offers `Show last 7 days`.
- **Today** on Price changes → an *empty range* message, which is deliberately different from
  the *no filter matches* message you get by searching for nonsense.
- **Profit report** → margin column with a bar, colored by band.
- **Labor report** → the footnote explaining why the breakdown is one row.
- **Price changes** → reason chips, SKU copy buttons, and the signed delta chip inline with
  the price.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the library.

## What this redesign fixes

Each screen highlighted one KPI card in **solid black** — the only black surfaces in the
product and off-palette. Date range was a native `<select>`. The index was four cards of icon
and prose with no data. The Sales report showed six `₱0.00` figures and `No sales in this
range` with no explanation or recovery. The Profit report's five KPI cards wrapped 4 + 1,
orphaning one. The Labor report's `Service Sales 42` was labelled like money and read like a
count. Price changes was a 25-row wall with a near-empty `Δ` column and a stray `ΔReason`
header.

Now: the lead metric takes amber rather than black, the shared segmented date control scopes
all four reports identically, index cards carry live figures, every KPI has a note that frames
it (`51.4% of sales`, not a bare number), margin is a column, and the empty states explain and
offer a way out.

## The rule these screens broke three times

**Every figure derives from one scoped set.**

Sales showed `Gross sales ₱10,710.00` while Profit — same label, same range — showed
`₱38,325.00`, because one summed a fixture and the other used literals lifted from a
screenshot. On the index that produced a profit figure larger than the gross sales figure
above it. After that was fixed, Price changes still ignored the range control entirely,
claiming 18 changes "today" with every row dated the day before.

Fix, and the shape to build against: **one line-level fixture, everything derived.**

```
SALES: [{ no, day, paid, mechanic, labor, lines: [{ name, qty, price, cost }] }]

parts  = Σ qty × price      gross  = parts + labor
cogs   = Σ qty × cost       profit = gross − cogs
```

Product tables roll up from those lines; the payment split sums the same sale totals; the
labor breakdown groups the same sales; price changes filter on a `day` key against the same
range. Assert in tests: the profit table's revenue sums to parts, its cost column to COGS,
`gross − cogs === profit`, the payment split sums to gross, and every figure moves when the
range moves.

## Four other things to get right

- **The server computes report totals.** A report is a historical statement; the client must
  not re-derive gross from one page of rows. All five endpoints must agree —
  ideally they share one query layer so they *cannot* disagree.
- **COGS uses the cost recorded at the time of sale**, captured on the sale line. Using the
  product's current cost makes every historical margin move whenever stock is received.
- **Dates cross the wire as `YYYY-MM-DD`**, `to` inclusive through 23:59:59 in `Asia/Manila`.
  A client `toISOString()` shifts the boundary and silently drops a day.
- **Payment colors are mapped once:** Cash `--accent`, Gcash `--info`, Maya `--pos`, Salmon
  `--neg`. Same four tones wherever a payment split appears.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- **Should Reports show net profit after expenses?** Expenses are recorded but never
  subtracted anywhere in the product, so "profit" here is gross margin only. Probably the most
  valuable figure missing from the app.
- `Salmon` appears as a payment method with zero in every range, and `Shop fees` is always
  `₱0.00`. Live, typos, or dead?
- On price changes, does a **rise** read as positive (better margin) or negative (costs the
  customer more)? The reference treats a rise as red.
- What margin percentage counts as too thin? Coloring breaks at 50% and 25%.
- Are report figures VAT-inclusive? Still unanswered from the POS receipt question.
