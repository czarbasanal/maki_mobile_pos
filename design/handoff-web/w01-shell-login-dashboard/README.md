# MAKI POS Web Admin — Design Handoff w01: Shell + Login + Dashboard

**Purpose.** A self-contained bundle showing the **current** web-admin UI so a design session can
*see* what exists today and mark up what should change. Hand the marked-up version back and it gets
implemented in React (Vite + TypeScript + Tailwind) at `web_admin/`. This is the **chrome bundle**:
it documents the AdminShell + Sidebar shell that *every other bundle renders inside*, plus the two
auth screens and the Dashboard. Other bundles reference the sidebar/shell defined here.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate static reconstruction (light theme,
  desktop ~1280px) of the shell, both auth screens, and the Dashboard, plus a "Sidebar per role"
  comparison and a "Modals & overlays" section.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  chrome spec, and a **"What I want" template** to fill in.

**Surfaces** (repo-relative under `web_admin/src/presentation/`):
- `layouts/AdminShell.tsx` — app shell (sidebar + main + offline banner + scroll region)
- `layouts/AuthLayout.tsx` — centered layout for login / access-denied
- `components/common/Sidebar.tsx` — sidebar chrome, nav, per-role gating, account popover
- `components/common/OfflineBanner.tsx` — offline strip
- `features/auth/LoginPage.tsx` — `/login` (+ inline reset-password confirm, banners, restoring state)
- `features/access-denied/AccessDeniedPage.tsx` — `/access-denied`
- `features/dashboard/DashboardPage.tsx` — `/` (page shell + states)
- `features/dashboard/SummaryCard.tsx` — metric tile (default / emphasized / compact)
- `features/dashboard/RecentSales.tsx` — recent-sales list rows
- `features/dashboard/InventoryStatus.tsx` — stock-status count rows

Shared components touched here (restyle once, reused everywhere): `Sidebar`, `OfflineBanner`,
`SummaryCard`, `LoadingView`/`Spinner`, `ErrorView`, `EmptyState`, `Dialog` (popover pattern).

---

## Design system (tokens in `core/theme/tokens.ts` → `tailwind.config.ts`; Roboto via `@fontsource/roboto`)

### Color (hex — semantic use)
| Token | Hex | Use here |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; also the **black button fill** |
| `light-text-secondary` | `#666666` | secondary text, inactive nav items |
| `light-text-hint` | `#A0A0A0` | hints, section labels, role text, timestamps |
| `light-background` / `light-card` | `#FFFFFF` | app bg, sidebar bg, cards, inputs, dialogs |
| `light-surface` / `light-subtle` | `#FAFAFA` | hover fills, active nav fill, subtle panels |
| `light-hairline` / `light-divider` | `#EAEAEA` | borders, row dividers (near-invisible) |
| `light-border` | `#E0E0E0` | input borders, monogram tile border |
| `primary-dark` | `#121C1D` | avatar bg, black-button hover |
| `light-accent` (brand-slate) | `#334E58` | slate accent (defined; not used in light chrome) |
| success | `#4CAF50` / light `#E8F5E9` / dark `#2E7D32` | success banner, In-stock, cash dot |
| warning | `#FFC107` / light `#FFF8E1` / dark `#F57C00` | low-stock, capped notices |
| error | `#F44336` / light `#FFEBEE` / dark `#C62828` | error banner/view, Void pill, out-of-stock |
| info | `#2196F3` / light `#E3F2FD` / dark `#1565C0` | info, "Sales today" tile tone |
| pos.cash / pos.gcash / pos.voided | `#4CAF50` / `#007DFE` / `#9E9E9E` | RecentSales status dots |
| role.admin / staff / cashier | `#9C27B0` / `#2196F3` / `#4CAF50` | role badges (defined; role shown as plain text in the sidebar chip) |

