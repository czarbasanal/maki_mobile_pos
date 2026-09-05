# Void Requests — Implementation Guide

Reference implementation: `Void Requests.dc.html`
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build from the shared components
> Everything here already exists in the library: `AppShell`, `Card`, `StatCard`,
> `DateRangeFilter`, `SearchInput`, `SegmentedFilter`, `DataTable`, `Badge`, `CopyButton`,
> `Button`, `Toast`, `EmptyState`, `Skeleton`.
>
> Two tables on one screen is two chances to fork `DataTable`. Don't — the waiting queue and
> the resolved history are the same component with different columns.

---

## 1. What changed and why

The original screen had one job — decide on pending voids — and could not do it. Five
problems:

1. **No reason column.** The single most important field was missing entirely. A manager
   approving a void needs to know *why* before anything else; the old table showed sale,
   amount, requester and outcome, and left the reason invisible.
2. **No timestamps.** No request time, no resolution time. A void request is a **held sale**
   — the cashier is waiting, and possibly the customer is too — so how long it has sat is the
   whole basis for prioritising it.
3. **`APPROVED` three times in a column called Outcome.** Every resolved row read the same
   value, so the column carried no information. It is now a real filter (`All / Approved /
   Rejected`) with counts, and the pill only earns its place because it varies.
4. **The waiting queue had no actions.** `Nothing waiting` was the only state ever designed;
   there was no approve or reject anywhere on the screen, so the screen's stated purpose —
   *approving voids the sale and puts its stock back* — had no button.
5. **No summary.** Nothing told you how many were pending, how long the oldest had waited, or
   how much money was held up.

Added: four KPIs, the reason column with an optional free-text detail line, requested and
resolved timestamps with the resolver and how long it took, an age indicator that escalates,
`CopyButton` on every sale no., search, date presets, CSV export, and a **Total voided** table
foot.

Header copy is unchanged: *Approving voids the sale and puts its stock back. Rejecting leaves
the sale as it stands and tells the cashier why.*

---

## 2. Layout

```
KPI strip     — Waiting on you (lead) · Oldest request · Approved · Approval rate
Waiting       — heading + count badge ......... note
                queue table with row actions, or the empty state
Resolved      — heading .................... [date presets] [CSV]
                [search] [outcome chips]
                history table + Total voided foot
```

**Waiting sits above Resolved and is never scoped by the date filter.** A pending request from
three weeks ago is still pending; hiding it behind a 7-day window would be a queue that lies.
Only the resolved history is scoped.

The date presets and CSV stay on the Resolved heading row (they belong to that section as a
whole); search and the outcome chips sit on their own row beneath it.

### Waiting queue

| Column | Content |
|---|---|
| Sale | sale no. + `CopyButton` |
| Reason | reason `Badge` over an optional detail line in `--text-2` |
| Requested by | cashier |
| Requested | timestamp over an **age** line |
| Amount | peso, right |
| — | `Reject` (secondary, hovers to `--neg`) · `Approve void` (amber primary) |

`min-width: 1000px` in the inner scroller.

**Age escalates in color:** `<1h` `--text-3`, `1–4h` `--accent-text`, `≥4h` `--neg`. It is the
only prioritisation signal on the screen and costs nothing to render.

`Reject` is the secondary and `Approve void` the primary, because approving is the expected
outcome. But note §4 — the approve path is the destructive one, and it needs a confirmation
step this reference doesn't have.

### Resolved history

Sale · Reason · Requested (+ by) · Outcome · Resolved (+ by, + duration) · Amount, with a
**Total voided** foot summing only the approved rows in view. `min-width: 1060px`.

**Duration (`16m`, `1h 24m`) is the number worth watching.** It measures how long a customer
stood at the counter waiting for a manager, and it is the metric that tells the owner whether
approval authority needs delegating.

### Reason tones
`Wrong item` / `Wrong price` → `--info` · `Duplicate sale` → `--accent` ·
`Customer cancelled` → `--surface-3` · `Test transaction` → `--neg`.

`Test transaction` is deliberately red: a real sale voided as a "test" is the classic cover
for register theft, and it should catch the eye in a scan. Confirm the reason list.

### Empty states — three, all distinct
1. **Nothing waiting** — green check tile, *Void requests filed by cashiers show up here for
   approval. Until then, no sale is being held.* This is the good state, so it reads as
   reassurance rather than absence.
2. **No resolved requests in this range** — clock tile, with a **Widen the range** action.
3. **No resolved requests match** — filter-blaming copy with `Clear filters`.

