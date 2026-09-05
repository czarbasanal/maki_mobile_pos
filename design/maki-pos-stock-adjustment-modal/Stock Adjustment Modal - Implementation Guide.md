# Stock Adjustment Modal — Implementation Guide

Reference implementation: `Inventory.dc.html` — click any product row, then **Adjust stock**.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build on the shared `Modal`
> This is the `sm` size (452px) of the shared `Modal` shell — the same one the Product and
> Supplier modals use. If that shell doesn't exist yet, add it to §7 first. Everything inside
> it is already in the library: `Button`, chips, inputs, `Toast`.

---

## 1. What changed and why

The original was a full-height panel with a mode dropdown, a quantity field, a reason
dropdown and a note box — a form that recorded *what you typed* rather than showing *what
would happen*. The number the user actually cares about, the resulting on-hand quantity, was
never displayed. You typed 12 into a box labelled Quantity and hoped.

Five changes:

1. **A preview strip at the top**, before any input: `On hand → New quantity` with a signed
   delta chip. It updates as you type. This is the whole point of the modal — the user is
   reconciling a number against a physical shelf, so show them the number they will land on.
2. **Mode is three chips, not a dropdown.** Add / Remove / Set to. One tap, no popover, and
   all three options visible so the user learns "Set to" exists.
3. **Quantity gets a stepper.** `−` and `+` either side of a 16px mono field. Most
   adjustments are one or two units; typing is the slow path.
4. **Reason is chips too** — Delivery, Count correction, Damaged, Lost, Returned, Transfer —
   and it is **required**. An adjustment without a reason is an unexplained inventory change,
   which is the thing this record exists to prevent.
5. **Negative stock is blocked at the input**, not on submit: the field border goes `--neg`
   and an inline line reads *Removing 40 would leave −6. Stock cannot go negative.*

---

## 2. Anatomy

452px panel (`Modal` size `sm`), header / body / footer with only the body scrolling.

### Header
`Adjust stock` at 15px / 600, with the part on the line beneath at 11.5px `--text-3`:
`2PIN SOCKET BLACK · 00270002`. The SKU is there because two parts often share a name.

### Preview strip
`--surface-2` inset, `1px --border`, radius 11px, padding `12px 14px`:

```
ON HAND          →          NEW QUANTITY              [ +12 ]
78 pcs                      90 pcs
```

Both figures 19px mono / 600. `New quantity` shows `—` in `--text-3` until a quantity is
entered, and turns `--neg` when the result would be negative. Delta chip: `--pos-soft`/`--pos`
when positive, `--neg-soft`/`--neg` when negative, `--surface-3`/`--text-3` at zero or untouched.

### Movement
Three equal chips in a `repeat(3, 1fr)` grid. Selected takes `--accent-soft` fill with
`--accent-text` text and border — the same active-chip treatment as every filter in the app.

Arithmetic:

| Mode | New quantity |
|---|---|
| Add | `onHand + qty` |
| Remove | `onHand − qty` |
| Set to | `qty` |

**`Set to` relabels the field** to `Counted quantity`. It is the physical-count case, and
"Quantity" would read as an amount to move rather than the total on the shelf.

### Quantity
`−` / field / `+`, all 40px tall, with the unit (`pcs`, `set`, `L`) as static text to the
right. Input is digits-only (`replace(/[^0-9]/g, '')`) — sign comes from the mode, never from
a typed minus. `−` floors at 0.

### Reason
Wrapping chip row, required. Six values; confirm the list with the client.

### Note
Optional by default. **Required** for `Count correction`, `Damaged` and `Lost` — the three
reasons someone will question later. While required and empty, the border sits at
`--accent-line` and the label drops its `(optional)` suffix, so the requirement is visible
before submit rather than announced by an error.

### Footer
`--surface-2`, `Recorded against Czar · today` on the left — the adjustment is attributable
and the user should see that before committing. `Cancel`, then `Apply adjustment` (amber
primary, `opacity .45` until valid).

Validity: quantity entered, result ≥ 0, reason picked, note present if the reason demands it.

---

## 3. Behavior

- **`Escape` closes one layer at a time.** A dropdown inside the modal takes the first press,
  this modal the second, the product modal behind it the third. The reference keeps an
  explicit `else if` chain; the shared `Modal` should hold a small open-layer stack.
- **Scrim click closes**; `stopPropagation()` on the panel or every field click dismisses it.
- **Autofocus the quantity field** and select its contents — the user came here to type a
  number.
- `Enter` applies when valid.
- **On apply:** close both this modal and the product modal, toast `Stock adjusted` with
  `+12 → 90 pcs`, and patch the row in place.
- **Reset on open**, every time: mode `Add`, quantity empty, no reason, no note. A remembered
  quantity from the last adjustment is how a stray `Enter` writes the wrong number.

---

## 4. Data wiring

```
POST /api/products/{sku}/adjustments
{
  mode: 'add' | 'remove' | 'set',
  quantity: number,            // always positive; sign comes from mode
  reason: 'delivery' | 'count_correction' | 'damaged' | 'lost' | 'returned' | 'transfer',
  note: string | null,
  expectedOnHand: number,      // what the client displayed
  idempotencyKey: string
}
→ 200 { onHand, adjustment: { id, delta, createdAt, createdBy } }
→ 409 { error: 'stale_on_hand', currentOnHand }
→ 422 { error: 'negative_result' }
```

Four non-negotiables:

1. **Send the mode and quantity, not the computed result.** `set` and `add` are different
   business events even when they land on the same number, and the log must record which
   happened.
2. **`expectedOnHand` guards the race.** Between opening the modal and pressing Apply, the
   register may have sold three of these. A 409 means someone else moved the stock — reopen
   the modal with the fresh figure and the user's quantity intact, and say so. Silently
   applying a delta to a changed base is how physical and system counts drift apart.
3. **The server recomputes and re-validates.** A client-side negative-stock guard is a
   courtesy, not a rule.
4. **Idempotency key per attempt.** A double-tapped Apply must not adjust twice.

**Every adjustment is an append-only record.** Never overwrite `products.stock` alone —
on-hand is the sum of its movements. This is what makes Receiving, sales and adjustments
reconcilable, and it is what the Inventory guide means by "stock only moves through a recorded
movement".

Each adjustment writes to Activity Logs with user, timestamp, mode, delta, reason and note,
and bumps the product's `updatedAt` / `updatedBy` so Record history in the product modal
stays truthful.

---

## 5. Not built

Adjusting several SKUs in one pass (a stocktake session) · attaching a photo of damaged goods
· `Transfer` needs a destination branch once there is more than one · an adjustment history
list on the product · approval for large write-offs.

That last one is worth raising: a single clerk can currently write off any quantity with no
second pair of eyes.

---

## 6. Open questions

- Is the reason list right? Confirm the six, and whether `Transfer` is real yet.
- Should large adjustments need manager approval, and above what threshold?
- Is `Set to` allowed to anyone, or admins only? It can erase a discrepancy without recording
  what the discrepancy was.
- Can stock be adjusted for a deactivated product?

---

## 7. Definition of done

- Built on the shared `Modal` (`sm`), assembled from §7 components.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Preview strip updates live; negative results blocked at the input with inline copy.
- Reason required; note required for count correction, damage and loss.
- `Escape` closes one layer at a time; scrim click closes; focus trapped and restored.
- State resets on every open.
- Server re-validates, guards on `expectedOnHand`, and stores the adjustment as an
  append-only record.
