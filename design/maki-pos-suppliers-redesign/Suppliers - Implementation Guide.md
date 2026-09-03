# Suppliers — Implementation Guide

Reference implementation: `Suppliers.dc.html`
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library and this screen must be assembled from it, not hand-styled.

> ### Build this from the shared components
> `AppShell`, `Card`, `TableViews`, `FilterBar`, `SearchInput`, `SelectFilter`, `DataTable`,
> `Badge`, `CopyButton`, `Button`, `Toast`, `EmptyState`, `Skeleton` — every element here
> already exists. If you find yourself writing a `<table>`, a chip row, a status pill or a
> dropdown inside this feature's files, stop and use the shared one.

---

## 1. What changed and why

Six problems on the old screen, all structural:

1. **~350px of empty white** between the header and the search field, with the `Add supplier`
   button floating alone in it. The first row sat halfway down the page.
2. **The Status column was 14 identical green `Active` pills.** A column that says the same
   thing on every row is not information — it is a filter pretending to be data. Status is
   now the saved-view strip (`Active` · `Inactive` · `Never received` · `All`) with counts,
   and only genuinely inactive rows carry a badge.
3. **The Inventory column read `0` / `₱0.00` on eleven of fourteen rows.** It was reporting
   current stock *value* per supplier, which is near-zero by nature and answers no question a
   buyer has. Replaced by **Parts** (how many SKUs you source from them) and **Spend 90d**
   (how much you actually buy).
4. **`+ Add supplier` was a pure-black pill** — the only black element in the product. Now
   the standard amber primary.
5. **An Actions column with `Edit` and `⋯` on every row**, costing ~130px to duplicate what
   clicking the row already does. Rows are clickable; per-row actions belong in the detail
   view or a right-click menu.
6. **`Show inactive` was a toggle with an eye icon** — a hidden third state. It is now an
   explicit view with a visible count.

Nothing else moved: supplier names, contacts, places and terms are verbatim.

---

## 2. Layout

Standard `AppShell`, padding `20px 28px 36px`, `flex column; gap: 12px`:

```
summary row  — Directory card + 3 stat cards   (auto-fit, minmax(236px, 1fr))
views row    — TableViews chips | + Add supplier
filters row  — search · Terms dropdown · clear · count
table card   — DataTable, empty states, pagination footer
```

The summary row is what fills the dead space, and it earns its place: it answers *who am I
buying from, on what terms, and whose details are missing.*

### Directory card
Four-row pattern from Inventory and Receiving: a label, the total right-aligned in mono, then
clickable rows — a color square, the label, the count. Each row **is** a filter and takes
`--text` / 600 when its view is active.

Rows: `Active` (`--pos`) · `Inactive` (`--text-3`) · `Never received` (`--accent`).

**The counts and the chips must derive from the same predicate.** In the first build,
`Never received` was rendered as a clickable filter but its handler set `view: 'All'` — a user
clicking a stat reading `3` landed on a 14-row table, with no selected styling to show
anything had happened. Both the card row and the chip now map through one `inView(s)`
function. This is the same counts-disagree trap flagged on Receiving; it will recur on every
screen that summarizes above a filtered table.

If a stat is **not** a filter, render it as a plain `div` with no pointer cursor. Identical
markup for interactive and non-interactive rows is the bug.

### Stat cards
`Spend, last 90 days` · `Buying on terms` · `Missing contact`. The third is a work queue: two
suppliers have no name or number on file, which is only discoverable today by scrolling and
noticing the `—`.

---

## 3. Table

| Column | Content | Style |
|---|---|---|
| Supplier | 32px initials mark + name + place, `INACTIVE` badge when applicable | name 12.5px/500, place 10.5px `--text-3` |
| Contact | name over phone with `CopyButton` | 12.5px + 10.5px mono |
| Terms | `Badge` chip | 11px/500, radius 6px |
| Parts | SKU count, `—` at zero | 12.5px mono/600, right |
| Last received | date, or `Never` in `--text-3` | 12px mono |
| Spend 90d | peso, `—` at zero | 13px mono/600, right |

`min-width: 940px` inside the `DataTable` scroller.

**Terms is color-coded**, because it is the one field that changes how you buy: `Cash` →
`--pos-soft`/`--pos`, `30 Days` → `--info-soft`/`--info`, `60 Days` →
`--accent-soft`/`--accent-text`. Route through the shared `statusTone()`-style map so the
palette stays in one place.