**Tonal palette** (`core/theme/tones.ts`, keyed yellow/green/blue/orange/red/violet):
`toneStrokeClasses` = `text-{tone}-500` (SummaryCard icon stroke); `toneBadgeClasses` =
`bg-{tone}-50 text-{tone}-600` (InventoryStatus 24px badges). Standard Tailwind scale.

### Type scale (custom `fontSize`, px / weight)
headingMedium 24/600 · headingSmall 20/600 · bodyLarge 18/400 · bodyMedium 16/400 ·
bodySmall 14/400 · labelMedium 14/500 · labelSmall 12/500 · badge 11/600. Ad-hoc arbitrary
sizes appear too: `text-[20px]` (login monogram), `text-[13px]` (banner/offline copy),
`text-[12px]` (hints/errors), `text-[11px]` (section labels, role, version), `text-[10px]` (Void pill).
Numerics use `tabular-nums`.

### Spacing (`tk-*`) & radii & shadows
Spacing: `tk-xs 4 · tk-sm 8 · tk-md 16 · tk-lg 24 · tk-xl 32 · tk-xxl 48`.
Radii: `rounded-md` 6px (inputs/buttons/nav items), `rounded-lg` 8px (cards/panels/dialogs),
`rounded-full` (avatar, status dots). Shadows: none on cards/tiles (weight = type + hairlines);
`shadow-lg` on the account popover; `shadow-xl` on the `Dialog` panel.

### Layout
Sidebar `w-60` (240px) fixed; content max width 1280px; no top bar (each page owns its header).
Content scrolls independently in the main region.

### Button styles
- **Black (primary):** `bg-light-text (#0A0A0A) text-light-background`, hover `bg-primary-dark (#121C1D)`,
  `disabled:opacity-60`. Login submit, reset "Send", Access-Denied "Sign out".
- **Ghost text:** `hover:bg-light-hairline` (reset "Cancel"); text-link "Forgot password?" (`hover:underline`).
- **Icon button:** password show/hide, banner dismiss (`hover:bg-light-subtle`).

### Card / list pattern
Panels & tiles: `rounded-lg border border-light-hairline bg-light-card`. Lists use
`<ul class="divide-y divide-light-hairline">` rows (RecentSales, InventoryStatus). No table on
these screens — the standard table pattern (FAFAFA header, uppercase 11px headers, divided rows,
tabular-nums numerics) lives in later bundles.

---

## App chrome (rendered around every non-auth screen)

### AdminShell — `layouts/AdminShell.tsx`
`flex h-full w-full bg-light-background`. Left = `<Sidebar/>` (fixed 240px). Right =
`<main class="flex flex-1 flex-col overflow-hidden">` holding `<OfflineBanner/>` (above content)
then a scroll region `<div class="flex-1 overflow-auto"><Outlet/></div>`. Vercel-style: **no top
bar** — each page renders its own header.

### AuthLayout — `layouts/AuthLayout.tsx`
Used by `/login` and `/access-denied`. Full-viewport centered:
`flex h-full w-full items-center justify-center bg-light-background p-tk-lg`, inner `w-full max-w-md`.

### Sidebar — `components/common/Sidebar.tsx`
`<aside class="flex h-full w-60 shrink-0 flex-col border-r border-light-hairline bg-light-background">`.
- **Brand header:** 56px tall (`h-14`), `px-tk-lg`, text "MAKI POS" (`text-bodyMedium font-semibold
  tracking-tight`). No logo icon.
- **Nav:** scrollable `flex-1`, `px-tk-sm py-tk-sm`. Standalone **Dashboard** link at top, then grouped
  sections. Section header: `text-[11px] font-medium uppercase tracking-wider text-light-text-hint`.
- **Nav item (`SidebarLink`):** `flex gap-tk-sm rounded-md px-tk-sm py-[6px] text-bodySmall`, 16px icon
  (`h-4 w-4`), truncating label. Active = `bg-light-subtle font-semibold text-light-text`; inactive =
  `text-light-text-secondary hover:bg-light-subtle hover:text-light-text`. Active detection: exact match
  for `/`, otherwise prefix match on `path` or `path/`.

