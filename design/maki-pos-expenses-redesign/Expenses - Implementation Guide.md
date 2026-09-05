# Expenses — Implementation Guide

Reference implementation: `Expenses.dc.html` — click any row to open the edit modal,
`+ Add expense` for the add mode.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build from the shared components
> Everything on this screen already exists in the library: `AppShell`, `Card`, `FilterBar`,
> `SearchInput`, `SelectFilter`, `DateRangeFilter`, `SegmentedBar`, `DataTable`, `Badge`,
> `Button`, `Modal`, `Toast`, `EmptyState`, `Skeleton`. Nothing here needs a new primitive.
>
> If you catch yourself writing a `<table>`, a chip row, a status pill or a dropdown inside
> this feature's files, stop and use the shared one.

---

## 1. What changed and why

The original had four problems:

1. **Three cards for three numbers.** `Today ₱20.00`, `This Week ₱2,585.00`,
   `This Month ₱2,525.00` each got a full-width card — roughly 90px of surface per figure,
   ~350px of the first screenful spent on three amounts. They are now three rows in one
   **Spend** card, with the week figure at 17px and the other two at 13px, so the card has a
   focal point instead of three equal-weight numbers.
2. **No sense of where the money went.** Added a **By category** card: a segmented bar plus
   clickable rows with amount and share. Clicking a row filters the table. A month total tells
   you nothing you can act on; "₱2,405 of ₱2,525 was wages" does.
3. **`Delete` on every row, in red, with no confirm and no edit.** The only row action was
   destructive, sitting one mis-click from the amount column, and there was no way to correct
   a typo — you deleted and re-entered. Rows now **open the edit modal**; delete lives in a
   Danger zone inside it.
4. **Native `<select>`s and a pure-black `+ Add expense` pill.** Both replaced with the app's
   own controls: the shared `SelectFilter` for Category, the segmented `DateRangeFilter`, and
   the standard amber primary.

Also added: a **Total shown** row in the table foot (the sum of what is on screen after
filtering — the number anyone tallying against a cash drawer actually wants), a search field,
pagination, `by <user>` under each date, and notes surfacing as a second line under the
description.

Every field and label from the original is preserved: Description, Category, Paid via, Date,
Amount.

---

## 2. Every figure derives from one scoped set

This screen's characteristic bug, and it bit twice during design: the **Spend** card said
`This month ₱2,525.00` while the **By category** card, labelled *this month*, summed to
`₱2,585.00` — the week's figure, because its totals were reduced over the whole fixture array
including an Aug 31 entry. Its percentage shares were computed against the wrong denominator
too, and a third card hard-coded `Entries this month: 5` when only four were in September.

The rule, same as Receiving:

> **One filtered array feeds the table, the cards, the chip counts and the totals.** Never
> hard-code a summary figure, and never let a card's label claim a period its data doesn't
> cover.

In the reference, `scoped = since(RANGE_FROM[range])` and everything reads from it: the
category bar, the entries count, the largest single, the dropdown counts, the table and the
foot total. The **By category** scope label follows the date-range control (`last 7 days`,
`this month`) rather than being a fixed string, so it cannot drift again.

The Spend card is the deliberate exception: its three rows are fixed windows (today / 7 days /
30 days) by definition, so each is computed from its own window and labelled precisely.

Server-side this means the summary endpoint takes the same `from`/`to` the list does, and
returns category breakdown, entry count and totals for exactly that window.

---

## 3. Layout

Standard `AppShell`, padding `20px 28px 36px`, `flex column; gap: 12px`:

```
summary row   — Spend · By category · Entries · Largest single   (auto-fit, minmax(236px,1fr))
action row    — [date range] + Add expense + Export        (all right-aligned)
filters row   — search · Category dropdown · clear · count
table card    — DataTable + Total shown foot, empty states, pagination
```

The date range sits immediately left of `+ Add expense` — it scopes the whole screen, so it
belongs with the screen-level actions rather than among the row filters. Category, which
filters only the table, stays in the filters row.

### Table columns

| Column | Content | Style |
|---|---|---|
| Description | description + note as a second line | 12.5px / 500 + 10.5px `--text-3` |
| Category | chip | 11px / 500, `--surface-3`/`--text-2`, radius 6px |
| Paid via | `Cash` / `Card` / `GCash` / `Maya` | 12.5px `--text-2` |
| Date | date over `by <user>` | 12px mono + 10.5px `--text-3` |
| Amount | peso | 13px mono / 600, right |
| *(foot)* | **Total shown** | 15px mono / 600, right |

`min-width: 860px` inside the `DataTable` scroller. The foot row hides when there are no rows.

`by <user>` under the date is there because expenses are the one place in this app where
*who entered this* is asked routinely — and it saves opening the modal to find out.

### Empty states
- **No expenses at all**: amber tile, `No expenses yet`, one line — *anything logged here comes
  off the profit the register reports* — then `+ Add expense`. Condition is `totalCount === 0`
  from the server for an unfiltered range.
- **No matches**: `No expenses match these filters` + `Clear filters`.

---

## 4. Add / edit modal — one component, two modes

520px shared `Modal`, `mode: 'add' | 'edit'`. **Do not build two forms.**

Body: Description (full width) · Amount + Date (two-up, `auto-fit minmax(150px,1fr)`) ·
Category chips · Paid via chips · Note · then, **edit mode only**, Record history and the
Danger zone.

