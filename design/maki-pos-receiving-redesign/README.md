# MAKI MOTOR PARTS — Receiving Redesign Handoff

Everything Claude Code needs to build the redesigned Receiving list and detail views.

## Read in this order

1. **Dashboard - Spec.md** — the skin. Fonts, type scale, both color palettes, geometry,
   theme rules, and the shared component library (§7). Start here; the guide assumes it.
2. **Receiving - Implementation Guide.md** — both views: what changed and why, layout, the
   table, the detail facts strip, endpoints, and the open questions.

## Reference implementation

**Receiving.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider; the table has an inner horizontal scroller below that.

Three views in the one file:
- **List** — the default on load.
- **Detail** — click any row; the filled "Back to receiving" button above the card returns.
- **Empty (first run)** — behind a `showEmptyState` prop; set it `true`, or empty the
  `RECEIPTS` array. In production the condition is `totalCount === 0` from the server, *not*
  `rows.length === 0` after filtering — filtered-to-nothing is a separate, also-implemented
  state.

Read exact values off the file; do not port the markup — rebuild from the component library.

## What this redesign fixes

The old list gave its first 350px to three cards holding three small numbers, then showed
three rows with no search, filters or pagination and half a screen of white below. The old
detail buried supplier, timestamp and recorder in one dim subtitle line and floated a small
totals card in the middle of the page.

Now: a September pipeline card whose rows filter the table, two money cards that surface
partially-counted stock, a full table with saved views and filters, a facts strip on the
detail, and a margin column on both. Copy is preserved. Full rationale in §A and §B of the
guide.

## Four things to get right

- **Every count derives from the same filtered set.** The first build had the summary card
  reading `Completed 3` (month-scoped) directly above a chip reading `Completed 4`
  (all-time), and a header that said `4 receipts` over rows summing to 5. Compute; never
  hard-code.
- **Completing a receipt is the write that moves stock.** It must be idempotent and
  transactional — a partial failure that moves some lines and not others cannot be recovered
  from the UI.
- **Table overflow.** A card with `overflow:hidden` clips columns with no scrollbar. Every
  table needs an inner `overflow-x:auto` scroller plus a `min-width`.
- **Theme transitions.** Never put a CSS `transition` on `background` when the value comes
  from a `var()` — the old color gets pinned when the custom property flips.

## Open questions for the client

- Does receiving set each product's cost to the new landed cost, or keep a moving average?
  This one changes every margin figure in the app.
- Do receipts originate from Purchase Orders? If so the detail needs ordered-vs-received per
  line, and `Partial` means "short delivery" rather than "not fully counted".
- Can a completed receipt be edited, or only corrected with an adjustment record?
- Is `Sell price` editable while receiving, or does it come from the product?
