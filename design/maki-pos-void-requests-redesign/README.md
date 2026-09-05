# MAKI MOTOR PARTS — Void Requests Redesign Handoff

The Void Requests screen reskinned, with the approval queue made usable.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **This screen is assembled from
them** — `AppShell`, `Card`, `StatCard`, `DateRangeFilter`, `SearchInput`, `SegmentedFilter`,
`DataTable`, `Badge`, `CopyButton`, `Button`, `Toast`, `EmptyState`, `Skeleton`.

Two tables on one screen is two chances to fork `DataTable`. Don't — the waiting queue and the
resolved history are the same component with different columns.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Void Requests - Implementation Guide.md** — what changed and why, the two tables, all
   three empty states, the approve/reject transaction rules, open questions.

## Reference implementation

**Void Requests.dc.html** — opens directly in a browser (no build step) and needs
`support.js` beside it. Open it at 1400px or wider.

Try these:
- **Approve void** or **Reject** on a waiting row → it moves to the resolved history and every
  count, the KPI strip and the sidebar badge update.
- **Reason column** → tone-coded badge with the cashier's own note beneath.
- **Age line** under the request time → `--text-3` under an hour, amber past one, red past
  four.
- **Date presets** (`Today · 7 days · 30 days · Custom`) → scope the resolved history only.
  The waiting queue is deliberately never scoped.
- **`Today`** → the *empty range* state, with a range-widening action. Search for nonsense
  instead and you get the *no matches* state with `Clear filters` — deliberately different
  messages.
- **`showEmptyState: true`** → the `Nothing waiting` state, which is the good state and reads
  as reassurance.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the library.

## What this redesign fixes

The original screen had one job and couldn't do it. **No reason column** — the single field a
manager needs before approving anything. **No timestamps**, so no way to tell which held sale
had been waiting longest. `APPROVED` repeated in all three rows of a column called Outcome,
carrying no information. And **no approve or reject action anywhere** — the header promised
"approving voids the sale and puts its stock back", but there was no button.

Now: reason as a tone-coded column with the cashier's note, requested and resolved timestamps
with the resolver and how long they took, an age indicator that escalates, four KPIs led by
`Waiting on you`, outcome as a real filter with counts, and row actions that work.

## Two things this reference gets wrong on purpose — fix them

- **Approve has no confirmation.** It is the most destructive action in the product: it
  reverses money and returns stock, in one click, from a table row. Put it behind a confirm
  modal (shared `Modal`, `sm`) showing the sale's lines and the stock about to be restocked.
- **Reject collects no note.** The screen's own copy promises it "tells the cashier why". Make
  the note required in the same modal, and send it back to the cashier.

## Four rules for the backend

- **Approving is one transaction:** void the sale, return every line's stock, reverse the
  payment record, close the request. A partial failure that restocks without voiding is
  unrecoverable from the UI. Idempotency key per attempt — a double tap must not void twice.
- **The requester cannot approve their own request.** Enforce server-side. Without it, a
  cashier with an admin login can void their own sales, which is the entire risk this feature
  exists to control.
- **The sale is never deleted** — it keeps a `Voided` status and stays readable. Voided sales
  must drop out of Reports consistently: gross, COGS, profit and the payment split all
  recompute.
- **Stale requests 409.** If the sale was already voided, refunded or amended since the request
  was filed, refuse and refresh the row.

Two smaller ones: `counts` respects the range and search but **not** the outcome filter, or the
chip counts contradict the rows; and age must re-derive on a timer, or the queue silently stops
ageing while the tab sits open.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- Is the reason list right? The reference invents `Wrong item`, `Wrong price`,
  `Duplicate sale`, `Customer cancelled`, `Test transaction`. **`Test transaction` is styled
  red on purpose** — a real sale voided as a "test" is the classic cover for register theft.
- **Who may approve?** Admin only, or a supervisor role too?
- Can a void be reversed after approval, or is it final?
- Should there be a time limit on requesting a void — same business day only? Voiding a
  month-old sale reopens closed books.
- Does approving restock **damaged** goods? A part that came back broken shouldn't return to
  the shelf at full count.
- Should approval work from a phone? This is the one screen where the manager is routinely away
  from the desk while a customer waits at the counter.
