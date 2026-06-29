# Handoff: MAKI POS — Void Requests (admin approval queue)

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS Void Requests.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex value, font size, weight, padding, gap, radius, border, shadow, icon, copy string, row order,
> and state below is **intentional and already verified** — replicate all of it, do not skip any. **Do NOT**
> redesign, "improve", simplify, round values, substitute icons, re-order, rename labels, or drop any
> state/sheet/dialog. Build **both light and dark** themes, every state shown.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - Implement in the existing codebase using its real widgets/theme (this is a visual spec, not code to paste).
> - **Preserve every behavioral rule** (mark-all-read, unread dot, tap-to-resolve, password/reason gates,
>   admin-only) — restyle only, never change the flow or the figures.
>
> When in doubt, match the prototype rather than your own judgment. Treat "follow every detail" literally.

## Overview
Bundle **07** of the MAKI POS redesign — the admin **Void Requests** queue (opened from the dashboard notification
bell). It brings the screen onto the **elevated global theme** (bundles 01–06b): a raw Material `ListView` of
`ListTile`s split by `Divider`s becomes soft-shadow **`AppCard`** rows; **Cupertino icons → Lucide**; and the
request status — which currently ships **all-neutral** — gains **color semantics** (pending amber · approved green ·
rejected red) with full dark parity (**gold leads in dark**). The unread red dot, "Mark all read", tap-to-resolve
bottom sheet, and password/reason dialogs are all preserved. The resolve sheet's receipt breakdown **matches the
shipped Sale Detail (bundle 03)**. **Admin-only screen.**

This reuses the **global theme** — do **not** invent new tokens. Pull from `design/handoff/maki-theme/` /
`lib/core/theme/` (`AppColors` success/warning/error + their `*OnDark` variants) exactly as bundles 01–06 did.

