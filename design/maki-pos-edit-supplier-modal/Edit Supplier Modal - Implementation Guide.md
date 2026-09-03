# Edit Supplier Modal — Implementation Guide

Reference implementation: `Suppliers.dc.html` — click any row to open the modal.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build this as the shared `Modal`
> The admin has no modal primitive yet. **Add one to §7** rather than writing this markup
> into Suppliers — Add supplier, Add product, Void reason, Adjust receipt line and the POS
> tender step all need the same shell. Everything inside it (`Button`, `Badge`, inputs,
> segmented chips, `Toast`) already exists in the library.

---

## 1. Why a modal, not a page

The original was a full-page route: a page header, four separate cards stacked down the
viewport, a footer action bar — roughly 940px of scroll to edit six fields, most of them
empty. Editing a supplier is a small, reversible correction made *while looking at the list*,
usually because you noticed a missing phone number. Leaving the list, losing your filters and
scroll position, then returning, costs more than the edit does.

Four other problems fixed on the way:

1. **Fields spanned the full ~1580px width.** A supplier name is thirty characters. The
   `Name` and `Address` inputs were each wide enough for a paragraph.
2. **Four cards for six fields.** Each section (`CONTACT`, `TERMS`, `NOTES`) got its own
   surface with its own padding and shadow. The chrome outweighed the content. Sections are
   now label + fields on one surface.
3. **`Save changes` was a pure-black pill** — the only black element in the product. Now the
   standard amber primary.
4. **Payment terms was a native `<select>`.** Three options do not need a dropdown, and native
   select chrome can't be tokenized in either theme. Now three chips, one tap.

Every field and label is preserved: Name, Address, Contact person, Email, Contact number,
Alternative number, Payment terms, Internal notes, Deactivate supplier, Cancel, Save changes.

---

## 2. Shell — the shared `Modal`

```
scrim    position:fixed; inset:0; z-index:60; background:rgba(12,16,22,.36)
         display:flex; align-items:center; justify-content:center; padding:32px 24px
panel    width:100%; max-width:620px; max-height:100%
         display:flex; flex-direction:column          ← header/footer pin, body scrolls
         background:--surface; border:1px --border; radius:16px
         box-shadow:0 32px 72px -24px rgba(0,0,0,.45)
         overflow:hidden; animation:rise .2s ease
```

`max-height: 100%` with the flex column is what makes the body scroll while the header and
footer stay put. A modal that grows past the viewport and scrolls the whole panel hides its
own Save button.

`padding: 32px 24px` on the scrim doubles as the small-screen inset — no separate mobile rule.

**Contract for the shared component:** `<Modal open onClose title subtitle icon size footer>`
with `size: 'sm' | 'md' | 'lg'` → `480 / 620 / 820px`. It must own: scrim click to close,
`Escape` to close, focus trap, focus restored to the trigger on close, `aria-modal="true"`,
`role="dialog"`, and `overflow: hidden` on `<body>` while open.

`stopPropagation()` on the panel, or a click on any field closes the modal.

**Escape ordering matters.** When a dropdown inside the modal is open, `Escape` closes the
dropdown first and the modal on a second press — never both at once. The reference handles
this with an explicit `else if`; the shared component should keep a small open-layer stack.

---

## 3. Anatomy

### Header
34px initials tile in `--accent-soft` / `--accent-text`, then `Edit supplier` at 15px / 600
with a live subtitle beneath at 11.5px `--text-3`: `12 parts sourced · last received Aug 12,
2026`, or `No parts sourced yet`.

That subtitle is the one addition. The old page told you nothing about the supplier you were
editing — the same form for a shop you buy 41 parts from and one you have never bought from.

Close is a 28px `IconButton` in `--surface-2`, top right.

### Body
`padding: 18px 20px`, `gap: 18px`, `overflow-y: auto`.

Fields are `--surface-2` fill, `1px --border`, radius 10px, padding `10px 12px`, 13px text,
with a 11.5px / 600 `--text-2` label above. Phone and alternative number use IBM Plex Mono —
they are numbers to read back, not prose.

Pairs sit in `repeat(auto-fit, minmax(240px, 1fr))`, so the two-up grid collapses to one
column on narrow windows without a media query.

