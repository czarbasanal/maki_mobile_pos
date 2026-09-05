# MAKI MOTOR PARTS — Users Redesign Handoff

The Users screen reskinned, with row-level delete replaced by a proper account lifecycle.

## ⚠ Build from the shared component library

`Dashboard - Spec.md` §7 defines the shared components. **This screen is assembled from
them** — `AppShell`, `Card`, `StatCard`, `SearchInput`, `SegmentedFilter`, `TableViews`,
`DataTable`, `Badge`, `Button`, `Modal`, `Toast`, `EmptyState`, `Skeleton`.

The add/edit form is **one component with `mode: 'add' | 'edit'`**, on the same `Modal` shell
as the Product, Supplier, Expense and Stock Adjustment modals. Don't build two forms, and
don't write a fifth modal shell.

## Read in this order

1. **Dashboard - Spec.md** — the skin and the component library. Start here.
2. **Users - Implementation Guide.md** — what changed and why, the two permission rules, the
   Danger zone lifecycle, the modal, endpoints, open questions.

## Reference implementation

**Users.dc.html** — opens directly in a browser (no build step) and needs `support.js` beside
it. Open it at 1400px or wider.

Try these:
- **Click a row** → the manage modal, with Account history and a red-outlined Danger zone.
- **Open your own account (Czar)** → the role picker is replaced by a read-only summary, and
  the Danger zone says to ask another admin. You cannot demote or disable yourself.
- **Open `Admin`** (the other admin) then deactivate Czar first → the last-admin guard fires:
  non-admin roles grey out with an explanation.
- **Danger zone** → `Delete` is inert until you press `Deactivate`; the row copy explains why.
- **`+ Add user`** → same modal, no history, no Danger zone, and an invite notice instead of a
  password field.
- **Role card rows** → click one to filter the table.
- **`Jeric`** → never signed in; switch the segmented filter to `Inactive` to see him.
- **Dark** — the header toggle; persists to the shared `maki-pos-theme` key.

Read exact values off the file; do not port the markup — rebuild from the library.

## What this redesign fixes

The original was Name / Email / Role / Created / Actions, with `Edit` and a red `Delete` on
every row and a pure-black `+ Add User` pill — the only black element in the product.

**No sign-in data at all**, so nothing answered *is this account still in use*. It turns out
four of the eight accounts here haven't signed in for over 40 days and one never has — none of
it visible before. **No status**, because deactivation didn't exist; delete was the only exit.
And roles were bare uppercase text with no indication of what each could do.

Now: `Last sign-in` with a staleness line that escalates in color, three sign-in KPIs, a role
card that states each role's scope and filters the table, tone-coded role badges, `YOU` on your
own account, and an Active/Inactive filter.

## Two permission rules — enforce them in the API, not just the UI

- **You cannot change your own role.** Otherwise the last admin can demote themselves and lock
  everyone out of Users, Reports and void approval permanently.
- **The last active admin cannot be demoted or deactivated.** Same lockout from the other
  direction. `activeAdminCount` must come from the server — deriving it from the current page
  means the guard silently disappears on page two.

Both are visible in the reference UI, and both must be rejected server-side with a specific
message, not a generic 403.

## Three things to get right

- **Delete is soft, and attribution survives.** Sales, job orders, receipts, adjustments and
  logs stay intact and stay attributed **by name**. Set `deletedAt`, keep the row, revoke the
  login. A nulled `createdBy` that renders a two-year-old sale as `by —` is data loss. Never
  reassign their records to a placeholder account.
- **No password field, in either mode.** An admin who can type a user's password can sign in as
  them, and every action that user takes becomes deniable. Invite links and self-service
  resets only. If the client asks for admin-set passwords, offer `Send password reset` instead.
- **Deactivation revokes sessions immediately**, not at next expiry.

Also, as everywhere in this app: never put a CSS `transition` on `background` when the value
comes from a `var()` — the old color gets pinned when the theme flips.

## Open questions for the client

- **Three accounts look like test logins** — `admin@test.com`, `cashier@test.com`,
  `staff@test.com` — and four of eight accounts are dormant 40+ days. Should the test accounts
  be removed before go-live? Shared or generic logins destroy attribution: every sale they ring
  up is unattributable.
- Are three roles enough? `STAFF` currently covers mechanics and stock handlers.
- Should `CASHIER` see any money screen — their own day's total, for cashing up?
- Should a dormant account auto-deactivate after N days? Cheapest control available, and the
  KPI already identifies them.
- Who may add users — admins only, presumably, but the reference doesn't gate the button.
