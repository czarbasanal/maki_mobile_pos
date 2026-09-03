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
   680px panel with `auto-fit` pairs — two-up on desktop, one-up when narrow, no media query.
3. **Native `<select>` for Unit, Category and Supplier.** Unusable to token in either theme.
   Unit is now chips (five fixed options, one tap); Category and Supplier use the shared
   `SelectFilter`.
4. **Cost and Price sat side by side with no margin shown**, so the buyer had to compute the
   one number that decides whether the price is right. **Margin is now a live third tile.**
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
body     identity row   — 88px photo slot + name + SKU/barcode pair
         PRICING        — cost · price · live margin tile
         STOCK & CLASSIFICATION — qty · reorder · unit chips · category · supplier
         notes
         DANGER ZONE    — deactivate · delete   (edit mode only)
footer   ................................. Cancel · primary
```

### Header subtitle carries mode
- **Add:** `Set a cost and a price and the register handles the rest.`
- **Edit:** `00270002 · SOCKETS · 78 on hand` — the record's own facts.

Everything else that differs between modes:

| | Add | Edit |
|---|---|---|
| Title | New product | Edit product |
| Primary | Create product | Save changes |
| Qty label | Initial quantity | On hand |
| Danger zone | hidden | shown |
| SKU auto | on by default | off (SKU already exists) |

### Photo slot
88px square, radius 12px, `1px dashed --border`, hovering to `--accent-line`, with an image
glyph and `Add photo`. Dashed border is the affordance — it reads as a drop target rather
than an empty box. Swap for `<img style="object-fit:cover">` at the same dimensions once a
photo exists, so nothing reflows.

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
- Margin recomputes live and uses the app-wide thresholds.
- Both destructive actions sit in the Danger zone at the bottom of the body, `--neg`-outlined,
  never in the footer.
- `Delete` is inert and visibly gated until the product is deactivated — enforced on the
  server too, and explained in the row copy rather than a tooltip.
- Delete is soft: `deletedAt` set, row retained, every referencing document still renders its
  name and SKU. Restore exists.
- Delete requires typed SKU confirmation; a dirty draft confirms before discarding.
- Every lifecycle change writes to Activity Logs.
- Duplicate-SKU errors render on the field; `Escape` closes one layer at a time.
