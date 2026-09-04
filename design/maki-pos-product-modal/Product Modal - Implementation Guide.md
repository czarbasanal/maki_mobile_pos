# Product Modal (Add & Edit) — Implementation Guide

Reference implementation: `Inventory.dc.html` — `+ Add product` opens add mode, clicking any
row opens edit mode.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### One component, two modes
> This is a single `ProductModal` with `mode: 'add' | 'edit'`. Do not build two forms — they
> drift within a sprint. Build it on the shared `Modal` shell (see the Edit Supplier Modal
> guide; if that shell doesn't exist yet, **add it to §7** first). Everything inside —
> `Button`, inputs, chips, `SelectFilter`, `Toast` — already exists in the library.

---

## 1. What changed and why

The original was a ~365px-wide column: five stacked cards (`IDENTITY`, `PRICING`,
`SELLING OPTIONS`, `STOCK & CLASSIFICATION`, `NOTES`), each with its own surface, border and
padding, for about fourteen fields. It scrolled roughly 780px. Five problems:

1. **Five cards for one form.** Each section's chrome cost more vertical space than its
   fields. Sections are now labels on one surface.
2. **Single column at 365px** left every field full-width and the form endlessly tall. Now a
   680px panel on one shared three-column grid — see §2. Twelve controls align on three
   vertical edges.
3. **Native `<select>` for Unit, Category and Supplier.** Unusable to token in either theme.
   All three now use the shared `SelectFilter`, sitting as one three-column row.

   Unit was briefly a chip row. With the real unit list (`pcs set pair pack box liter ml kg g
   m`) ten chips wrapped to two lines and dominated the modal — more visual weight than the
   price. **Chips are for two to five options; past that, a dropdown.** That threshold is
   worth holding across the app.
4. **Cost and Price sat side by side with no margin shown**, so the buyer had to compute the
   one number that decides whether the price is right. **Margin is now a live third tile** on
   the same row, label and value inline.
5. **Auto-generate SKU was a checkbox that generated nothing** — it only greyed the field and
   changed a hint. It now writes a real value, and the field is `readOnly` while it is on.

`SELLING OPTIONS` with its `+ Add option` button was dropped — it was an empty card with no
defined behavior. If variants (size, color, pack) are real, they need their own design; ask
before rebuilding it.

---

## 2. Layout

680px panel, header/footer pinned, body scrolls (`max-height: 100%` + flex column).

```
header   34px box glyph tile · title · live subtitle · close

body     IDENTITY        ┌──────┐  Part name ......................
                         │photo │  ┌ SKU ☐Auto ─┐ ┌ Barcode ─────┐
                         └──────┘  └────────────┘ └──────────────┘

         PRICING         [ Cost ] [ Price ] [ MARGIN      85% ]

         STOCK & CLASS.  [ On hand ] [ Reorder level ] [ Adjust stock ]
                         [ Unit ]    [ Category ]      [ Supplier ]

         NOTES           [ ............................................ ]

         RECORD HISTORY  [ Created by Czar     ] [ Last updated by Bern ]
                         [ Mar 14, 2026 9:42AM ] [ Sep 1, 2026 4:18 PM  ]

         DANGER ZONE     ┌ deactivate ─────────────────────────────────┐
                         └ delete ─────────────────────────────────────┘
                                                        (edit mode only)

footer   ................................. Cancel · primary
```

### The grid is the whole layout

Three rows of three equal columns, all sharing one track definition:

```css
display: grid;
grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
gap: 12px;
align-items: end;      /* labels vary in height; controls must line up */
```

Pricing, the stock row and the classification row use the identical rule, so **twelve
controls line up on three shared vertical edges** down the whole modal. That single decision
is what took this from the original's ragged five-card stack to something scannable — do not
give any row its own column widths.

`align-items: end` matters: a two-word label wrapping to two lines would otherwise push its
input below its neighbours'.

`auto-fit` handles narrow windows without a media query — three columns become two, then one,
and the pairs stay paired.

### Identity row

`display: flex; gap: 14px; align-items: center`.

The 88px photo slot is **vertically centred against the whole right-hand block** (part name
above, SKU + barcode below), not top-aligned to the name. Top-aligning leaves the square
hanging off the top of a two-row group and reads as misalignment.

The right side is `flex: 1; min-width: 240px` so the slot and fields wrap to two rows rather
than crushing.

### Adjust stock is a grid cell, not an inline button

`Adjust stock` occupies the **third cell** of the stock row, at `width: 100%`, so it is exactly
as wide as On hand and Reorder level beside it and as Supplier below it. It is not tucked
inside the On hand field group.

Two reasons: it inherits the shared column edge, and it does not shrink the field it sits
next to. The first build put it inline with the input, which squeezed a mono quantity into
about 90px.

Hidden entirely in add mode — there is no stock to adjust yet, and the row falls back to two
columns.

### Record history

Edit mode only, between Notes and the Danger zone: a `--surface-2` panel on the **same
three-column grid rule** as every other row, with two entries.

Each entry stacks three lines — a 10px uppercase `--text-3` label, the person at 12.5px/500,
and the timestamp at 10.5px mono `--text-3`:

| Label | Who | When |
|---|---|---|
| Created by | `Czar` | `Mar 14, 2026 · 9:42 AM` |
| Last updated by | `Bern` | `Sep 1, 2026 · 4:18 PM` |

Person and timestamp are **one entry, not two fields.** Four separate cells (created by /
created at / updated by / updated at) fill a row with labels and read as a form; pairing them
halves the label count and matches how the fact is spoken — *Bern updated it on Sep 1.*

Placement is deliberate: last thing before the destructive actions. Someone scrolling to
delete a part passes "Bern touched this five days ago" on the way. It is context for the
decision, not a field to fill in — so it is plain text, never inputs, and it sits below every
editable control rather than in the header.

Timestamps render in the shop's timezone (`Asia/Manila`), format `MMM D, YYYY · h:mm A`.
Absolute, not relative — "3 days ago" is useless when reconciling against a paper invoice
dated the 1st.

If `updatedBy` is null (never edited since creation), show `—` in `--text-3` rather than
repeating the creator; and if the last edit was the system rather than a person (a CSV import,
a bulk price update), name it as such: `CSV import`, `Bulk price update`.

**This panel is a summary, not the audit trail.** It shows the two most recent facts; the full
per-field history lives in Activity Logs. Link to it — `View full history →` filtered to this
SKU — once that screen exists.

### Margin tile

Label and value on **one line**: `display: flex; align-items: center; gap: 10px`, `MARGIN` at
10px uppercase `--text-3` on the left, the percentage at 17px mono/600 pushed right with
`margin-left: auto`. Same 10px 12px padding and 10px radius as the inputs beside it, so it
reads as the third member of the pricing row rather than a card dropped into it.

Stacking the label above the value made the tile taller than the two inputs it sits with and
broke the row's baseline.

### Auto checkbox placement

`Auto` sits **immediately after the `SKU` label** — `display: flex; align-items: center;
gap: 9px`, no `margin-left: auto`.

Pushing it to the column's right edge (the first build) put it 190px from the `SKU` label and
12px from the `Barcode` label, so it read as a barcode control. A checkbox must be adjacent to
the thing it governs, and pinning it to a flexible edge means the gap grows with the column.

### Header subtitle carries mode
- **Add:** `Set a cost and a price and the register handles the rest.`
- **Edit:** `00270002 · SOCKETS · 78 on hand` — the record's own facts.

Everything else that differs between modes:

| | Add | Edit |
|---|---|---|
| Title | New product | Edit product |
| Primary | Create product | Save changes |
| Qty label | Initial quantity | On hand (read-only + Adjust stock) |
| Danger zone | hidden | shown |
| SKU auto | on by default | off (SKU already exists) |

### Photo slot
88px square, radius 12px, `1px dashed --border`, hovering to `--accent-line`, with an image
glyph and `Add photo`. Dashed border is the affordance — it reads as a drop target rather
than an empty box. Swap for `<img style="object-fit:cover">` at the same dimensions once a
photo exists, so nothing reflows.

### On hand is not typed — it is adjusted

In **add** mode the quantity field is `Initial quantity` and freely editable: it is the
opening count, and it creates the first stock movement.

In **edit** mode it becomes `On hand`, renders **`readOnly`** on a `--surface-3` fill, and an
**`Adjust stock`** button sits beside it. Typing over a live stock figure is how inventory
silently stops matching the shelf — there is no record of who changed 78 to 40 or why, and
every downstream figure (stock value, margin, reorder suggestion) moves with it.

`Adjust stock` opens its own small modal: current quantity, a direction (`Add` / `Remove` /
`Set to`), the amount, a **required reason** (`Recount`, `Damaged`, `Lost`, `Found`,
`Returned to supplier`, `Other` + free text), and the resulting new quantity shown live
before confirming. Not built in the reference — the button toasts.

Each adjustment writes a movement record: `{ sku, delta, before, after, reason, note, userId,
createdAt }`, and the Danger-zone rule about history applies here too — adjustments are never
edited or deleted, only superseded by another adjustment.

Because of this, `PATCH /api/products/{sku}` must **reject** an `onHand` field outright rather
than accepting it. The only paths that move stock are receiving, selling, and an adjustment.

### Live margin tile
Third item in the pricing grid, `--surface-2` fill: an uppercase `MARGIN` label and the
percentage at 17px mono/600. `(price − cost) / price`, colored `≥50%` `--pos`, `25–49%`
`--text-2`, `<25%` `--neg`, `—` in `--text-3` until a price exists. Same thresholds as the
Inventory table and the Receiving detail — keep them in one place.

### Auto SKU
`Auto` checkbox sits inline with the SKU label. While on: the field is **`readOnly`**, filled
`--surface-3`, cursor `default`, and picking a category writes `<3-letter prefix>-<sequence>`
(e.g. `SOC-0004`).

Two traps the first build hit, both worth stating because they are easy to reintroduce:
- **Styling a field as disabled without disabling it.** The greyed input still accepted
  typing, and the typed text rendered `--text-3` on `--surface-3` — about 2.3:1, well under
  4.5:1. Either lock it or don't grey it. Never both halves of the illusion.
- **A checkbox that promises generation and generates nothing.** If `Auto` is on, a value must
  appear. Server-side, that sequence has to be allocated atomically — two clerks adding a
  `SOCKETS` part at once must not both get `SOC-0004`.

Text on a `--surface-3` fill is always `--text`, never `--text-3`.

---

## 3. Danger zone — the two-step lifecycle

Both destructive actions live in a **Danger zone** at the bottom of the modal body, directly
after Notes — never in the footer beside Cancel and Save. A destructive button adjacent to the
primary action is hit by muscle memory; one that requires scrolling past every field is not.

Rendered only in edit mode. Structure:

```
DANGER ZONE                                  ← 10px uppercase label in --neg
┌──────────────────────────────────────────┐  ← 1px --neg outline, radius 12px
│ Deactivate this product      [Deactivate]│  ← --surface, neutral button
├──────────────────────────────────────────┤  ← 1px --neg divider
│ Delete this product              [Delete]│  ← --neg-soft fill, --neg title + button
└──────────────────────────────────────────┘
```

The outline and the label are `--neg`; only the delete row takes the `--neg-soft` fill. Two
rows escalate: deactivation is reversible and reads as ordinary maintenance, so its row keeps
the plain surface and a neutral-bordered button. Deletion is not, so its row is tinted.

Each row carries a one-line explanation of consequence, not a restatement of the button:

| Row | State | Copy |
|---|---|---|
| Deactivate | active | Stops it appearing at the register and in purchase orders. Nothing is lost, and you can turn it back on. |
| Deactivate | inactive | *(title: Product is deactivated)* Hidden from the register and from purchase orders. Stock, cost and history are untouched. |
| Delete | active | Deactivate it first — an active part cannot be deleted. |
| Delete | inactive | Removes it from the catalog for good. Past sales, receipts and job orders keep their record of it. |

The gating is legible in the copy itself, so the disabled button never needs a tooltip to
explain why it will not respond.

### Rules

1. **A product must be deactivated before it can be deleted.** While active, `Delete` renders
   at `--text-3` with a `--border` outline, `opacity .5` and `cursor: not-allowed`, and its
   row copy explains why. Clicking it does nothing but restate that. This is not a nicety —
   it is what prevents someone removing a part mid-shift because a button was adjacent.
2. **Deactivate is reversible** and the button becomes `Reactivate`. A deactivated product:
   - disappears from POS search and the register catalog,
   - disappears from purchase-order suggestions and receiving pickers,
   - stays visible in Inventory under the `Archived` view,
   - keeps its stock figure, cost, price and full history.
3. **Delete requires a typed confirmation.** A second modal: show the name and SKU, require
   the user to type the SKU, then confirm. Not in the reference — build it.
4. **Deleting never destroys history.** This is the important part:

   > Sales lines, job orders, receipts, purchase orders, price history, stock adjustments and
   > activity logs that reference a deleted product **remain intact and remain readable.**

   Which means the delete is a **soft delete on the product record**, not a row removal. Set
   `deletedAt` and keep the row. Historical documents keep pointing at it and continue to
   render the name and SKU they were written with. A past sale must still say
   `2PIN SOCKET BLACK · 00270002` five years later.

   Never `DELETE FROM products`. A foreign key that cascades, or a nulled reference that makes
   an old receipt read `— · —`, is data loss, and in a shop with tax filings it is the kind
   that matters.

5. **A deleted product is not reusable.** Its SKU stays reserved so a new part can't inherit
   an old part's history. If the user wants the SKU back, they restore the product rather than
   creating a duplicate.
6. **Restore exists.** Deleted products live in an admin-only list (Settings, or an
   `Archived` → `Deleted` sub-view) with a `Restore` action. Do not build a delete you cannot
   undo.
7. Every deactivation, reactivation, delete and restore writes to Activity Logs with the user,
   the timestamp and the previous state.

### Guard on stock
Ask the client: should a product with stock on hand be deactivatable at all? The reference
allows it. The safer behavior is to warn — *78 on hand will stop appearing at the register* —
and require confirmation, since deactivating a part you still physically own hides inventory
value from every report.

---

## 4. Validation and behavior

- **Required:** name, and a price above zero. Save sits at `opacity .45` and refuses until
  both exist. Cost may legitimately be zero (a giveaway or a warranty part).
- **Draft state is separate from the record.** The modal edits a `draft` seeded on open;
  nothing mutates the row until Save. Cancel and `Escape` discard.
- **If the draft is dirty**, confirm before discarding on scrim click or `Escape`. Not in the
  reference — add it.
- **Escape closes one layer at a time.** A category or supplier dropdown inside the modal
  consumes the first press; the modal takes the second.
- **Autofocus** the name field in add mode; in edit mode, focus nothing (the user came to
  change one specific thing, not to retype the name).
- Duplicate SKU returns 409 and renders **on the SKU field**, not as a toast.
- `Enter` submits from single-line fields; `Enter` in the textarea inserts a newline. Use a
  real `<form onSubmit>`.

---

## 5. Data wiring

### Create / update
```
POST  /api/products
PATCH /api/products/{sku}
{
  name: string,                  // required
  sku: string,                   // required; server allocates when autoSku is true
  autoSku: boolean,
  barcode: string | null,
  cost: number,                  // centavos
  price: number,                 // centavos, required, > 0
  initialQty: number,            // create only
  reorderPoint: number,
  unit: 'pcs' | 'set' | 'pair' | 'liter' | 'box',
  category: string | null,
  preferredSupplierId: string | null,
  imageUrl: string | null,
  notes: string | null
}
→ 200 { product }                // return the full record; patch the row from the response
→ 409 { error: 'duplicate_sku' | 'duplicate_barcode' }
→ 422 { errors: { field: message } }
```

The product record carries its own audit fields, returned on every read:

```ts
{
  createdBy:  { id, name } | null,   // null → system-created (import, seed)
  createdAt:  string,                // ISO
  updatedBy:  { id, name } | null,   // null → never edited since creation
  updatedAt:  string | null,
  updatedVia: 'ui' | 'csv_import' | 'bulk_price_update' | 'api' | null
}
```

Set these **server-side from the session**, never from the client payload — a client-supplied
`updatedBy` is a forgeable audit trail. `updatedVia` is what lets the panel say `CSV import`
instead of naming a person who did not do it.

Deactivation, reactivation, deletion and stock adjustments each bump `updatedAt` / `updatedBy`
as well as writing their own log entry — otherwise a part can be deactivated and still claim
it was last touched months ago.

**`PATCH` must not silently move stock.** Editing `On hand` in this modal is a correction, and
it should write a **stock adjustment record** (old value, new value, user, reason) rather than
overwriting the number. Consider requiring a reason when it changes. Confirm with the client.

Editing `cost` writes to price history; so does editing `price`. The Price History screen
depends on it.

### Lifecycle
```
POST /api/products/{sku}/deactivate   → { active: false }
POST /api/products/{sku}/reactivate   → { active: true }
DELETE /api/products/{sku}            → 409 { error: 'must_deactivate_first' } while active
                                      → 200 { deletedAt }  (soft; row retained)
POST /api/products/{sku}/restore      → { deletedAt: null }
```

Enforce the deactivate-first rule **server-side as well as in the UI**. A client-side-only
guard is not a rule.

`GET /api/products` excludes `deletedAt != null` by default; historical document endpoints
must still resolve them.

---

## 6. Open questions

- Are variants (`SELLING OPTIONS` in the original) real? If so they need their own design —
  per-variant SKU, price and stock — and the modal grows a variants table.
- Should editing `On hand` here be allowed at all, or forced through Receiving and a stock
  adjustment?
- Can a product with stock on hand be deactivated? Warn, block, or allow?
- Is `reorderPoint` per-part (as this modal assumes) or one global threshold?
- Who may delete — admins only, or any user who can edit? The reference doesn't gate it.

---

## 7. Definition of done

- One `ProductModal` with an `add`/`edit` mode, on the shared `Modal` shell from §7.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Header and footer pinned; only the body scrolls; the primary is always reachable.
- Auto SKU writes a real value and the field is `readOnly` while on; text on any filled input
  stays `--text`.
- `On hand` is read-only in edit mode with an `Adjust stock` button; `PATCH` rejects `onHand`;
  every adjustment carries a reason and writes a movement record.
- Margin recomputes live and uses the app-wide thresholds.
- Record history renders above the Danger zone in edit mode, as plain text on the shared grid
  — never as inputs; audit fields come from the session server-side.
- Both destructive actions sit in the Danger zone at the bottom of the body, `--neg`-outlined,
  never in the footer.
- `Delete` is inert and visibly gated until the product is deactivated — enforced on the
  server too, and explained in the row copy rather than a tooltip.
- Delete is soft: `deletedAt` set, row retained, every referencing document still renders its
  name and SKU. Restore exists.
- Delete requires typed SKU confirmation; a dirty draft confirms before discarding.
- Every lifecycle change writes to Activity Logs.
- Duplicate-SKU errors render on the field; `Escape` closes one layer at a time.
