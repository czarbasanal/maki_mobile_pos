# Users — Implementation Guide

Reference implementation: `Users.dc.html` — click any row (or `Manage`) for the edit modal,
`+ Add user` for the add mode.
Skin, tokens and shared components: `Dashboard - Spec.md`. **Read that first** — §7 is the
shared component library.

> ### Build from the shared components
> Everything here already exists in the library: `AppShell`, `Card`, `StatCard`,
> `SearchInput`, `SegmentedFilter`, `TableViews`, `DataTable`, `Badge`, `Button`, `Modal`,
> `Toast`, `EmptyState`, `Skeleton`.
>
> The add/edit form is **one component with `mode: 'add' | 'edit'`** on the same `Modal` shell
> as the Product, Supplier, Expense and Stock Adjustment modals. Do not build two forms, and
> do not write a fifth modal shell.

---

## 1. What changed and why

The original was a bare table — Name, Email, Role, Created, Actions — with an `Edit` and a red
`Delete` on every row and a pure-black `+ Add User` pill. Four problems:

1. **`Delete` on every row, in red, with no confirm.** Deleting a user account is not a row
   action. Every sale, job order, receipt and log entry in the system is attributed to a user;
   removing one carelessly damages the audit trail. Rows now open a modal, and both
   destructive actions live in a Danger zone inside it.
2. **No sign-in information at all.** The column that answers *is this account still in use*
   didn't exist. `Last sign-in` is now a column with a relative line under it, escalating in
   color, and it drives three KPIs. Four of the eight accounts here haven't signed in for over
   40 days, and one has never signed in — none of which the old screen could tell you.
3. **`ADMIN` / `CASHIER` / `STAFF` as bare uppercase text.** No indication of what each can do.
   Roles are now tone-coded badges (`ADMIN` amber, `STAFF` green, `CASHIER` blue), the summary
   card states each one's scope in three words, and the modal's role picker carries a sentence
   per role.
4. **No status.** Nothing distinguished an active account from a disabled one, because
   deactivation didn't exist — only delete.

Added: a role-distribution card whose rows filter the table, three sign-in KPIs, `YOU` on your
own account, avatar tiles tinted by role, an Active/Inactive/All filter, search, and Account
history in the modal.

---

## 2. Layout

```
summary row   — Accounts by role · Signed in this week · Dormant 30+ · Never signed in
views row     — role chips ............ [Active/Inactive/All] [+ Add user]
filters row   — search · clear · count
table card    — DataTable, or the no-matches state
```

### Columns

| Column | Content |
|---|---|
| User | role-tinted avatar tile + name (+ `YOU`) + email |
| Role | tone-coded badge |
| Last sign-in | timestamp over a relative line |
| Added | date, `--text-3` |
| Status | dot + `Active` / `Inactive` |
| — | `Manage` |

`min-width: 940px` in the inner scroller. Inactive rows render at `opacity .62`.

**Staleness escalates:** `≤7 days` `--text-3`, `8–29` `--accent-text`, `≥30` `--neg`, and
`Never` `--neg` with *invite not accepted* beneath. An account that hasn't been used in two
months is an open door, and this is the only place anyone would notice.

---

## 3. The two permission rules

Both are visible in the UI **and must be enforced server-side** — a client guard on
permissions is a courtesy, not a rule.

1. **You cannot change your own role.** On your own account the role picker is replaced by a
   read-only summary explaining why. Otherwise the last admin can demote themselves and lock
   everyone out of Users, Reports and void approval permanently.
2. **The last active admin cannot be demoted or deactivated.** Non-admin options grey out with
   *Unavailable while this is the only admin*, plus a line in `--neg` above the picker. Same
   lockout, reached from the other direction.

Related, and enforced in Void Requests rather than here: **whoever files a void request cannot
approve it.** Worth stating in the role descriptions so the boundary is legible.

### Danger zone — deactivate before delete

Bottom of the modal body, `--neg`-outlined box, edit mode only. Same pattern as the Product
and Expense modals, and never in the footer beside Save.

- **Deactivate** — reversible. They keep their history but cannot sign in. Sessions must be
  revoked immediately, not at next expiry.
- **Delete** — inert while the account is active (`opacity .55`, `cursor: not-allowed`), with
  the row copy explaining why rather than a tooltip.
- **On your own account both are hidden**, replaced by *Ask another admin to deactivate it.*

> **Deletion is soft, and attribution survives.** Sales, job orders, receipts, purchase
> orders, adjustments and activity logs stay intact and stay **attributed to that person by
> name**. Set `deletedAt`, keep the row, revoke the login.

