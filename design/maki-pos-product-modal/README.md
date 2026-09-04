# MAKI MOTOR PARTS — Product Modal Handoff

The add-product form, redesigned and extended to serve edit mode as well.

## ⚠ One component, two modes — built on the shared library

`Dashboard - Spec.md` §7 defines the shared components. This is a single `ProductModal` with
`mode: 'add' | 'edit'` — **do not build two forms**, they drift within a sprint.

It sits on the shared `Modal` shell. If that shell doesn't exist yet, **add it to §7 first**
(the Edit Supplier Modal handoff specifies it) — Add supplier, Adjust stock, Void reason and
the POS tender step all need the same one. Everything inside the modal already exists in the
library: `Button`, inputs, `SelectFilter`, `Toast`.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Product Modal - Implementation Guide.md** — this component: the layout and its grid
   rules, auto-SKU behavior, the Adjust stock flow, the danger zone lifecycle, validation,
   endpoints, open questions.

## Reference implementation

**Inventory.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider.

- **Add mode** — `+ Add product`. Auto SKU is on: pick a category and a real SKU appears
  (`SOC-0004`); untick `Auto` to type your own. No Adjust stock, no Danger zone.
- **Edit mode** — click any product row. Title, CTA and the `On hand` label change, `Adjust
  stock` appears, and the Danger zone renders at the bottom of the body.
- **Live margin** — type in Cost and Price; the tile recomputes and recolors.
- **Record history** — who created the part and who last touched it, with timestamps, sitting
  above the Danger zone.
- **Danger zone** — `Delete` is inert until you press `Deactivate`; the row copy explains why
  rather than a tooltip. Deactivate is reversible.
- **Escape** — closes an open dropdown on the first press, the modal on the second.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — build the shared component.

## Layout — the one rule that matters

```
IDENTITY        [photo]  Part name ..........................
                         [ SKU ☐Auto ]  [ Barcode ]

PRICING         [ Cost ]     [ Price ]          [ MARGIN   85% ]

STOCK & CLASS.  [ On hand ]  [ Reorder level ]  [ Adjust stock ]
                [ Unit ]     [ Category ]       [ Supplier ]

NOTES           [ ................................................ ]

RECORD HISTORY  [ Created by ]  [ Last updated by ]   (edit mode only)

DANGER ZONE     deactivate / delete                   (edit mode only)
```

Pricing, the stock row and the classification row all share **one** grid rule —
`repeat(auto-fit, minmax(170px, 1fr))`, `gap: 12px`, `align-items: end`. Twelve controls
therefore align on three shared vertical edges down the whole modal. Do not give any row its
own column widths; that shared alignment is what replaced the original's ragged five-card
stack.

Four placement decisions the guide explains in full, each fixing something the earlier passes
got wrong:

- **Photo slot is vertically centred** against the name + SKU/barcode block, not top-aligned
  to the name.
- **`Adjust stock` is the third grid cell** at `width: 100%`, not an inline button inside the
  On hand field — inline squeezed the quantity input to about 90px.
- **Margin label and value sit on one line**, label left, value right. Stacked, the tile grew
  taller than the inputs beside it and broke the row.
- **`Auto` sits immediately after the `SKU` label.** Pushed to the column edge it landed
  190px from `SKU` and 12px from `Barcode`, so it read as a barcode control.

Also: **chips are for two to five options, a dropdown past that.** Unit was briefly a chip
row; with the real ten-unit list it wrapped to two lines and outweighed the price. Worth
holding that threshold app-wide.

## Record history

Edit mode only, between Notes and the Danger zone, on the same three-column grid. Two entries,
each stacking a label, the person, and the timestamp:

| Created by | Last updated by |
|---|---|
| Czar · Mar 14, 2026 · 9:42 AM | Bern · Sep 1, 2026 · 4:18 PM |