**The initials mark** is a 32px tinted square cycling four token pairs by row index, greying
to `--surface-3`/`--text-3` when inactive. It gives a list of 14 near-identical text rows
something to scan by. It is decorative — never derive meaning from the color.

**Phone number is new and copyable.** The old screen showed a contact name with no way to
reach them; a buyer on the shop floor wants to tap and call. Per the spec's §5.7 every
machine-readable identifier gets a `CopyButton`; a phone number qualifies.

**`Never` and `No contact`** in `--text-3` rather than a bare `—`. They read as a state
someone can act on, not as missing data.

### Empty states
- **No suppliers at all**: storefront glyph in an amber tile, `No suppliers yet`, one line —
  *once a supplier exists you can tag it on a purchase order line and on every receipt* —
  then `+ Add supplier`. Condition is `totalCount === 0` from the server.
- **No matches**: `No suppliers match these filters` + `Clear filters`.

Footer hidden entirely when there are no rows. The reference's `showEmptyState` prop exists
only to preview the first case; drop it in production.

---

## 4. Data wiring

### List
`GET /api/suppliers?status=&terms=&q=&page=&size=`

```ts
{
  rows: Array<{
    id: string,
    name: string,                  // 'Boss Atan Argao'
    place: string | null,          // 'Poblacion, Argao, Cebu' — or 'Mobile'
    contactName: string | null,
    phone: string | null,
    email: string | null,
    terms: 'cash' | 'net30' | 'net60' | string,
    partCount: number,             // distinct SKUs sourced from them
    lastReceivedAt: string | null, // ISO
    spend90d: number,              // centavos, completed receipts only
    active: boolean
  }>,
  totalCount: number,
  statusCounts: { active, inactive, neverReceived, all },
  termsCounts: [{ terms, count }]
}
```

`statusCounts` and `termsCounts` respect search but **not** the filter they drive, or the
counts contradict the rows.

`neverReceived` is `active && lastReceivedAt === null` — an active supplier you have never
actually bought from. Inactive suppliers are excluded deliberately: they are not a task.

`partCount` and `spend90d` are derived; compute them server-side (a join on inventory and on
completed receipts) rather than shipping raw receipts to the client.

`place` is free text today. `Mobile` appears where a street address is unknown, which suggests
the field is doing double duty as "how we reach them" — see the open questions.

### Detail and mutations — not built
- `GET /api/suppliers/{id}` → the detail view: contact block, terms, the SKUs sourced from
  them, receipt history, spend over time, open POs.
- `POST /api/suppliers` → add. Fields: name, contact name, phone, email, place, terms,
  optional notes.
- `PATCH /api/suppliers/{id}` → edit.
- `POST /api/suppliers/{id}/deactivate` → soft-only. **Never hard-delete a supplier** —
  historical receipts and POs reference it. Deactivating should hide it from pickers while
  leaving every past record intact.

Every add, edit and deactivation goes to Activity Logs with user and timestamp.

---

## 5. Open questions

- **Is `place` an address or a channel?** `Mobile` in that field for six suppliers suggests
  it means "we only have a phone number". If so, split it: an address field and a
  `Mobile only` flag. Ambiguous today.
- Do terms ever differ per part or per order, or is it one setting per supplier?
- Should `Spend 90d` count completed receipts only, or include pending POs as committed
  spend? The reference uses completed only.
- Is there a payables side — outstanding balance, due dates on the 30/60-day accounts? If so
  that belongs on this screen and changes the stat cards entirely. Worth asking before
  building the detail view.
- Multiple contacts per supplier? `Eleavel/Wilson` and `RF/Geraldine` are two people jammed
  into one field.

---

## 6. Definition of done

- Assembled from §7 components. No table, chip, pill or dropdown written locally.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Every count derives from the same predicate as the filter it drives; a clickable stat
  filters to exactly its own number, and shows selected styling when active.
- Non-interactive stats are not rendered as buttons.
- Both empty states present and distinct; footer hidden when empty.
- Terms filter closes on outside `mousedown` and `Escape`, both listeners removed on unmount.
- Skeleton rows at real dimensions while loading.
- Keyboard: rows reachable and activatable, focus rings visible.
