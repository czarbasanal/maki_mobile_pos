# MAKI MOTOR PARTS — Suppliers Redesign Handoff

Everything Claude Code needs to build the redesigned Suppliers directory.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. This screen is assembled from them —
`AppShell`, `Card`, `TableViews`, `FilterBar`, `SearchInput`, `SelectFilter`, `DataTable`,
`Badge`, `CopyButton`, `Button`, `Toast`, `EmptyState`, `Skeleton`.

If you catch yourself writing a `<table>`, a chip row, a status pill or a dropdown inside
this feature's files, stop and use the shared one. Copy-pasted table CSS is how the old admin
ended up with five different table styles.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Suppliers - Implementation Guide.md** — this screen: what changed and why, layout, the
   table, endpoints, and the open questions.

## Reference implementation

**Suppliers.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider.

States to look at:
- **Active** — the default view.
- **Inactive** / **Never received** / **All** — the chips, or the clickable rows in the
  Directory card. Both routes filter to the same set.
- **Terms filter** — the dropdown; closes on outside click and `Escape`.
- **No matches** — search something absent.
- **Empty (first run)** — `showEmptyState: true`, or empty the `SUPPLIERS` array. In
  production the condition is `totalCount === 0` from the server, *not* `rows.length === 0`
  after filtering.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the component library.

## What this redesign fixes

The old screen left ~350px of white between the header and the search field, pushed the first
row halfway down the page, and spent two columns on data that said nothing: a Status column of
fourteen identical green `Active` pills, and an Inventory column reading `0` / `₱0.00` on
eleven of fourteen rows. An Actions column duplicated the row click, and `+ Add supplier` was
a pure-black pill — the only black element in the product.

Now: a summary band that answers who you buy from and whose details are missing, status as a
saved-view filter, and **Parts** / **Last received** / **Spend 90d** in place of the dead
inventory value. Phone numbers are surfaced and copyable. Names, contacts, places and terms
are verbatim.

## Three things to get right

- **A clickable stat must filter to exactly its own number.** The first build rendered
  `Never received` (3) as a filter whose handler showed all 14 suppliers, with no selected
  styling. Both the card rows and the chips now map through one `inView()` predicate. If a
  stat isn't a filter, render it as a plain `div` — identical markup for interactive and
  non-interactive rows is the bug.
- **Never hard-delete a supplier.** Historical receipts and POs reference it. Deactivate
  soft: hide from pickers, leave every past record intact.
- **Table overflow.** `min-width: 940px` inside the `DataTable` scroller — a card with
  `overflow:hidden` clips columns with no scrollbar.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- **Is `place` an address or a channel?** Six suppliers read `Mobile` in that field, which
  suggests it means "we only have a phone number". If so it should be split: an address field
  plus a `Mobile only` flag.
- Is there a payables side — outstanding balance and due dates on the 30/60-day accounts? If
  so it belongs on this screen and changes the stat cards entirely. Worth settling before the
  detail view is built.
- Multiple contacts per supplier? `Eleavel/Wilson` and `RF/Geraldine` are two people in one
  field.
- Should `Spend 90d` count completed receipts only, or include pending POs as committed
  spend? The reference uses completed only.
- Do payment terms ever vary per part or per order, or is it one setting per supplier?