- Amount has a `₱` prefix and is right-aligned mono — it is read against a receipt.
- Category and Paid via are chips, not selects. Six and four fixed options respectively; a
  popover for either is a wasted interaction.
- Header subtitle carries the id and date in edit mode (`EXP-0411 · Sep 2, 2026`), and
  `Money leaving the shop` in add mode.
- Footer note names the consequence: `Recorded against Czar · today` when adding,
  `Saving records you as the last editor` when editing.
- `Save` sits at `opacity .45` until Description is non-empty and Amount parses above zero.

**Date should use the shared calendar** (see the Date Range Calendar handoff), single-date
mode. The reference uses a plain text field only because it has no picker wired.

### Record history (edit mode only)

Two entries on an `auto-fit minmax(180px,1fr)` grid, each an inset `--surface-2` card:

| Created by | Last updated by |
|---|---|
| Bern · Sep 2, 2026 · 10:04 AM | Czar · Sep 2, 2026 · 3:40 PM |

Person and timestamp are **one entry, not two fields** — four separate cells read as a form
and double the label count. An unedited record shows `—` in `--text-3` with `Never edited`
beneath, never a repeat of the creator.

Three rules for the data:

- **Audit fields come from the session, server-side.** A client-supplied `updatedBy` is a
  forgeable trail.
- **Carry `updatedVia`** (`ui` / `csv_import` / `api`) so the panel can say `CSV import`
  rather than naming someone who didn't do it.
- Timestamps are absolute, `Asia/Manila`, `MMM D, YYYY · h:mm A`. "3 days ago" is useless when
  reconciling against a receipt dated the 1st.

This panel is a summary; the full per-field trail belongs in Activity Logs.

### Danger zone (edit mode only)

Last thing in the body, in a `--neg`-outlined box with a warning glyph and the label
`Danger zone`. Copy states the consequence — *Deleting keeps the entry in Activity Logs but
removes it from every expense total* — then a `--neg`-outlined `Delete expense` button.

**Never in the footer beside Cancel and Save.** A destructive button adjacent to the primary
gets hit by muscle memory, which is exactly what the original row-level `Delete` invited.

Deletion is **soft**: set `deletedAt`, keep the row, keep it readable in Activity Logs, and
exclude it from every total. It needs its own typed or two-step confirmation — not built in
the reference.

Unlike products, expenses have no deactivate step. An expense is a fact that either happened
or was recorded in error; there is no "inactive expense".

---

## 5. Data wiring

### List
`GET /api/expenses?from=&to=&category=&q=&page=&size=`

```ts
{
  rows: Array<{
    id: string,                       // 'EXP-0411'
    description: string,
    category: string,
    paidVia: 'cash' | 'card' | 'gcash' | 'maya',
    spentOn: string,                  // ISO date — the date of the expense
    amount: number,                   // centavos
    note: string | null,
    createdBy: { id, name }, createdAt: string,
    updatedBy: { id, name } | null, updatedAt: string | null, updatedVia: string | null
  }>,
  totalCount: number,
  shownTotal: number,                 // sum over the filter, for the table foot
  categoryCounts: { [name]: number }
}
```

`shownTotal` comes from the server so it reflects every page, not just the rows in hand. Say
so in the label if it ever differs from the visible rows.

### Summary
`GET /api/expenses/summary?from=&to=`

```ts
{
  total: number,
  entryCount: number,
  recorderCount: number,
  byCategory: [{ name, amount }],     // sums to `total`
  largest: { description, amount, spentOn } | null,
  periods: { today: number, last7: number, thisMonth: number }
}
```

`byCategory` **must** sum to `total`, and both must cover exactly the requested window. Assert
it in a test — this is the invariant that broke twice.

### Writes
```
POST  /api/expenses          { description, amount, category, paidVia, spentOn, note }
PATCH /api/expenses/{id}     same shape
POST  /api/expenses/{id}/delete   → soft delete, sets deletedAt
```

Money is integer centavos, parsed at the edge and never accumulated as floats. `spentOn` is
a `YYYY-MM-DD` string — never a client `toISOString()`, which shifts the date across midnight
west of UTC.

Every create, edit and delete writes to Activity Logs with user, timestamp and changed fields,
and bumps `updatedAt` / `updatedBy` so Record history stays truthful.

**Expenses feed the Reports screen.** Net profit there is gross margin minus expenses over the
same window, so a soft-deleted expense must drop out of both consistently.

---

## 6. Not built

Receipt photo attachment (worth having — a paper receipt for a ₱2,405 wage payout is the
audit trail) · recurring expenses like rent · category management · approval for large
amounts · a delete confirmation step · the single-date picker in the modal.

---

## 7. Open questions

- **The original screen reported `This Week ₱2,585.00` above `This Month ₱2,525.00`** — the
  week larger than the month containing it, because the week window reached back into August.
  Correct as arithmetic, misleading as a pair. Should the week figure be clipped to the current
  month, or the labels made explicit (`last 7 days` vs `Sep 1–5`)? The reference does the
  latter.
- Is the category list right — Supplies, Fuel, Wages, Rent, Utilities, Other? The live data
  only uses Supplies and Other, which suggests the list was never filled in.
- **`Salary belle ₱2,405.00` is filed under `Other`.** If wages run through Expenses rather
  than HR/Payroll, they want their own category and probably a link to the employee record.
- Should large expenses need approval, and above what threshold? Anyone who can open this
  screen can currently record any amount.
- Who may delete — admins only, or anyone who can edit?
