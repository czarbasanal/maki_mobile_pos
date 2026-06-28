# Bundle 07 — Void Requests

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (1 screen, 4 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Void Requests** list (admin queue) | `lib/presentation/mobile/screens/sales/void_requests_screen.dart` |
| 2 | **Empty** state | same (`EmptyStateView`) |
| 3 | **Resolve** bottom sheet (tap a pending row) | same (`showModalBottomSheet` + `ReceiptWidget`) |
| 4 | **Approve** (password) / **Reject** (reason) dialogs | same (`AlertDialog`) |

Opened from the dashboard notification bell. **Admin-only.**

## Current state — what's not migrated

Raw Material: a `ListView` of `ListTile`s split by `Divider`s, Cupertino icons, a hard-coded red unread dot,
a `showModalBottomSheet` resolve sheet, and password/reason `AlertDialog`s. **No `AppCard`, no Lucide, no status
color semantics.** This bundle = Cupertino→Lucide + Material rows→soft-shadow `AppCard` + add status color.

## States & rules to preserve (don't design these away)

- **List row** = one request: leading status glyph, title `{saleNumber} • {grandTotal}`, subtitle
  `{requestedByName} • {reason}` then `{date} • {status}`, and an **unread red dot** (trailing) when `read == false`.
  Newest first.
- **Status** = `pending` / `approved` / `rejected` — give it **color semantics** (suggest: pending = amber `clock`,
  approved = green `check-circle`, rejected = red `x-circle`), with dark parity. Currently all-neutral.
- **Mark all read** — app-bar text action; clears all unread dots.
- **Tap behavior:** tapping a row marks it read; if the request is **pending**, the **resolve bottom sheet** opens.
  Non-pending (approved/rejected) rows are read-only (no sheet).
- **Resolve sheet:** header `Void {saleNumber}?` + `Requested by {name}` + `Reason: {reason}`, a divider, then a
  **receipt-style item breakdown** of the sale being voided (reuse / match the shipped **Sale Detail / Receipt**
  styling — bundle 03), and a pinned footer with **Reject** (outlined) + **Approve** (filled) buttons.
- **Approve** opens a dialog requiring the **admin's password** (obscured field). **Reject** opens a dialog
  capturing a **rejection reason**. Both show success/error snackbars on completion.
- Currency grouped `₱1,234.00` via the app formatter; dates `MMM d, h:mm a`.
- Empty state: bell icon + "No void requests".

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–06a: soft-shadow `AppCard`
rows, Lucide icons, theme-aware **status color semantics** with dark parity (reuse `AppColors` success/warning/error
+ their `*OnDark` variants), neutral-by-default discipline (color only for status). The resolve sheet's receipt
breakdown should visually match the redesigned **Sale Detail** (bundle 03). App bar stays flat on canvas.