**Nav sections & items** (label — route — heroicon — permission gate):
- **Sell** — POS `/pos` `ShoppingCartIcon` (common) · Drafts `/drafts` `PencilSquareIcon` (common)
- **Stock** — Inventory `/inventory` `CubeIcon` (`viewInventory`) · Receiving `/receiving` `TruckIcon`
  (`accessReceiving`) · Reorder `/inventory/reorder` `ClipboardDocumentListIcon` (`viewProductCost`, admin) ·
  Price History `/inventory/price-history` `ClockIcon` (`viewProductCost`, admin) · Suppliers `/suppliers`
  `BuildingStorefrontIcon` (`viewSuppliers`, admin)
- **Money** — Expenses `/expenses` `ReceiptPercentIcon` (`viewExpenses`) · Reports `/reports`
  `ChartBarIcon` (`viewSalesReports`)
- **Admin** — Users `/users` `UsersIcon` (`viewUsers`, admin) · Activity Logs `/logs` `ClockIcon`
  (`viewUserLogs`, admin) · Settings `/settings` `Cog6ToothIcon` (`viewSettings`)

**Gating mechanics:** each item filtered by `canAccess(item.path, user)` — the same gate as the route
guard. A section renders only if ≥1 item is allowed (empty sections hidden). The app currently gates
entry to admins at the door, but the sidebar honors the full RBAC matrix.

**Per-role sidebar visibility:**
| Item | admin | staff | cashier |
|---|:--:|:--:|:--:|
| Dashboard | ✓ | ✓ | ✓ |
| POS | ✓ | ✓ | ✓ |
| Drafts | ✓ | ✓ | ✓ |
| Inventory | ✓ | ✓ | ✓ |
| Receiving | ✓ | ✓ | — |
| Reorder | ✓ | — | — |
| Price History | ✓ | — | — |
| Suppliers | ✓ | — | — |
| Expenses | ✓ | ✓ | ✓ |
| Reports | ✓ | ✓ | ✓ |
| Users | ✓ | — | — |
| Activity Logs | ✓ | — | — |
| Settings | ✓ | ✓ | ✓ |

Result: **staff** Stock section = Inventory + Receiving; Admin section = Settings only. **cashier**
Stock section = Inventory only; Money section = Expenses + Reports; Admin section = Settings only
(the whole Admin header still shows because Settings is allowed).

**Account chip / popover (`SidebarAccount`,** pinned to foot, top hairline, `p-tk-sm`):
- **Trigger button:** circular 28px avatar (`bg-primary-dark`, white 12px letter = first char of email,
  uppercased), email (`text-bodySmall`, truncated) over role (`text-[11px] uppercase tracking-wider
  text-light-text-hint`), and `ChevronUpIcon` (rotates 180° when open).
- **Popover (opens UPWARD,** `bottom-full`, `rounded-md border border-light-hairline bg-light-card
  shadow-lg`): top block = full email + role; below, full-width **"Sign out"** row with
  `ArrowRightStartOnRectangleIcon` (`hover:bg-light-subtle`). Closes on outside mousedown. Sign out →
  `authRepo.signOut()` then navigate `/login` replace.

### OfflineBanner — `components/common/OfflineBanner.tsx`
Hidden when online. When offline: full-width strip `border-b border-light-hairline bg-light-subtle
px-tk-lg py-tk-xs text-light-text-secondary`, `SignalSlashIcon` (16px) + **"Offline — changes will
sync automatically"** (`text-[13px]`). Syncs `navigator.onLine` on mount; subscribes to window
online/offline.

### Print-hiding — `index.css` `@media print`
`body *` → `visibility:hidden`; `#print-receipt` subtree → visible + pinned top-left full width.
Purpose: print only the receipt subtree (used by the Receipt in bundle w06), hiding all chrome. No
`print:hidden` utilities on chrome components — one global CSS rule handles it.

---