A nulled `createdBy` that renders a two-year-old sale as `by —` is data loss. Never
`DELETE FROM users`, and never reassign their records to a placeholder account.

Delete needs typed confirmation (the email) in a second modal — not built in the reference.

---

## 4. Add / edit modal

540px shared `Modal`. Body: Name + Email two-up (`auto-fit minmax(200px,1fr)`) · Role picker ·
then per mode.

**Add mode** carries an `--info` notice: *They will get an email to set their own password. You
never see or set it.* Primary reads `Send invite`.

**No password field, in either mode.** An admin who can type a user's password can sign in as
them, and every action that user takes becomes deniable. Invite links and self-service resets
only. If the client asks for admin-set passwords, push back — offer *Send password reset* as
the answer.

**Edit mode** adds **Account history** — three inset cards on an `auto-fit minmax(160px,1fr)`
grid: `Added by` (person + date), `Last updated by` (person + timestamp, or `—` with *Never
edited*), `Last sign-in`. Then a `View activity for this user →` link into Activity Logs
filtered to them.

Person and timestamp are **one entry, not two fields** — four separate cells read as a form and
double the label count.

Audit fields come from the session, server-side. Carry `updatedVia` so a bulk import isn't
attributed to a person. Timestamps absolute, `Asia/Manila`, `MMM D, YYYY · h:mm A`.

Footer note names the consequence: `An invite email goes out on save` / `Saving records you as
the last editor`. `Save` sits at `opacity .45` until name and email are both present.

---

## 5. Data wiring

```
GET /api/users?role=&status=&q=

{
  rows: [{
    id, name, email,
    role: 'admin' | 'staff' | 'cashier',
    active: boolean,
    lastSignInAt: string | null,        // null = invite never accepted
    createdAt: string, createdBy: { id, name },
    updatedAt: string | null, updatedBy: { id, name } | null, updatedVia: string | null
  }],
  totalCount,
  counts: { admin, staff, cashier },    // active only, for the role card
  activeAdminCount: number              // drives the last-admin guard
}
```

`counts` respects search and status but **not** the role filter, or the chip counts contradict
the rows.

**`activeAdminCount` must come from the server.** Deriving it from the current page means the
last-admin guard silently disappears on page two.

### Writes
```
POST  /api/users                      { name, email, role }        → sends invite
PATCH /api/users/{id}                 { name, email, role }
POST  /api/users/{id}/deactivate      → revoke sessions immediately
POST  /api/users/{id}/reactivate
POST  /api/users/{id}/delete          → soft; sets deletedAt, revokes login
POST  /api/users/{id}/resend-invite
POST  /api/users/{id}/send-password-reset
```

Server must reject: changing your own role, demoting or deactivating the last active admin,
deleting an active account, and deleting yourself. Each with a specific message, not a generic
403 — the UI shows the reason inline.

`409 duplicate_email` is the likely real-world error; surface it on the Email field, not as a
toast.

Every create, role change, deactivation, reactivation and deletion writes to Activity Logs
with actor, target, before/after role and timestamp. Role changes are the highest-value line
in that log.

---

## 6. Not built

Typed delete confirmation · resend invite / send password reset actions (both endpoints
specified; the UI has no buttons yet) · 2FA · session list with remote sign-out · per-user
permission overrides beyond the three roles · PIN-based quick switch at the register (raised in
the Sign In handoff — it fits this shop better than email and password at the counter) ·
pagination, which the current eight accounts don't need but a growing team will.

---

## 7. Open questions

- **Four of eight accounts are dormant 40+ days, and three look like test logins** —
  `admin@test.com`, `cashier@test.com`, `staff@test.com`. Should those be deleted before go-live?
  Shared or generic logins destroy attribution: every sale one of them rings up is
  unattributable.
- Are three roles enough? `STAFF` currently covers mechanics and stock handlers, which may want
  splitting.
- Should `CASHIER` see any money screens — their own day's total, for cashing up?
- Who may add users — admins only, presumably, but the reference doesn't gate the button.
- Should a dormant account auto-deactivate after N days? It is the cheapest control available
  here, and the KPI already identifies the accounts.

---

## 8. Definition of done

- Assembled from §7 components; one modal component with two modes.
- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Counts derive from one filtered set; `activeAdminCount` comes from the server.
- Own-role change and last-admin demotion blocked in UI **and** API, each with its own message.
- Delete inert until deactivated, typed confirmation, soft, attribution preserved.
- No password field anywhere; deactivation revokes sessions immediately.
- Skeleton rows at real dimensions while loading; `Escape` closes the modal.
- Keyboard: rows reachable, role options arrow-navigable as a radio group, focus rings visible.