## About the Design Files
These files are **design references created in HTML** — a prototype of the intended look and behavior, **not
production code to ship**. The task is to **recreate them in the existing Flutter codebase**
(`lib/presentation/mobile/screens/sales/void_requests_screen.dart` + its sheet/dialogs) using its established
widgets (`AppCard`, the shared `ReceiptWidget`, status chips) and the theme layer. Translate the CSS values below
into Flutter `ThemeData` / widget styles. (If the target is some other environment, recreate faithfully using that
stack's idioms — but the visual result must be identical.)

- `MAKI POS Void Requests.dc.html` — the redesign prototype (4 states × light + dark). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (Material `ListTile`/`Divider`, Cupertino, no `AppCard`, no status color), for before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, and icons are final. **Match them precisely.**

---

## Source files (what to migrate)
| Surface | Source |
|---|---|
| Void Requests list (admin queue) | `lib/presentation/mobile/screens/sales/void_requests_screen.dart` |
| Empty state | same (`EmptyStateView`) |
| Resolve bottom sheet | same (`showModalBottomSheet` + `ReceiptWidget`) |
| Approve / Reject dialogs | same (`AlertDialog`) |

Rows migrate from Material `ListTile` + `Divider` → `AppCard`
(`lib/presentation/shared/widgets/common/app_card.dart`): light = soft shadow; dark = `darkCard` `#18262A` + 1px
hairline `#243234`. The resolve sheet's item breakdown reuses / visually matches the redesigned **Sale Detail /
`ReceiptWidget`** (bundle 03).

Entity: `VoidRequestEntity` — `status` = `pending` / `approved` / `rejected`; `read` flag drives the unread dot.

---

## Design Tokens

| Token | Light | Dark |
|---|---|---|
| Screen canvas | `#F6F5F3` | `#0C1415` |
| Card / row (`AppCard`) | `#FFFFFF` + shadow `0 2px 8px rgba(17,28,29,.06)` | `#18262A` + 1px border `#243234` (no shadow) |
| Bottom sheet surface | `#FFFFFF`, radius 26 top, shadow `0 -10px 36px rgba(17,28,29,.22)` | `#18262A` + 1px `#243234`, shadow `0 -10px 36px rgba(0,0,0,.5)` |
| Dialog surface | `#FFFFFF`, radius 24, shadow `0 24px 60px rgba(17,28,29,.28)` | `#18262A` + 1px `#243234`, shadow `0 24px 60px rgba(0,0,0,.55)` |
| Scrim | `rgba(17,28,29,.36)` sheet / `.40` dialog | `rgba(0,0,0,.5)` sheet / `.55` dialog |
| Primary (slate) | `#283E46` | gold `#E8B84C` **leads** |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Sale number (mono) / amount | `#16201F` (mono 13/600) / `#16201F` (13.5/700) | `#ECEFEF` / `#ECEFEF` |
| Divider / hairline | `#F0F0F0` | `#243234` |
| Input fill / border | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` |
| Input focus (password) | 1.5px `#283E46` + ring `0 0 0 4px rgba(40,62,70,.07)` | 1.5px `#E8B84C` + ring `0 0 0 4px rgba(232,184,76,.12)` |

### Status color semantics — the headline of this bundle (MUST ADD; currently all-neutral)
Drives the **leading icon-square tint + glyph**, the **status pill**, and the list **count pill**. Dark parity in
the right column.
| Status | Glyph (leading / pill) | Light — icon · square/pill tint · text | Dark |
|---|---|---|---|
| **pending** | `clock` · `clock` | `#C8881A` · `rgba(245,124,0,.12)` · pill text `#C8881A` | `#F5B547` · `rgba(245,181,71,.14)` · `#F5B547` |
| **approved** | `check-circle-2` · `check` | `#2E7D32` · `#E8F5E9` · `#2E7D32` | `#5FC86A` · `rgba(76,175,80,.16)` · `#8FE39A` |
| **rejected** | `x-circle` · `x` | `#F44336` · `rgba(244,67,54,.10)` · `#F44336` | `#FF6B5E` · `rgba(255,107,94,.14)` · `#FF6B5E` |

**Leading square:** 40×40, radius 11, status tint bg, 20px status glyph (stroke 1.9). **Status pill:** 10/600,
letter-spacing .3, icon (11px) + capitalized word, radius 999, padding 2×8, status tint. **Unread dot:** 9px
circle, `#F44336` / `#FF6B5E`, trailing, top-aligned — **only when `read == false`.**

**Type:** **Figtree** (400/500/600/700/800); **Roboto Mono** (600) for the **sale number** (`SALE-20260627-3`).
Sizes: app-bar title 18/600 · "Mark all read" action 13/600 · row sale-number 13 mono/600 · row amount 13.5/700 ·
row subtitle 12.5 muted · status pill 10 · date 11.5 hint · sheet title 18/700 · receipt total 18/700 · dialog
title 17/700 · dialog sub 12.5 · field 14–16. **Radii:** row/dialog-field 15–16 · receipt block 16 · sheet 26 top ·
dialog 24 · leading square 11 · pill/dot 999. **Shadows:** card `0 2px 8px rgba(17,28,29,.06)` (light only; dark =
1px hairline) — use explicit `BoxShadow`, not Material `elevation`.

**Currency:** grouped `₱1,234.00` via the app formatter. **Dates:** `MMM d, h:mm a` ("Jun 27, 11:48 AM").

**Icons — Lucide, stroke 1.75–1.9** (2.2–2.6 for pill/button glyphs): status bar `signal-high`/`wifi`/`battery-full`
· back `chevron-left` · mark-all-read `check-check` · pending `clock` · approved `check-circle-2` (pill `check`) ·
rejected `x-circle` (pill `x`) · empty `bell` · sheet reason `message-square-quote` · receipt labor chip text-only ·
approve `check` / `shield-check` · reject `x` · password `lock` + `eye-off`.

---

## Screens / Views

> Each frame is a flex **column**: status bar (36) → app bar (≈52) → **scrolling body**. App bar sits flat on the
> screen canvas. The trailing app-bar action is **"Mark all read"** (`check-check` + label, slate / **gold**;
> disabled = muted `#B7BDC0` / `#4A5A5E` when nothing is unread, as in the empty state).

### State 1 — Void Requests list  (`void_requests_screen.dart`)
**App bar:** `chevron-left` back · **"Void Requests"** · trailing **Mark all read**.
**Body** (padding `12 16 20`): a small **count caption** — amber **"N pending"** pill (12/700, `white-space:nowrap`)
+ "· N total" muted — then the **request rows** (newest first), each an **`AppCard`** (radius 16, margin-bottom 10),
`display:flex; align-items:flex-start; gap:12; padding:14`:
- **Leading** status square (per semantics table).
- **Middle** (flex:1): top line = **sale number** (mono 13/600) + **grand total** (13.5/700, right via
  `margin-left:auto`); **subtitle** (12.5 muted, margin-top 4) = `{requestedByName} · {reason}`; **meta row**
  (margin-top 7) = **status pill** + **date** (11.5 hint).
- **Trailing:** **unread red dot** — only when `read == false` (pending rows here are unread; resolved rows read).

**Mock rows (reproduce verbatim, newest first):**
1. `SALE-20260627-3` · **₱980.00** · Juan Dela Cruz · Wrong item scanned · **Pending** · Jun 27, 11:48 AM · **unread**
2. `SALE-20260627-1` · **₱1,540.00** · Maria Santos · Customer changed mind · **Pending** · Jun 27, 9:12 AM · **unread**
3. `SALE-20260626-8` · **₱430.00** · Juan Dela Cruz · Duplicate charge · **Approved** · Jun 26, 5:30 PM
4. `SALE-20260626-2` · **₱2,100.00** · Maria Santos · Test transaction · **Rejected** · Jun 26, 10:05 AM

### State 2 — Empty  (`EmptyStateView`)
Same app bar (Mark-all-read **disabled/muted**). Centered empty state: 80px circle (`rgba(40,62,70,.06)` /
`rgba(255,255,255,.05)`) holding `bell` (34px, hint) · **"No void requests" 16/700** · sub "When a cashier requests
a void, it appears here for your review." 13 hint.

### State 3 — Resolve bottom sheet  (`showModalBottomSheet`, opens on tapping a **pending** row)
Scrim over the dimmed list; sheet pinned to bottom (top inset ~42px), radius 26 top, grab handle (38×4,
`#E2E2E2`/`#2C3C3E`). Three regions:
1. **Context header** (padding `12 18 14`): amber `clock` leading square + **"Void this sale?" 18/700** over
   "Requested by **{name}**" (12.5 muted); then a **reason callout** — amber-tint panel (radius 12, padding 10×12)
   with `message-square-quote` + "**Reason** · {reason}".
2. **Receipt** (scrolls, top hairline) — **matches Sale Detail**: centered **sale number** (mono 13/600 slate/gold)
   + date·time·cashier (12 muted); an inset block (`#FAFAFA`/`#0C1415`, radius 16, hairline) of **item rows**
   (`display:flex; gap:12; padding:12 13`, hairline between): **qty chip** `×N` (slate `#283E46` bg / white text;
   dark gold `#E8B84C` / `#121C1D`; the **Labor** row uses a tinted text chip instead of `×N`) + name 13.5/600 over
   `{sku} · ₱{unit}/pc` (12 muted) + line total 13.5/700; then **"Total to void"** (14/600) + amount (18/700) below
   the block.
3. **Footer** (top hairline, padding `14 18 20`): **Reject** (outlined, 1.5px error border, error text, `x` icon) +
   **Approve** (filled — slate `#283E46` / **gold in dark**, `check` icon) — two equal-width 50px buttons, radius 15.

**Mock sale:** `SALE-20260627-3` · Jun 27, 2026 · 11:48 AM · Juan Dela Cruz — ASK Brake Shoe XRM 125 ×2 ₱500.00 ·
NGK Spark Plug CPR6EA-9 ×1 ₱200.00 · Labor — Brake service ₱280.00 · **Total to void ₱980.00**.

### State 4 — Approve / Reject dialogs  (`AlertDialog`)
Scrim over the screen; centered. Both: header = tinted icon square (40×40, radius 11) + title (17/700) over sub
(12.5 muted), a labeled field, then right-aligned **Cancel** (muted text) + a filled action.
- **Approve** (opened by sheet's Approve) — green `shield-check` square · **"Approve void"** / "Confirm with your
  admin password" · **Password** field (obscured `••••••••`, `lock` + `eye-off` toggle, **focused**: primary border
  + ring) · action **Approve** filled `#4CAF50` (dark `#5FC86A`).
- **Reject** (opened by sheet's Reject) — error `x-circle` square · **"Reject request"** / "Tell the cashier why" ·
  **Reason** textarea (min-height 64, placeholder "Add a short reason…") · action **Reject** filled `#F44336`.
Both show a **success / error snackbar** on completion.

---

## Interactions & Behavior  ⚠ preserve exactly
- **Newest first.** Tapping a row **marks it read** (clears its unread dot); **if the request is `pending`**, the
  **resolve bottom sheet** opens. **Non-pending (approved/rejected) rows are read-only** — tap marks read only, no
  sheet.
- **Mark all read** (app-bar action) clears every unread dot at once; disabled/muted when nothing is unread.
- **Resolve sheet → Approve** opens the **password dialog** (admin's password required, obscured). **Resolve sheet →
  Reject** opens the **reason dialog** (rejection reason captured). Both close the sheet and show a success/error
  snackbar; the row moves to approved/rejected with its new status color.
- **Theme toggle** swaps the full light/dark token set, including primary slate → gold (Mark-all-read, sheet
  Approve button, receipt sale number + qty chips, password focus) and each status' dark variant.
- Opened from the dashboard **notification bell**. **Admin-only** — not reachable by cashier/staff roles.

## State Management
Reuse the existing void-request providers/blocs. Needed: the request list (`VoidRequestEntity`: sale number, grand
total, requested-by name, reason, datetime, **status** pending/approved/rejected, **read** flag) sorted newest-first
· unread count (drives the count pill + dot visibility + Mark-all-read enabled) · the selected request's full sale
breakdown for the receipt (items: name, sku, unit price, qty, line total; labor lines; total) · approve action
(admin password) · reject action (reason) · snackbar results.

## Must-keep
- **Status color semantics** (pending amber · approved green · rejected red) on the leading square, the status pill,
  and the count pill — **with dark parity**. This is the point of the bundle; currently all-neutral.
- **Unread red dot** (only when `read == false`) + **Mark all read** clearing it.
- **Tap rule:** mark read always; open the resolve sheet **only for pending**; approved/rejected are read-only.
- **Resolve sheet** = requester + reason + **Sale-Detail-style receipt breakdown** + Reject/Approve footer.
- **Approve requires admin password**; **Reject captures a reason**; success/error snackbars.
- **`AppCard`** rows (no Material `ListTile`/`Divider`); **Lucide** (off Cupertino); **admin-only** gating.
- Sale number in **Roboto Mono**; currency `₱1,234.00`; dates `MMM d, h:mm a`.

## Assets
- Icons: **Lucide** (`lucide_icons`) — migrate off Cupertino. No custom SVGs.
- Fonts: **Figtree** + **Roboto Mono** (already in project).
- No images/photography.

## Files
- `MAKI POS Void Requests.dc.html` — redesign prototype, **source of truth** (4 states × light/dark).
- `reference_current-ui.html` — current/flat UI (Material `ListTile` + Cupertino, no status color), before/after only.
