# MAKI MOTOR PARTS — Inventory Redesign Handoff

Everything Claude Code needs to build the redesigned Inventory screen.

## Read in this order

1. **Dashboard - Spec.md** — the skin. Fonts, type scale, both color palettes, geometry,
   theme rules, and the shared component library (§7). Start here; the guide assumes it.
2. **Inventory - Implementation Guide.md** — this screen: what changed and why, layout,
   the table and its columns, both empty states, endpoints, open questions.

## Reference implementation

**Inventory.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider; the table has an inner horizontal scroller below that.

Two states in the one file:
- **With products** — the default on load.
- **Empty (first run)** — behind a `showEmptyState` prop; set it `true`, or make the
  `PRODUCTS` array empty in the logic class. In production the condition is
  `totalCount === 0` from the server, *not* `rows.length === 0` after filtering — filtered-
  to-nothing is a separate, also-implemented state.

Read exact values off the file; do not port the markup — rebuild from the component library.

## What this redesign fixes

The old screen used six summary cards stacked in two bands with the filter row between them,
pushing the first product row off the bottom of a laptop screen. The three stock-status cards
are now one "Stock health" card with a segmented bar, the money cards join the same row, the
status counts became working filters, and Margin is now a column. Full rationale in §1 of the
guide.

## Three bugs the guide calls out — do not re-introduce

- **Table overflow.** A card with `overflow:hidden` clips columns with no scrollbar. Every
  table needs an inner `overflow-x:auto` scroller plus a `min-width`. Bake it into
  `DataTable`.
- **Theme transitions.** Never put a CSS `transition` on `background` when the value comes
  from a `var()` — the old color gets pinned when the custom property flips.
- **Dropdown dismissal.** A custom select must close on outside `mousedown` and `Escape`,
  with both listeners removed on unmount.

## Open questions for the client

- Are reorder points per-part today, or one global threshold? (The reference assumes 10 for
  every SKU, which is certainly wrong.)
- Should Stock Cost / Retail Value / Expected Profit respect the active filters, or stay
  whole-catalog totals?
- What margin percentage counts as too thin? Coloring currently breaks at 50% and 25%.
- Is there more than one branch? Every stock figure here is implicitly single-branch.
