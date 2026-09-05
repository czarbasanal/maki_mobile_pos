# MAKI MOTOR PARTS — Stock Adjustment Modal Handoff

The stock adjustment form, reskinned and rebuilt around a live preview of the resulting
quantity.

## ⚠ Build on the shared `Modal`

This is the `sm` (452px) size of the shared `Modal` shell defined in `Dashboard - Spec.md`
§7 — the same shell the Product and Supplier modals use. If it doesn't exist yet, add it to
the library first. Everything inside is already there: `Button`, chips, inputs, `Toast`.

Don't write a fourth modal shell. Three screens already need this one.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Stock Adjustment Modal - Implementation Guide.md** — anatomy, arithmetic, validation
   rules, endpoints, and the open questions.

## Reference implementation

**Inventory.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Click any product row, then **Adjust stock**.

Try these:
- Type a quantity — the preview strip updates `On hand → New quantity` with a signed delta.
- Switch to **Remove** and enter more than is on hand — the field goes red and an inline line
  explains why, before you can submit.
- Switch to **Set to** — the field relabels to `Counted quantity`.
- Pick **Count correction**, **Damaged** or **Lost** — the note becomes required and its
  border marks it before you press Apply.
- **Escape** — closes this modal first, the product modal on a second press.

Read exact values off the file; do not port the markup — build it from the library.

## What this redesign fixes

The original recorded what you typed but never showed what would happen: a mode dropdown, a
quantity box, a reason dropdown, a note — and no sight of the resulting on-hand figure. The
user is standing at a shelf reconciling a physical count, so the resulting number is the whole
point.

Now: a preview strip above the inputs, Add / Remove / Set to as three visible chips, a stepper
on the quantity, reason as required chips, and negative results blocked at the input rather
than on submit.

## Four things to get right

- **Send mode and quantity, not the computed result.** `set` and `add` are different business
  events even when they land on the same number, and the log must say which happened.
- **Guard the race with `expectedOnHand`.** Between opening the modal and pressing Apply the
  register may have sold three. A 409 should reopen with the fresh figure and the user's
  quantity intact — silently applying a delta to a changed base is exactly how physical and
  system counts drift apart.
- **Adjustments are append-only.** Never overwrite `products.stock` on its own; on-hand is the
  sum of its movements. This is what keeps Receiving, sales and adjustments reconcilable.
- **Reset state on every open.** A remembered quantity from the last adjustment is how a stray
  `Enter` writes the wrong number to the wrong part.

Also: each adjustment must bump the product's `updatedAt` / `updatedBy` so Record history in
the product modal stays truthful — and as everywhere in this app, never put a CSS `transition`
on `background` when the value comes from a `var()`.

## Open questions for the client

- Is the reason list right — Delivery, Count correction, Damaged, Lost, Returned, Transfer?
  Is `Transfer` real yet, given there appears to be one branch?
- Should large write-offs need manager approval, and above what threshold? A single clerk can
  currently write off any quantity unchecked.
- Is `Set to` available to everyone, or admins only? It can erase a discrepancy without
  recording what the discrepancy was.
- Can stock be adjusted on a deactivated product?