Section labels (`CONTACT`, `PAYMENT TERMS`) are 10px, 1px-tracked, uppercase, `--text-3`,
600 — no card, no border, just the label the section already had.

`TERMS` was retitled `PAYMENT TERMS` because the chips carry no other context now that the
card is gone.

### Payment terms chips
`Cash` · `30 Days` · `60 Days`, `8px 15px`, radius 10px. Selected takes `--accent-soft` fill
with `--accent-text` text and border — the same active-chip treatment as every filter in the
app, so "selected" reads identically everywhere.

If terms ever become an open list (per the Suppliers guide's open question), switch to the
shared `SelectFilter`. Three fixed options do not warrant it.

### Notes
`min-height: 74px`, `resize: vertical`, `line-height: 1.5`. The placeholder does real work:
*Anything the next buyer should know — who to ask for, delivery habits, price quirks.* An
empty box labelled "Internal notes" gets left empty.

### Footer
`--surface-2` fill, `1px --border` top. `Deactivate supplier` far left in `--neg`, hovering to
a `--neg-soft` fill. `Cancel` and `Save changes` right.

Destructive left, safe right, primary furthest right — the destructive action is the one you
must not hit by muscle memory.

`Save changes` sits at `opacity .45` while Name is empty and refuses the submit. Name is the
only required field.

---

## 4. Behavior

- **Draft state is separate from the row.** The modal edits a `draft` object seeded from the
  record on open; nothing mutates the list until Save. Cancel and `Escape` discard silently.
- **If the draft is dirty**, confirm before discarding on scrim click or `Escape`. Not in the
  reference — add it; losing typed notes to a stray click is the modal's characteristic
  failure.
- **Autofocus** the first field, or the field the user came to fix if you can infer it.
- `Enter` in any single-line field submits; `Enter` in the textarea inserts a newline. Wrap
  the body in a real `<form onSubmit>`.
- **Deactivate needs its own confirm step** — a second modal or an inline "Are you sure?" row.
  It is soft-only: hide the supplier from pickers, keep every historical receipt and PO intact.
  **Never hard-delete.**
- On save: close, toast `Supplier saved` with the name, and update the row in place without a
  full refetch.

---

## 5. Data wiring

```
PATCH /api/suppliers/{id}
{
  name: string,               // required
  address: string | null,
  contactName: string | null,
  email: string | null,
  phone: string | null,
  altPhone: string | null,
  terms: 'cash' | 'net30' | 'net60',
  notes: string | null
}
→ 200 { supplier }            // return the full record; patch the row from the response
→ 409 { error: 'duplicate_name' }
→ 422 { errors: { field: message } }
```

`POST /api/suppliers/{id}/deactivate` → `{ active: false }`. Soft only.

Field-level 422s render under their input in `--neg` at 11.5px, with the input border going
`--neg`. A 409 on the name is the likely real-world error — the shop has near-duplicate
supplier names already — so surface it on the Name field, not as a toast.

Every save and deactivation goes to Activity Logs with user, timestamp and the changed fields.

`Add supplier` is the same modal with an empty draft, titled `Add supplier`, without the
Deactivate action and with `Create supplier` as the primary. Build one component, two modes.

---

## 6. Open questions

- Is `Address` an address, or is it doing double duty as a channel? Six suppliers read
  `Mobile` in that field. If so, split it: address plus a `Mobile only` flag.
- Should `Alternative number` be a repeatable contact list? `Eleavel/Wilson` and
  `RF/Geraldine` are two people jammed into one Contact person field.
- Are internal notes visible to cashiers, or admin-only? The label says internal; the
  permission model doesn't say.

---

## 7. Definition of done

- Built as the shared `Modal` in §7, not inline in Suppliers.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Header and footer pinned; only the body scrolls; Save is always reachable.
- Closes on scrim click, `Escape` and Cancel; a nested dropdown consumes `Escape` first.
- Dirty draft confirms before discarding.
- Focus trapped while open, restored to the trigger on close; `role="dialog"`,
  `aria-modal="true"`; `<body>` scroll locked.
- Real `<form>`; `Enter` submits from single-line fields; Save disabled while Name is empty.
- Field-level validation errors render under their field, not as a toast.
- Deactivate confirms, and is soft-only.