## Screen 1 — Login (`/login`) — `features/auth/LoginPage.tsx`

**Job.** Admin sign-in (email/password) with a password-reset flow. Rendered inside AuthLayout
(centered `max-w-md`). Sets `document.title = 'Sign in · MAKI POS Admin'`.

**Layout top → bottom** (`space-y-tk-xl`):
1. **Header** — 48px monogram tile (`rounded-md border border-light-border`, letter "M"
   `text-[20px] font-semibold`), title **"MAKI POS Admin"** (`text-bodyLarge font-semibold`),
   subtitle **"Sign in to continue"** (`text-bodySmall text-light-text-secondary`).
2. **Banners (conditional)** —
   - **ErrorBanner** (`border-error-light bg-error-light/40 text-error-dark`): `ExclamationCircleIcon`
     + message (`text-[13px]`) + dismiss `XMarkIcon`. Shows sign-in / reset error.
   - **SuccessBanner** (`border-success-light bg-success-light/40 text-success-dark`): `CheckCircleIcon`
     + message + dismiss. Shows **"Password reset email sent to {email}. Check your inbox."** after reset.
3. **Form** (`space-y-tk-md`, `noValidate`):
   - **Email** (`Field`: label `text-bodySmall font-medium` + input + error `text-[12px] text-error`),
     `type=email`, autofocus.
   - **Password** — input with right-aligned show/hide toggle (`EyeIcon`/`EyeSlashIcon`, 16px). Input
     `inputCls`: `rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall`; focus adds real
     `outline outline-1 outline-light-text` (no glow); error → `border-error`/`outline-error`.
   - **Submit** — full-width black button; shows `Spinner` + **"Signing in…"** while pending, else **"Sign in"**.
   - **"Forgot password?"** text link. Clicking swaps to the inline **ResetConfirm** card (`rounded-md
     border border-light-hairline bg-light-subtle p-tk-md`): copy **"Send password reset email to
     {email}?"** (or **"Enter your email above first."**), **Cancel** (ghost) + **Send** (black; shows
     Spinner + "Sending…" while pending; disabled if no email).
4. **Footer** — version **"v1.0.0"** (`text-[11px] tracking-[0.5px] text-light-text-hint`).

**States / behavior:**
- Auth `status==='loading'` → renders `LoadingView label="Restoring session…"` **instead of the form**.
- Already `signedIn` && `role==='admin'` → `<Navigate>` to `from` (default `/`).
- Validation (zod): email required + valid, password required; errors via react-hook-form.
- On submit: non-admin → navigate `/access-denied` replace; admin → navigate `from`. Auth failure sets
  a field error on **password** with the friendly message from `FirebaseAuthRepository`.
