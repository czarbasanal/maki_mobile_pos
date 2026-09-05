# MAKI MOTOR PARTS — Expenses Redesign Handoff

The Expenses screen reskinned, with the add/edit form moved into the shared modal.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **This screen is assembled from
them** — `AppShell`, `Card`, `FilterBar`, `SearchInput`, `SelectFilter`, `DateRangeFilter`,
`SegmentedBar`, `DataTable`, `Badge`, `Button`, `Modal`, `Toast`, `EmptyState`, `Skeleton`.

Nothing here needs a new primitive. If you catch yourself writing a `<table>`, a chip row, a
status pill or a dropdown inside this feature's files, stop and use the shared one.

The add/edit modal is **one component with `mode: 'add' | 'edit'`**, on the same `Modal` shell
as the Product, Supplier and Stock Adjustment modals. Do not build two forms.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Expenses - Implementation Guide.md** — what changed and why, the single-scoped-set rule,
   layout, the modal, Record history, the Danger zone, endpoints, open questions.

## Reference implementation

**Expenses.dc.html** — opens directly in a browser (no build step) and needs `support.js`
beside it. Open it at 1400px or wider.

Try these:
- **Click a row** → the edit modal, with Record history at the bottom and a red-outlined
  Danger zone.
- **`+ Add expense`** → the same modal in add mode; Record history and Danger zone are
  correctly absent.
- **Move the date range** (left of Add expense) → every card, count and total re-derives, and
  the By-category card's own scope label follows it.
- **Click a By-category row** → filters the table to that category.
- **Search / Category dropdown** → the `Total shown` foot follows the filter.
- **Escape** → closes the dropdown first, then the modal.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the library.

## What this redesign fixes

The original spent ~350px of the first screenful on three cards holding three amounts, showed
no breakdown of where the money went, and gave every row exactly one action: **Delete**, in
red, with no confirmation and no way to edit a typo. Category and date were native `<select>`s,
and `+ Add expense` was a pure-black pill — the only black element in the product.

Now: one Spend card with a focal figure, a By-category card whose rows filter the table, rows
that open an edit modal with delete demoted into a Danger zone, a `Total shown` table foot for
tallying against the drawer, plus search and pagination. Every original field and label is
preserved.

## The one rule this screen keeps breaking

**Every figure derives from one scoped set.** During design the Spend card read
`This month ₱2,525.00` while the By-category card — labelled *this month* — summed to
`₱2,585.00`, because its totals were reduced over the whole dataset including an August entry.
Its percentage shares used the wrong denominator, and a third card hard-coded
`Entries this month: 5` when only four fell in September.

One filtered array must feed the table, the cards, the dropdown counts and the totals. Never
hard-code a summary figure, and never let a card's label claim a period its data doesn't cover.
The summary endpoint takes the same `from`/`to` as the list, and `byCategory` must sum to
`total` — assert it in a test.

## Three other things to get right

- **Delete is soft and belongs in the Danger zone**, never in the footer next to Save. Set
  `deletedAt`, keep the row readable in Activity Logs, exclude it from every total — including
  net profit on Reports.
- **Audit fields come from the session, server-side.** A client-supplied `updatedBy` is a
  forgeable trail. Carry `updatedVia` so a CSV import doesn't get attributed to a person.
- **`spentOn` crosses the wire as `YYYY-MM-DD`.** A client `toISOString()` shifts the date
  across midnight west of UTC and files the expense on the wrong day.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- The original showed **This Week ₱2,585.00 above This Month ₱2,525.00** — the week larger
  than the month containing it, because the 7-day window reached into August. Clip the week to
  the current month, or label both windows explicitly? The reference does the latter.
- Is the category list right — Supplies, Fuel, Wages, Rent, Utilities, Other? The live data
  only uses two of them.
- **`Salary belle ₱2,405.00` is filed under `Other`.** If wages run through Expenses rather
  than HR/Payroll, they need their own category and probably a link to the employee.
- Should large expenses need approval, and above what amount? Anyone who can open this screen
  can currently record any figure.
- Who may delete — admins only, or anyone who can edit?