**Person and timestamp are one entry, not two fields.** Four separate cells (created by /
created at / updated by / updated at) fill the row with labels and read as a form; pairing
them halves the label count and matches how the fact is spoken — *Bern updated it on Sep 1.*

Placement is deliberate: last thing before the destructive actions, so anyone scrolling to
delete a part passes "Bern touched this five days ago" on the way. Plain text, never inputs.

Three rules for the data:

- **Audit fields come from the session, server-side.** A client-supplied `updatedBy` is a
  forgeable audit trail.
- **Carry `updatedVia`** (`ui` / `csv_import` / `bulk_price_update` / `api`) so the panel can
  say `CSV import` instead of naming a person who didn't do it. Null `updatedBy` shows `—`,
  not a repeat of the creator.
- **Deactivation, reactivation, deletion and stock adjustments all bump `updatedAt`/
  `updatedBy`.** Otherwise a part can be deactivated today and still claim it was last touched
  months ago.

Timestamps are absolute, in `Asia/Manila`, `MMM D, YYYY · h:mm A` — "3 days ago" is useless
when reconciling against a paper invoice dated the 1st.

This panel is a **summary**, not the audit trail. The full per-field history belongs in
Activity Logs; add a `View full history →` link filtered to the SKU once that screen exists.

## Stock only moves through a recorded movement

In add mode the field is `Initial quantity` and freely editable. In edit mode it becomes
`On hand`, renders **`readOnly`**, and `Adjust stock` sits beside it.

Typing over a live stock figure is how inventory silently stops matching the shelf — no record
of who changed 78 to 40, or why, while stock value, margin and reorder suggestions all move
with it.

`Adjust stock` opens its own modal: current quantity, a direction (`Add` / `Remove` / `Set
to`), the amount, a **required reason**, and the resulting quantity shown live before
confirming. Each adjustment writes `{ sku, delta, before, after, reason, note, userId,
createdAt }`. Adjustments are never edited or deleted, only superseded.

**`PATCH /api/products/{sku}` must reject an `onHand` field outright.** The only paths that
move stock are receiving, selling, and an adjustment.

## Product lifecycle — implement exactly this

Both destructive actions live in a **Danger zone** at the bottom of the modal body, after
Notes, in a `--neg`-outlined box. Never in the footer beside Cancel and Save — a destructive
button adjacent to the primary gets hit by muscle memory.

1. **Deactivate first, delete second.** `Delete` is inert and `cursor: not-allowed` while the
   product is active. Enforce **server-side too** — a client-side guard is not a rule. `DELETE`
   on an active product returns `409 must_deactivate_first`.
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

## Two other things to get right

- **Never style a field as disabled without disabling it.** The auto-SKU input was greyed but
  still editable, and typed text rendered `--text-3` on `--surface-3` — about 2.3:1. Both it
  and the read-only `On hand` are now `readOnly` with text at `--text`. Lock it or don't grey
  it; never both halves of the illusion.
- **A checkbox that promises generation must generate.** Auto SKU writes
  `<3-letter prefix>-<sequence>` when a category is picked. Server-side that sequence must be
  allocated atomically — two clerks adding a `SOCKETS` part at once must not both get
  `SOC-0004`.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- Are variants (`SELLING OPTIONS` in the original — an empty card with a `+ Add option`
  button and no defined behavior, so it was dropped) real? Per-variant SKU, price and stock is
  a different modal.
- Which adjustment reasons does the shop actually use? Our list is a guess, and a wrong list
  means everything lands under `Other`, which makes the audit trail useless.
- Should an adjustment need manager approval past a certain quantity or value?
- Can a product with stock on hand be deactivated? Warn, block, or allow? Deactivating a part
  you still physically own hides inventory value from every report.
- Is `reorderPoint` per-part, as this modal assumes, or one global threshold?
- Who may delete — admins only, or anyone who can edit? The reference doesn't gate it.
- Should cashiers see Record history, or admins only? It names staff, which is a mild
  people-data question even in a small shop.