- Reset flow: validates email present + valid (own inline errors "Enter your email first" / "Invalid
  email address"), calls `useSendPasswordReset`, shows success banner or surfaces error in the ErrorBanner.
- Icons (heroicons 24/outline): CheckCircleIcon, ExclamationCircleIcon, EyeIcon, EyeSlashIcon, XMarkIcon.

**Per-role:** no in-page role branching beyond the admin gate. Only admins proceed; every other role is
bounced to `/access-denied` on successful auth.

---

## Screen 2 — Access Denied (`/access-denied`) — `features/access-denied/AccessDeniedPage.tsx`

**Job.** Shown when a non-admin authenticates. Rendered in AuthLayout (centered).
**Layout** (`space-y-tk-md text-center`): centered `NoSymbolIcon` 40px (`text-light-text-secondary`);
heading **"Access denied"** (`text-headingMedium font-semibold`); paragraph **"Your account does not
have permission to use the web admin. Sign in with an admin account to continue."** (`text-bodySmall
text-light-text-secondary`); black **"Sign out"** button → `authRepo.signOut()` then navigate `/login`
replace. No loading/error states, no modals, no role branching.

---

## Screen 3 — Dashboard (`/`) — `features/dashboard/DashboardPage.tsx`

**Job.** Read-only live snapshot of today's activity. Rendered inside AdminShell. Sets
`document.title = 'Dashboard · MAKI POS Admin'`. Data: `useTodaysSales()` → `summarizeSales()`;
InventoryStatus uses `useProducts()`.

**Layout top → bottom** (`space-y-tk-xl px-tk-xl py-tk-lg`):
1. **Header** — **"Dashboard"** (`text-headingMedium font-semibold tracking-tight`) + subtitle
   **"Live snapshot of today's activity."** (`text-bodySmall text-light-text-secondary`).
2. **Summary tiles** — responsive grid `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-tk-md`. Five
   `SummaryCard` tiles (title — value — icon — tone):
   - **Sales today** = `String(count)` — `ReceiptPercentIcon` — blue
   - **Gross Sales** = `formatMoney(grossAmount)` — `BanknotesIcon` — yellow — **emphasized** (inverted:
     `bg-light-text text-light-background`, black tile / white text)
   - **Total COGS** = `formatMoney(totalCost)` — `CubeIcon` — orange
   - **Gross profit** = `formatMoney(profit)` — `ArrowTrendingUpIcon` — green
   - **Avg order** = `formatMoney(revenue/count, 0 when no sales)` — `ChartBarIcon` — violet
3. **Two-panel row** — grid `grid-cols-1 lg:grid-cols-3 gap-tk-lg`:
   - **Recent sales** (`lg:col-span-2`) — `Panel` (`rounded-lg border border-light-hairline bg-light-card
     p-tk-lg`, h2 title `text-bodyMedium font-semibold`). Contents = `RecentSales` (limit 8).
   - **Inventory status** — `Panel`, contents = `InventoryStatus`.

**Sub-components:**
- **SummaryCard** — default `flex flex-col gap-tk-xs rounded-lg border border-light-hairline bg-light-card
  p-tk-md`: title (`text-bodySmall`) + tone icon (`toneStrokeClasses`, 16px), value (`text-headingMedium
  font-semibold tabular-nums`), optional hint. **Emphasized** inverts to `bg-light-text
  text-light-background` with muted `/70`,`/60` opacities + white icon. A **compact** variant exists
  (`text-[11px]` uppercase label, bodyLarge value) but is **not used on the Dashboard**.
- **RecentSales** — `<ul divide-y>` up to 8 rows. Each: 8px colored status dot (gcash `#007DFE` / cash
  `#4CAF50` / voided `#9E9E9E`), sale number (`text-bodySmall font-semibold tabular-nums`; voided →
  line-through hint), optional **"Void"** pill (`bg-error-light text-error-dark text-[10px] uppercase`),
  payment-method name (`text-[12px] text-light-text-hint`), second line **"N item(s) · time"** (en-PH 12h),
  right-aligned total (`formatMoney`, voided struck through). Empty → EmptyState.
- **InventoryStatus** — counts over active products (`getStockStatus`). `<ul divide-y>`, 4 rows: **Total**
  (`CubeIcon`, violet) · **In stock** (`CheckCircleIcon`, green) · **Low stock** (`ExclamationTriangleIcon`,
  orange) · **Out of stock** (`XCircleIcon`, red). Each row: 24px tinted badge (`toneBadgeClasses`) with
  14px icon, label (`text-bodySmall text-light-text-secondary`), right value (`text-bodyMedium font-semibold
  tabular-nums`). Own loading/error states.

**UI states:**
- Summary grid: error → `ErrorView title="Could not load sales" message`; loading/no data →
  `LoadingView label="Loading today's sales…"` inside an `h-32` box; else grid.
- Recent sales panel: error → `ErrorView message`; loading → `LoadingView label="Loading sales…"`; empty
  → `EmptyState title="No sales today" description="Transactions will appear here as they happen."`; else list.
- Inventory panel: error → `ErrorView`; loading → `LoadingView label="Loading inventory…"`; else rows.

