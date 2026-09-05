# MAKI MOTOR PARTS — New Receiving Handoff

The **New receiving** builder — the screen missing from the earlier Receiving reskin. The list
and detail views are covered by that handoff; this one is only the builder.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **This screen is assembled from
them** — `AppShell`, `Card`, `SearchInput`, `SelectFilter`, `DataTable`, `Badge`, `Button`,
`StickyActionBar`, `Toast`, `EmptyState`.

The `StickyActionBar` is the one specified in the Purchase Orders handoff — summary figures
left, actions right. Same component, same furniture. If it isn't in the library yet, add it
there rather than writing it into this screen.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **New Receiving - Implementation Guide.md** — what changed and why, layout, the line
   table, the receive transaction, open questions.

## Reference implementation

**Receiving.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Press **`+ New receiving`** on the list.

Try these:
- **Type in the search** (`brake`, `spark`, `0027`) → live results with on-hand and last cost.
- **Add the same part twice** → the result action changes from `Add` to `+1` and the line
  increments rather than duplicating.
- **Watch the line** → `34 on hand → 50` updates as you change qty.
- **Edit a cost or price** → the border goes amber, because a changed cost is a price event
  that propagates across the app.
- **Search nonsense** → the dropdown offers `+ Create it as a new product`, which is where you
  actually discover a part doesn't exist.
- **Empty state** → the table header stays hidden until there's a line.
- **Sticky footer** → Lines / Units in / Retail value on the left, Total cost and the actions
  on the right; `Receive into stock` is dimmed until something is on the receipt.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the library.

## What this redesign fixes

The original was a form that recorded keystrokes rather than a counting tool: a native
`<select>` for supplier, `+ New product` given more prominence than the search field, and a
table header rendered above `No items yet.` with no rows, no inputs and no way in. `Receive`
was a grey disabled pill while `Save draft` was the outlined button — the primary action styled
as the least prominent thing on screen. No margin column, and nothing anywhere saying that
receiving moves stock and rewrites cost.

Now: a search-first add bar with live results seeded from last known cost, a line table with a
stepper and `on hand → new` per row, a margin column, and a sticky footer carrying Total cost
next to Retail value — so a mis-typed sell price is obvious before the receipt is committed.

## Four things to get right

- **Receiving is one transaction:** increment on hand, write a movement per line, update each
  product's cost, write a price-history row for every changed value, mark the receipt complete.
  A partial failure that moves some lines and not others is unrecoverable from the UI.
  Idempotency key per attempt — a double-tapped Receive must not double the stock.
- **Stock moves as append-only movements**, never by overwriting `products.stock`. Same rule as
  the Stock Adjustment modal; it is what keeps sales, receipts and adjustments reconcilable.
- **Allocate the reference server-side on create.** Two clerks starting a receipt at the same
  time must not both get `RCV-20260905-002`.
- **Persist the draft to `localStorage`.** A half-counted delivery lost to an accidental
  refresh has to be recounted from the boxes.

Also: `receivedOn` crosses the wire as `YYYY-MM-DD` — a client `toISOString()` files the
delivery on the wrong day west of UTC. And as everywhere in this app, never put a CSS
`transition` on `background` when the value comes from a `var()`.

## The question this screen turns on

**Does receiving set each product's cost to the new landed cost, or keep a moving average?**

Still unanswered from the Receiving handoff. It changes every margin figure in the app, and
this screen is where the write happens. The reference assumes *last cost wins* — simpler, and
common for a parts shop, but it overstates margin after a cheap batch.

## Biggest gap

**Receiving against a Purchase Order isn't built.** When a receipt comes from a PO the table
needs `qtyOrdered` beside `qtyReceived`, a short/over-delivery flag, and `Partial` should mean
*less than ordered* rather than *not fully counted*. The Purchase Orders handoff assumes this
link exists.

## Other open questions

- Should `Sell price` be editable here at all, or only in the product modal? Convenient during
  receiving, and also the easiest way to mis-price a part.
- Can a receipt be completed with no supplier? The reference allows it, and the list already
  shows one historical receipt with none.
- Should over-receiving against a PO be blocked, warned, or allowed?
- Who may receive — any staff member, or admins only?
