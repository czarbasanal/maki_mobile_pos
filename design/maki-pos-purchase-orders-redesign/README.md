# MAKI MOTOR PARTS — Purchase Orders Redesign Handoff

Everything Claude Code needs to build the redesigned Purchase Orders list and the new
purchase order builder.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **Both screens here are assembled
from them** — `AppShell`, `Card`, `TableViews`, `FilterBar`, `SearchInput`,
`SegmentedFilter`, `DataTable`, `Badge`, `CopyButton`, `Button`, `Toast`, `EmptyState`,
`Skeleton`.

If you catch yourself writing a `<table>`, a chip row, a status pill, a checkbox or a
dropdown inside this feature's files, stop and use the shared one. Copy-pasted table CSS is
how the old admin ended up with five different table styles.

Two things the library is missing, listed in §D of the guide. Add them **to the library**,
not to this screen:
- `DataTable` row selection (checkbox column + header all/none)
- `StickyActionBar` (summary left, actions right)

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Purchase Orders - Implementation Guide.md** — both screens: what changed and why, the
   suggested-quantity formula, columns, endpoints, and the open questions.

## Reference implementation

**Purchase Orders.dc.html** — opens directly in a browser (no build step) and needs
`support.js` beside it. Open it at 1400px or wider.

Views in the one file:
- **List** — the default on load. Switch between Pending / Completed / Cancelled.
- **Empty states** — the Completed and Cancelled tabs are empty by design, so their states
  are visible immediately. `showEmptyState: true` empties all three.
- **Builder** — `+ New purchase order`, or click any row. "Back to purchase orders" returns.
  Try: move the Movement window or Cover controls, type over a Qty (the border goes amber and
  a reset arrow appears), uncheck a line, and watch the sticky bar total.

Read exact values off the file; do not port the markup — rebuild from the component library.

## What this redesign fixes

The old list was three tabs reading `0`, `0`, `0` above a single line of grey text, with a
pure-black `+ New Purchase Order` button — the only black element in the product. No table
existed, so no columns had been decided.

Now: a real table keyed on **Trip** (how a buyer actually recalls an order), per-view empty
copy that explains what will land there, and a builder that starts from what the shelf needs
— sold-in-window scaled to a cover period, minus what's on hand — instead of a blank form.

## Four things to get right

- **A PO reserves nothing and moves no stock.** It is a plan. Stock moves in Receiving.
- **Store `windowDays` and `coverDays` on the order.** Six weeks later, "why did we buy 40 of
  these" is only answerable if the assumptions were recorded.
- **Overridden quantities must look overridden** — amber border plus a reset control.
  Otherwise the buyer can't tell their edits from the system's suggestions.
- **Table overflow.** Nine columns, `min-width: 1080px` inside the `DataTable` scroller. A
  card with `overflow:hidden` clips columns with no scrollbar.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- Does a purchase order represent a **buying trip** (several suppliers, supplier recorded per
  line) or one supplier per order? The entire list design turns on this. The reference assumes
  a trip.
- What default cover period? 14 days is a guess; a shop that buys weekly wants 7.
- When the movement window or cover changes, should manual qty overrides survive? The
  reference discards them.
- Does receiving against a PO complete it automatically? Does a short delivery leave it
  pending?
- Should the builder surface parts that are out of stock but have **never** sold? Demand-based
  suggestion hides them completely.