**Per-role:** none — Dashboard is a common route with no permission branching. Revenue, COGS, and profit
are shown to any signed-in role here (unlike Reorder / Price-History which are admin-gated at the router).

**Dashboard heroicons (24/outline):** ArrowTrendingUpIcon, BanknotesIcon, ChartBarIcon, CubeIcon,
ReceiptPercentIcon (tiles); CheckCircleIcon, ExclamationTriangleIcon, XCircleIcon, CubeIcon (inventory).
No modals/menus on this screen.

---

## Modals & overlays

- **Account popover** (Sidebar `SidebarAccount`) — opens **upward** from the pinned account chip.
  `rounded-md border border-light-hairline bg-light-card shadow-lg`. Top block: full email + role
  (`text-[11px] uppercase`). Row below: **"Sign out"** with `ArrowRightStartOnRectangleIcon`,
  `hover:bg-light-subtle`. Closes on outside mousedown; no pending/lock state.
- **Login inline reset-confirm card** (`ResetConfirm`) — not a portal dialog; replaces the "Forgot
  password?" link in-flow. `rounded-md border border-light-hairline bg-light-subtle p-tk-md`, copy
  "Send password reset email to {email}?", **Cancel** + **Send** (Send disabled when no email; shows
  Spinner + "Sending…" while pending).
- **OfflineBanner strip** — full-width `bg-light-subtle` strip above content when offline (not a modal;
  documented as an overlay-like chrome state).
- **Login banners** — ErrorBanner (error tint) and SuccessBanner (success tint), each dismissable.

(There are no portal `Dialog` modals on these three screens; the shared `Dialog` pattern —
overlay `bg-black/30`, panel `max-w-md rounded-lg shadow-xl`, ESC/click-outside close, body-scroll lock —
is documented here for reference because later bundles use it.)

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall visual language for the web admin (keep Vercel-airy flat/hairline, or push a distinct look)? →
- Reference apps / dashboards you like →

### Shell + Sidebar (affects every bundle)
- Sidebar: keep white + grouped sections + icons, or restructure (collapsible, denser, different grouping)? →
- Brand header treatment (add a logo mark? keep text-only "MAKI POS")? →
- Active/inactive nav item styling (fill vs left-bar vs icon tint)? →
- Account chip + upward popover — keep, or move/restyle? →
- Offline banner placement + styling →

### Login / Access Denied
- Auth card treatment — centered card on plain bg, or a split/branded layout? →
- Monogram tile, banners, inline reset-confirm — restyle or rethink? →
- Restoring-session loading state →

### Dashboard
- Five summary tiles — keep 4-up grid + one emphasized black tile, or a hero-number strip? →
- **Charts allowed here:** e.g. a sales-over-time line, tender-split donut, or a stock-status bar built
  from InventoryStatus counts — want any? →
- Recent sales list — row density, keep colored dots + Void pill? →
- Inventory status — keep 4 count rows, or a bar/segmented meter? →
- Panel surfaces (hairline cards) — soft shadow, or keep flat? →

### Constraints / must-keep
- **Per-role sidebar visibility** (admin/staff/cashier table above) and `canAccess` gating must stay →
- Admin-only door: non-admins are bounced to `/access-denied` on login — copy + Sign-out must stay →
- Every state: restoring-session, login error/success banners, inline reset-confirm, Dashboard
  loading/error/empty (summary + recent-sales + inventory), offline banner →
- All copy verbatim (titles, subtitles, banner text, "Offline — changes will sync automatically",
  "No sales today", access-denied paragraph, "v1.0.0") →
- Print-hiding rule (chrome hidden when a receipt prints) must survive any shell restructuring →
- ₱ money formatting (en-PH) and `tabular-nums` on all numerics →

---

*Bundles: **w01-shell-login-dashboard (this)** · w02-pos-drafts · w03-inventory · w04-receiving ·
w05-suppliers · w06-reports · w07-users · w08-settings · w09-logs. One bundle at a time, per
`design/handoff-web/ROADMAP.md`.*
