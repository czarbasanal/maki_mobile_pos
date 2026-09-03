# MAKI MOTOR PARTS — Edit Supplier Modal Handoff

The supplier edit form, converted from a full-page route into a modal in the app skin.

## ⚠ Build this as the shared `Modal`

The admin has no modal primitive yet. **Add one to `Dashboard - Spec.md` §7** rather than
writing this markup into Suppliers — Add supplier, Add product, Void reason, Adjust receipt
line and the POS tender step all need the same shell.

Everything inside the modal already exists in the library: `Button`, `Badge`, inputs,
segmented chips, `Toast`. Don't rebuild them here.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Edit Supplier Modal - Implementation Guide.md** — why a modal, the shell contract,
   anatomy, behavior, endpoints, and the open questions.

## Reference implementation

**Suppliers.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. **Click any supplier row** to open the modal.

Try these:
- Type over **Name**, or clear it — `Save changes` dims and refuses.
- Switch **Payment terms** — three chips, no native select.
- **Cancel**, the **×**, **Escape**, or a click on the scrim — all close.
- Open the **Terms** filter behind the modal first: `Escape` closes the dropdown before the
  modal, never both at once.
- **Deactivate supplier** — bottom left in red, away from Save.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — build the shared component.

## What this conversion fixes

The original was a full-page route: a page header, four stacked cards, and a footer bar —
about 940px of scroll to edit six mostly-empty fields, with `Name` and `Address` inputs each
spanning the full ~1580px. Editing a supplier is a small correction made while looking at the
list, usually because you spotted a missing phone number; leaving the list and losing your
filters costs more than the edit.

Now a 620px modal: sections are labels rather than cards, fields pair up in a two-column grid
that collapses on narrow windows, payment terms is three chips instead of a native `<select>`,
and `Save changes` is the standard amber primary rather than the pure-black pill it was — the
only black element in the product. Every field, label and action is preserved verbatim.

One addition: the header shows what you're editing — `12 parts sourced · last received Aug 12,
2026`. The old page gave the same blank form for a shop you buy 41 parts from and one you've
never bought from.

## Four things to get right

- **Header and footer pin; only the body scrolls.** `max-height: 100%` plus a flex column. A
  modal that scrolls as one panel hides its own Save button.
- **Escape closes one layer at a time.** A dropdown inside the modal consumes the first
  press; the modal takes the second. Keep a small open-layer stack in the shared component.
- **A dirty draft must confirm before discarding.** Losing typed notes to a stray scrim click
  is this component's characteristic failure. Not yet in the reference — add it.
- **Deactivate is soft-only and needs its own confirm.** Historical receipts and POs
  reference the supplier; never hard-delete.

Also: the modal must trap focus, restore it to the trigger on close, lock `<body>` scroll, and
carry `role="dialog"` / `aria-modal="true"`. And as everywhere in this app — never put a CSS
`transition` on `background` when the value comes from a `var()`.

## Reuse note

`Add supplier` is this same component with an empty draft: title `Add supplier`, no Deactivate
action, primary reads `Create supplier`. One component, two modes.

## Open questions for the client

- Is `Address` an address, or a channel? Six suppliers read `Mobile` in that field. If it
  means "we only have a phone number", split it: address plus a `Mobile only` flag.
- Should `Alternative number` be a repeatable contact list? `Eleavel/Wilson` and
  `RF/Geraldine` are two people in one Contact person field.
- Are internal notes admin-only, or visible to cashiers? The label says internal; the
  permission model doesn't say.