States 2 and 3 must not be conflated. The first build showed the filter message for an empty
range, and its `Clear filters` button reset outcome and search but left the range untouched —
so it changed nothing and the user was stuck with no way to discover the cause.

Same family: with nothing resolved in range, `Approval rate` renders **`—`**, not `0%`. A
fabricated zero reads as "every request was rejected".

---

## 3. Data wiring

```
GET /api/void-requests?status=pending
GET /api/void-requests?status=resolved&from=&to=&outcome=&q=&page=&size=

{
  rows: [{
    id: string,
    saleNo: string,
    amount: number,                    // centavos
    reason: string,                    // controlled vocabulary
    detail: string | null,             // cashier's free text
    requestedBy: { id, name },
    requestedAt: string,               // ISO
    status: 'pending' | 'approved' | 'rejected',
    resolvedBy: { id, name } | null,
    resolvedAt: string | null,
    rejectionNote: string | null
  }],
  totalCount, pendingCount,
  counts: { approved, rejected },
  voidedTotal: number                  // approved only, over the range
}
```

`counts` respects the range and search but **not** the outcome filter, or the chip counts
contradict the rows. Same rule as every list in this app.

Age is derived client-side from `requestedAt` against the server's business date — but it must
re-derive on a timer or the queue silently stops ageing while the tab is open.

### Decisions
```
POST /api/void-requests/{id}/approve   { idempotencyKey }
POST /api/void-requests/{id}/reject    { reason, idempotencyKey }
```

Six rules:

1. **Approving is one server transaction:** mark the sale voided, return every line's stock,
   reverse the payment record, close the request. A partial failure that returns stock without
   voiding the sale is unrecoverable from the UI.
2. **Idempotency key per attempt.** A double-tapped Approve must not void twice or return stock
   twice.
3. **The sale is never deleted.** It stays readable with a `Voided` status — see the Sale
   detail guide.
4. **Rejecting requires a note**, and that note goes back to the cashier. The screen's own copy
   promises this ("tells the cashier why"); the reference doesn't collect it yet.
5. **Whoever raised the request cannot approve it.** Enforce server-side. Without this, a
   cashier with an admin login can void their own sales, which is the entire risk this feature
   exists to control.
6. **Stale requests must 409.** If the sale was already voided, refunded or amended since the
   request was filed, refuse and refresh the row rather than applying a second reversal.

Every decision writes to Activity Logs with actor, timestamp, sale, amount, reason and
outcome. Voided sales must drop out of Reports consistently — gross, COGS, profit and the
payment split all recompute.

---

## 4. Not built — and one of these is load-bearing

**Approve needs a confirmation step.** It is the most destructive single action in the product:
it reverses money and moves stock, in one click, from a table row. It should open a small
confirm modal (the shared `Modal`, `sm`) showing the sale's line items and the stock that will
be returned. Right now a mis-click voids a sale.

**Reject needs its note field** — a required textarea in the same modal.

Also missing: the sale's line items inline or on hover (a manager shouldn't have to leave to
see what is being voided) · partial voids of single lines · a link to the sale detail · a
per-cashier void-frequency view (the genuinely useful anti-theft signal) · notification to the
cashier on resolution · an SLA alert when a request ages past a threshold.

---

## 5. Open questions

- Is the reason list right? The reference invents `Wrong item`, `Wrong price`,
  `Duplicate sale`, `Customer cancelled`, `Test transaction`.
- **Who may approve?** Admin only, or a supervisor role? And should the requester be blocked
  from approving their own — the reference assumes yes.
- Can a void be reversed after approval, or is it final?
- Should there be a **time limit** on requesting a void — e.g. same business day only? Voiding
  a month-old sale reopens closed books.
- Does approving a void restock **damaged** goods? A returned part that broke shouldn't go back
  on the shelf at full count.
- Should approval be possible from a phone? This is the one screen where the manager is
  routinely away from the desk while a customer waits.

---

## 6. Definition of done

- Assembled from §7 components; both tables are `DataTable` with inner scrollers.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Waiting queue unscoped by the date filter; resolved history scoped, with counts derived from
  the same filtered set.
- All three empty states present and distinct; no `0%` with a zero denominator.
- Approve and reject both confirm; reject collects a required note.
- The requester cannot approve their own request (server-enforced).
- Approve is one idempotent transaction; stale requests 409.
- Skeleton rows at real dimensions while loading; error state on both tables.
- Keyboard: row actions reachable in order, focus rings visible, `Escape` closes the confirm.
