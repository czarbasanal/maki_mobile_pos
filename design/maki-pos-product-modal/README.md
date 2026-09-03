# MAKI MOTOR PARTS — Product Modal Handoff

The add-product form, redesigned and extended to serve edit mode as well.

## ⚠ One component, two modes — built on the shared library

`Dashboard - Spec.md` §7 defines the shared components. This is a single `ProductModal` with
`mode: 'add' | 'edit'` — **do not build two forms**, they drift within a sprint.

It sits on the shared `Modal` shell. If that shell doesn't exist yet, **add it to §7 first**
(the Edit Supplier Modal handoff specifies it) — Add supplier, Void reason, Adjust receipt
line and the POS tender step all need the same one. Everything inside the modal already
exists in the library: `Button`, inputs, chips, `SelectFilter`, `Toast`.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Product Modal - Implementation Guide.md** — this component: what changed and why, the
   layout, auto-SKU rules, the danger zone lifecycle, validation, endpoints, open questions.

## Reference implementation

**Inventory.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider.

- **Add mode** — `+ Add product`. Auto SKU is on: pick a category and a real SKU appears
  (`SOC-0004`); untick `Auto` to type your own.
- **Edit mode** — click any product row. Title, CTA and the `On hand` label all change, and
  the Danger zone appears at the bottom of the body.
- **Live margin** — type in Cost and Price; the third tile recomputes and recolors.
- **Danger zone** — `Delete` is inert until you press `Deactivate`; the row copy explains
  why rather than a tooltip. Deactivate is reversible.
- **Escape** — closes a category/supplier dropdown on the first press, the modal on the
  second.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — build the shared component.

## What this redesign fixes

The original was a ~365px column of five stacked cards — `IDENTITY`, `PRICING`,
`SELLING OPTIONS`, `STOCK & CLASSIFICATION`, `NOTES` — around fourteen fields, scrolling
roughly 780px. Each section's chrome cost more space than its fields, every input ran
full-width, Unit/Category/Supplier were native `<select>`s that can't be tokenized, and
`Auto-generate SKU` greyed the field without ever generating anything.

Now a 680px panel: sections are labels on one surface, fields pair up in an `auto-fit` grid,
Unit is chips, Category and Supplier use the shared `SelectFilter`, and **margin is a live
tile beside Cost and Price** — the number that decides whether the price is right was
previously left for the user to compute.

`SELLING OPTIONS` and its empty `+ Add option` button were dropped; it had no defined
behavior. If variants are real they need their own design — see the open questions.

## Product lifecycle — implement exactly this

Both destructive actions live in a **Danger zone** at the bottom of the modal body, right
after Notes, inside a `--neg`-outlined box. Never in the footer beside Cancel and Save — a
destructive button adjacent to the primary gets hit by muscle memory.

1. **Deactivate first, delete second.** `Delete` is inert, dimmed and `cursor: not-allowed`
   while the product is active. Enforce this **server-side too** — a client-side guard is not
   a rule. `DELETE` on an active product returns `409 must_deactivate_first`.
2. **Deactivation is reversible.** A deactivated product vanishes from POS search, the
   register catalog, purchase-order suggestions and receiving pickers; it stays visible in
   Inventory under `Archived`, and keeps its stock, cost, price and history.
3. **Deletion is soft. History always survives.**

   > Sales lines, job orders, receipts, purchase orders, price history, stock adjustments and
   > activity logs that reference a deleted product **remain intact and remain readable.**

   Set `deletedAt` and keep the row. Never `DELETE FROM products`. A past sale must still read
   `2PIN SOCKET BLACK · 00270002` five years from now — a cascading foreign key, or a nulled
   reference that makes an old receipt render `— · —`, is data loss, and in a shop with tax
   filings it is the kind that matters.
4. **Delete needs typed confirmation** — a second modal requiring the user to type the SKU.
   Not in the reference; build it.
5. **A deleted SKU stays reserved** so a new part can't inherit an old part's history, and
   **Restore exists** in an admin-only list. Don't build a delete you can't undo.
6. Every deactivation, reactivation, delete and restore writes to Activity Logs with the user,
   timestamp and previous state.

## Three other things to get right

- **Never style a field as disabled without disabling it.** The first build greyed the
  auto-SKU input but left it editable, and typed text rendered `--text-3` on `--surface-3` —
  about 2.3:1, well under 4.5:1. It is now `readOnly` while `Auto` is on, with text at
  `--text`. Lock it or don't grey it; never both halves of the illusion.
- **A checkbox that promises generation must generate.** Auto SKU now writes
  `<3-letter prefix>-<sequence>` when a category is picked. Server-side that sequence must be
  allocated atomically — two clerks adding a `SOCKETS` part at once must not both get
  `SOC-0004`.
- **`PATCH` must not silently move stock.** Editing `On hand` is a correction and should write
  a stock adjustment record (old value, new value, user, reason), not overwrite the number.
  Editing cost or price writes to Price History — that screen depends on it.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- Are variants (`SELLING OPTIONS` in the original) real? Per-variant SKU, price and stock is a
  different modal.
- Should `On hand` be editable here at all, or forced through Receiving and a stock adjustment?
- Can a product with stock on hand be deactivated? Warn, block, or allow? Deactivating a part
  you still physically own hides inventory value from every report.
- Is `reorderPoint` per-part, as this modal assumes, or one global threshold?
- Who may delete — admins only, or anyone who can edit? The reference doesn't gate it.
